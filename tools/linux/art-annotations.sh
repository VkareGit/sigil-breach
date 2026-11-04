#!/usr/bin/env bash
# Exports frames picked from the hit report through tools/art/annotations (a LOVE tool), as
# tools/win/art-annotations.ps1. Called by art-contact.sh and art-crops.sh.
# Usage: art-annotations.sh <contact|crops> <frames.csv> <output dir> [scale] [points]
source "$(dirname -- "${BASH_SOURCE[0]}")/project.sh"
[ "$#" -ge 3 ] || die 'Usage: art-annotations.sh <contact|crops> <frames.csv> <output> [scale] [points]'
mode=$1
manifest=$(realpath -- "$2")
output=$(realpath -m -- "$3")
scale=${4:-2}
points=${5:-}
mkdir -p "$output"
mapfile -t prefix < <(display_prefix)
runtime=$(love_path)
cd -- "$SIGIL_ROOT"
timeout --kill-after=10 120 "${prefix[@]}" "$runtime" tools/art/annotations "$SIGIL_GAME" \
  "$manifest" "$output" "$mode" "$scale" "$points" \
  > "$output/stdout.txt" 2> "$output/stderr.txt" \
  || die "Annotation export failed; see $output/stdout.txt and stderr.txt."
cat -- "$output/stdout.txt"
