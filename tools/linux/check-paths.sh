#!/usr/bin/env bash
# Paths in code must match their files letter for letter, as tools/win/check-paths.ps1. On
# Linux a wrong case is a missing file. Usage: check-paths.sh [game dir] [report file]
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
exec python3 -I - "${1:-$root/game}" "${2:-}" << 'PY'
import os, re, sys
source, report = os.path.abspath(sys.argv[1]), sys.argv[2]
known, leaves, issues, checked, files = {}, {}, [], 0, []
for folder, dirs, names in os.walk(source):
    for name in dirs + names:
        relative = os.path.relpath(os.path.join(folder, name), source).replace(os.sep, '/')
        key = relative.lower()
        if key in known and known[key] != relative:
            issues.append(f'CASE COLLISION: {relative} / {known[key]}')
        else:
            known[key] = relative
    for name in names:
        leaves.setdefault(name.lower(), set()).add(name)
        files.append(os.path.join(folder, name))
leaf = re.compile(r'''['"]([^'"/\\\r\n]+\.(?:png|jpg|wav|lua|json|txt|save))['"]''', re.I)
path = re.compile(r'''['"]((?:game/)?(?:assets|src|tests|qa|docs)[/.][^'"\r\n]*)['"]''', re.I)
dotted = re.compile(r'^(src|qa|tests|assets)\.[\w.-]+$', re.I)
# Literal prefixes are checked too: e.g. assets/sounds/ + family + /B1-1.wav. Dynamic
# suffixes remain covered by the runtime asset and registry tests.
for file in sorted(files):
    if not file.lower().endswith(('.lua', '.json')):
        continue
    relative = os.path.relpath(file, source).replace(os.sep, '/')
    text = open(file, encoding='utf-8', errors='replace', newline='').read()
    for match in leaf.finditer(text):
        value = match.group(1)
        if value.lower() in leaves:
            checked += 1
            if value not in leaves[value.lower()]:
                expected = ', '.join(sorted(leaves[value.lower()]))
                issues.append(f'CASE: {relative}: {value} (expected {expected})')
    for match in path.finditer(text):
        value = match.group(1)
        target = re.sub(r'^game/', '', value, flags=re.I)
        if dotted.match(target):
            target = target.replace('.', '/') + '.lua'
        target = target.rstrip('/')
        # A literal can end in a filename prefix before concatenation.
        while target and target.lower() not in known and '/' in target:
            target = target[:target.rindex('/')]
        if target and target.lower() in known:
            checked += 1
            if target != known[target.lower()]:
                line = 1 + text.count('\n', 0, match.start())
                issues.append(f'CASE: {relative}:{line}: {value} (expected {known[target.lower()]})')
lines = issues + [f'PATH CASE: {checked} references checked; {len(issues)} issues.']
if report:
    open(report, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
print('\n'.join(lines))
sys.exit(1 if issues else 0)
PY
