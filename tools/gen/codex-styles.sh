#!/usr/bin/env bash
# Run style-test briefs (tools/gen/styles/<id>.txt) in parallel, one Codex job each.
ROOT=/mnt/c/Users/nahiko/Documents/dev/sigil-breach
mkdir -p "$ROOT/work/gen/styles/logs"
pids=()
for id in "$@"; do
  bash "$ROOT/tools/gen/codex-gen.sh" "$ROOT/tools/gen/styles/$id.txt" "$ROOT/work/gen/styles/_ref-screenshot.png" > "$ROOT/work/gen/styles/logs/$id.log" 2>&1 &
  pids+=($!)
done
for p in "${pids[@]}"; do wait "$p"; echo "job $p exit $?"; done
