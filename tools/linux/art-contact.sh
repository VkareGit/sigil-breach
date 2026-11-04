#!/usr/bin/env bash
# Diagnostic source-UV contact sheets, as tools/win/art-contact.ps1; never edits production
# art. Needs work/qa/hit-frame-rects.csv (the game's --hit-review).
# Usage: art-contact.sh [--rects file] [kinds...]
source "$(dirname -- "${BASH_SOURCE[0]}")/project.sh"
rects="$SIGIL_ROOT/work/qa/hit-frame-rects.csv"
if [ "${1:-}" = --rects ]; then
  rects=$2
  shift 2
fi
[ "$#" -gt 0 ] || set -- stolas buer boss furfur art-evade
out="$SIGIL_ROOT/work/qa/anatomy-contact"
mkdir -p "$out"
python3 -I - "$rects" "$out/frames.csv" "$@" << 'PY'
import csv, sys
rects, output, *kinds = sys.argv[1:]
rows = [row for row in csv.DictReader(open(rects, newline='')) if row['kind'] in kinds]
if not rows:
    sys.exit('No frames of these kinds in ' + rects)
writer = csv.DictWriter(open(output, 'w', newline=''), rows[0].keys(), quoting=csv.QUOTE_ALL)
writer.writeheader()
writer.writerows(rows)
PY
"$SIGIL_ROOT/tools/linux/art-annotations.sh" contact "$out/frames.csv" "$out"
