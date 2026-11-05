#!/usr/bin/env bash
# The architecture gate, as tools/win/check.ps1. The checker draws nothing: no display needed.
source "$(dirname -- "${BASH_SOURCE[0]}")/project.sh"
mkdir -p "$SIGIL_QA"
python3 "$SIGIL_ROOT/tools/art/check_visual_catalog.py" --self-test \
  > "$SIGIL_QA/visual-catalog.txt" || { cat "$SIGIL_QA/visual-catalog.txt"; exit 1; }
tail -1 "$SIGIL_QA/visual-catalog.txt"
"$SIGIL_ROOT/tools/linux/check-paths.sh" "$SIGIL_GAME" "$SIGIL_QA/path-case.txt"
manifest="$SIGIL_QA/lua-files.txt"
files="$SIGIL_QA/game-files.txt"
report="$SIGIL_QA/architecture.txt"
(cd -- "$SIGIL_GAME" && find . -type f -printf '%P\n' | LC_ALL=C sort) > "$files"
grep '\.lua$' "$files" > "$manifest"
checker="$SIGIL_ROOT/tools/check"
enter_qa_session
run_isolated architecture 60 --no-display "$SIGIL_QA" -- "$checker" "$manifest" "$SIGIL_GAME" \
  "$report" "$checker/literals.txt" "$checker/presentation-edges.txt" "$files"
tail -1 "$report"
