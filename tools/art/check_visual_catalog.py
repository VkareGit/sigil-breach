#!/usr/bin/env python3
"""Reject unreviewed texture changes. This is identity QA, not an art critic."""
import argparse
import hashlib
import json
from pathlib import Path
import tempfile


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None


def problems(root):
    references = json.loads((root / 'baza/index.json').read_text())['references']
    textures = json.loads((root / 'baza/catalog.json').read_text())['textures']
    errors, ids, expected = [], set(), set()
    reference_paths = set()
    for ref in references:
        if ref['id'] in ids:
            errors.append('duplicate reference: ' + ref['id'])
        ids.add(ref['id'])
        path = ref['reference']
        reference_paths.add(path)
        if not path.startswith('baza/') or '..' in Path(path).parts:
            errors.append('invalid reference path: ' + path)
        elif digest(root / path) != ref['sha256']:
            errors.append('reference changed or missing: ' + path)
    for path in (root / 'baza').rglob('*'):
        if path.suffix.lower() in {'.png', '.jpg', '.jpeg', '.webp', '.dds', '.ktx'}:
            relative = path.relative_to(root).as_posix()
            if relative not in reference_paths:
                errors.append('unrecorded reference: ' + relative)
    for entry in textures:
        path = entry['path']
        if path in expected:
            errors.append('duplicate texture: ' + path)
        expected.add(path)
        if not path.startswith('game/assets/') or '..' in Path(path).parts:
            errors.append('invalid production path: ' + path)
        elif digest(root / path) != entry['sha256']:
            errors.append('texture changed or missing: ' + path)
        if entry.get('reference') not in ids or not entry.get('review'):
            errors.append('texture lacks a reference and review: ' + path)
    actual = {p.relative_to(root).as_posix() for p in (root / 'game/assets').rglob('*')
              if p.suffix.lower() in {'.png', '.jpg', '.jpeg', '.webp', '.dds', '.ktx'} }
    for path in sorted(actual - expected):
        errors.append('unreviewed texture: ' + path)
    for path in sorted(expected - actual):
        errors.append('catalog contains an absent texture: ' + path)
    # Reference files must never become runtime dependencies.
    for path in [root / 'game/main.lua', root / 'game/conf.lua', *(root / 'game/src').rglob('*.lua')]:
        if path.is_file() and 'baza/' in path.read_text():
            errors.append('runtime reads the reference folder: ' + path.relative_to(root).as_posix())
    return errors


def self_test():
    with tempfile.TemporaryDirectory(prefix='sigil-visual-catalog-') as tmp:
        root = Path(tmp)
        (root / 'baza').mkdir()
        (root / 'game/assets').mkdir(parents=True)
        (root / 'game/src').mkdir()
        ref, art = root / 'baza/base.png', root / 'game/assets/body.png'
        ref.write_bytes(b'approved painting')
        art.write_bytes(ref.read_bytes())
        (root / 'baza/index.json').write_text(json.dumps({'references': [
            {'id': 'base', 'reference': 'baza/base.png', 'sha256': digest(ref)}]}))
        (root / 'baza/catalog.json').write_text(json.dumps({'textures': [
            {'path': 'game/assets/body.png', 'sha256': digest(art), 'reference': 'base', 'review': 'fixture'}]}))
        assert not problems(root), 'approved fixture rejected'
        art.write_bytes(b'repainted under the same name')
        assert any('texture changed' in x for x in problems(root))
        art.write_bytes(ref.read_bytes())
        extra = root / 'game/assets/new-pose.png'
        extra.write_bytes(ref.read_bytes())
        assert any('unreviewed texture' in x for x in problems(root))
        extra.unlink()
        unrecorded = root / 'baza/unapproved.png'
        unrecorded.write_bytes(ref.read_bytes())
        assert any('unrecorded reference' in x for x in problems(root))
        unrecorded.unlink()
        ref.unlink()
        assert any('reference changed or missing' in x for x in problems(root))
        ref.write_bytes(art.read_bytes())
        (root / 'game/src/leak.lua').write_text("return 'baza/base.png'")
        assert any('runtime reads' in x for x in problems(root))
        (root / 'game/src/leak.lua').unlink()
        art.unlink()
        assert any('absent texture' in x for x in problems(root))
    print('VISUAL CATALOG: 7 positive/negative controls passed.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--self-test', action='store_true')
    args = parser.parse_args()
    if args.self_test:
        self_test()
    issues = problems(args.root)
    for issue in issues:
        print('FAIL ' + issue)
    if issues:
        raise SystemExit(1)
    print('VISUAL CATALOG: all texture identities, references and coverage passed.')
