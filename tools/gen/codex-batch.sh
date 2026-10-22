#!/usr/bin/env bash
# Run several Codex image jobs in parallel. Each argument is "brief|ref1,ref2,...".
# @STYLE@ inside a brief is replaced by tools/gen/briefs/_style.txt.
ROOT=/mnt/c/Users/nahiko/Documents/dev/sigil-breach
STYLE="$ROOT/tools/gen/briefs/_style.txt"
mkdir -p "$ROOT/work/gen/codex/logs"
pids=()
for job in "$@"; do
  brief="${job%%|*}"; refs="${job#*|}"
  name=$(basename "$brief" .txt)
  tmp=$(mktemp)
  python3 - "$ROOT/tools/gen/briefs/$brief" "$STYLE" > "$tmp" <<'PY'
import sys
b=open(sys.argv[1],encoding='utf-8').read(); s=open(sys.argv[2],encoding='utf-8').read()
print(b.replace('@STYLE@', s))
PY
  args=()
  IFS=',' read -ra R <<< "$refs"
  for r in "${R[@]}"; do args+=("$ROOT/$r"); done
  bash "$ROOT/tools/gen/codex-gen.sh" "$tmp" "${args[@]}" > "$ROOT/work/gen/codex/logs/$name.log" 2>&1 &
  pids+=($!)
done
for p in "${pids[@]}"; do wait "$p"; echo "job $p exit $?"; done
