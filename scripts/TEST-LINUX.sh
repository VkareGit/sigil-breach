#!/usr/bin/env bash
# The game's tests on Linux or in WSL, with only love on PATH: no PowerShell or StyLua needed.
#   bash scripts/TEST-LINUX.sh                 mechanics, input and startup
#   bash scripts/TEST-LINUX.sh golden weight   chosen suites by id (tests/suite.lua)
# Reports go to work/qa. /mnt/c does not tell upper from lower case, so from there the
# committed HEAD is cloned into the Linux home, tested and removed. Uncommitted changes
# are not seen in that case. The full gate with format and render is scripts/TEST.ps1 in pwsh.
set -u
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
love --version | grep -q '11\.5' || { echo 'LOVE 11.5 is required on PATH'; exit 2; }
case "$root" in
  /mnt/*)
    dir=$(mktemp -d "$HOME/sigil-test.XXXXXX")
    trap 'rm -rf "$dir"' EXIT
    git clone -q "$root" "$dir/repo"
    dir="$dir/repo"
    ;;
  *) dir=$root ;;
esac
cd -- "$dir" || exit 2
git log --oneline -1
export SIGIL_UI_QA_DIR="$dir/work/qa"
export XDG_DATA_HOME="$dir/work/xdg"
export ALSOFT_DRIVERS=null
mkdir -p "$SIGIL_UI_QA_DIR" "$XDG_DATA_HOME"
if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && [ "${SIGIL_XVFB:-}" != 1 ]; then
  run=(love game)
else
  run=(xvfb-run -a love game)
fi
failed=0
step() {
  local name=$1
  shift
  timeout --kill-after=10s 1800 "${run[@]}" "$@" > "$SIGIL_UI_QA_DIR/linux-$name.out" 2>&1
  local code=$?
  # The reporter's own trials fail on purpose.
  local fails
  fails=$(grep -E '^FAIL ' "$SIGIL_UI_QA_DIR/linux-$name.out" | grep -vE '^FAIL (second|fourth|failure):')
  if [ "$code" -ne 0 ] && [ -z "$fails" ]; then
    fails="exit $code, see $SIGIL_UI_QA_DIR/linux-$name.out"
  fi
  if [ -n "$fails" ]; then
    failed=1
    echo "FAILED: $name"
    echo "$fails"
  else
    echo "PASS: $name"
  fi
  grep -E '^TOTAL' "$SIGIL_UI_QA_DIR/linux-$name.out" | tail -1
}
if [ "$#" -gt 0 ]; then
  for suite in "$@"; do
    step "$suite" "--suite=$suite"
  done
else
  step selftest --selftest
  step input --input-test
  step startup --startup-check
fi
exit "$failed"
