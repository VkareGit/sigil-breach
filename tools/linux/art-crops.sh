#!/usr/bin/env bash
# Landmark annotation, as tools/win/art-crops.ps1: a magnified crop of a painted frame with a
# source-pixel grid, optionally with numbered markers at source pixels "x,y;x,y". Frame cuts
# come from the game: run its --hit-review first (hit-frame-rects.csv). Kind 'art-leap' or
# 'art-evade' for the ability sheets. Output: annotate/ in the external work directory.
# Usage: art-crops.sh <kind> <frame> [frame...] [--points "x,y;x,y"] [--scale n]
source "$(dirname -- "${BASH_SOURCE[0]}")/project.sh"
[ "$#" -ge 2 ] || die 'Usage: art-crops.sh <kind> <frame> [frame...] [--points p] [--scale n]'
kind=$1
shift
points=''
scale=2
frames=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --points)
      points=$2
      shift
      ;;
    --scale)
      scale=$2
      shift
      ;;
    *) frames+=("$1") ;;
  esac
  shift
done
out="$SIGIL_WORK/annotate"
mkdir -p "$out"
python3 -I - "${SIGIL_UI_QA_DIR:-$SIGIL_WORK/qa-direct}/hit-frame-rects.csv" "$out/frames.csv" "$kind" "${frames[@]}" << 'PY'
import csv, sys
rects, output, kind, *frames = sys.argv[1:]
rows = list(csv.DictReader(open(rects, newline='')))
picked = []
for frame in frames:
    found = [r for r in rows if r['kind'] == kind and int(r['frame']) == int(frame)]
    if not found:
        sys.exit(f'no frame {kind} {frame} in hit-frame-rects.csv')
    picked.append(found[0])
writer = csv.DictWriter(open(output, 'w', newline=''), picked[0].keys(), quoting=csv.QUOTE_ALL)
writer.writeheader()
writer.writerows(picked)
PY
"$SIGIL_ROOT/tools/linux/art-annotations.sh" crops "$out/frames.csv" "$out" "$scale" "$points"
