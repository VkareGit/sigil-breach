#!/usr/bin/env python3
# What a Linux player package holds, one rule for building and for checking it (the rule of
# tools/win/package.ps1). Art documents travel beside the player; everything else under assets
# is the game. Naming what stays out means a new art format cannot go missing.
#   package.py love <game dir> <fingerprint> <output.love>   writes the archive
#   package.py legal <game dir> <output dir>                 copies the art documents
#   package.py list <file.love>                              lists an archive
import os
import re
import shutil
import sys
import zipfile


def is_provenance(name):
    return name.startswith('assets/') and name.endswith(('.json', '.txt'))


def is_runtime(name):
    if name in ('main.lua', 'conf.lua') or name.startswith('src/'):
        return True
    return name.startswith('assets/') and not is_provenance(name)


def tree(root):
    for folder, _, names in os.walk(root):
        for name in names:
            path = os.path.join(folder, name)
            yield os.path.relpath(path, root).replace(os.sep, '/'), path


def main(command, *arguments):
    if command == 'love':
        root, fingerprint, output = arguments
        if not re.fullmatch('[A-Fa-f0-9]{64}', fingerprint):
            sys.exit('Invalid game fingerprint.')
        with zipfile.ZipFile(output, 'x', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            for name, path in sorted(tree(root)):
                if is_runtime(name):
                    archive.write(path, name)
            archive.writestr('build-fingerprint.txt', fingerprint + '\n')
    elif command == 'legal':
        root, output = arguments
        for name, path in sorted(tree(root)):
            if is_provenance(name):
                target = os.path.join(output, name)
                os.makedirs(os.path.dirname(target), exist_ok=True)
                shutil.copyfile(path, target)
    elif command == 'list':
        print('\n'.join(sorted(zipfile.ZipFile(arguments[0]).namelist())))
    else:
        sys.exit('Unknown command: ' + command)


main(*sys.argv[1:])
