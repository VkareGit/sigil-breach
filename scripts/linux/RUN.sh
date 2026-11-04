#!/usr/bin/env bash
# The game from source; --release runs the last built Linux player package.
# Usage: scripts/linux/RUN.sh [--release]
source "$(dirname -- "${BASH_SOURCE[0]}")/../../tools/linux/project.sh"
cd -- "$SIGIL_ROOT"
if [ "${1:-}" = --release ]; then
  run="$SIGIL_OUTPUTS/$SIGIL_NAME-Player-Linux/run.sh"
  [ -x "$run" ] || die "No built player; run scripts/linux/BUILD.sh --package first: $run"
  exec "$run"
fi
mapfile -t prefix < <(display_prefix)
runtime=$(love_path)
exec "${prefix[@]}" "$runtime" "$SIGIL_GAME"
