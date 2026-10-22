#!/usr/bin/env bash
# Generate images with Codex's built-in image_generation tool.
# Usage: codex-gen.sh <brief-file> [reference images...]
# The brief tells Codex exactly which files to write under work/gen/codex/.
set -euo pipefail
export PATH=$HOME/.nvm/versions/node/v24.21.0/bin:$PATH
ROOT=/mnt/c/Users/nahiko/Documents/dev/sigil-breach
BRIEF="$1"; shift
IMGS=()
for f in "$@"; do IMGS+=(-i "$f"); done
mkdir -p "$ROOT/work/gen/codex"
cd "$ROOT"
codex exec --skip-git-repo-check -s workspace-write -C "$ROOT" "${IMGS[@]}" - < "$BRIEF"
