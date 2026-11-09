# Shared by every Linux script: source it. The counterpart of tools/win/project.ps1 and
# platform.ps1. Needs bash, coreutils, flock and python3; LOVE and StyLua are in toolchain/.
set -euo pipefail
SIGIL_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
SIGIL_GAME="$SIGIL_ROOT/game"

die() {
  echo "$*" >&2
  exit 1
}

# The version is game/src/core/build.lua (the simulation stamps it on journals); title and
# QA output are game/src/app/release.lua.
literal() {
  sed -n "/\b$1[[:space:]]*=[[:space:]]*'/{s/.*\b$1[[:space:]]*=[[:space:]]*'\([^']*\)'.*/\1/p;q}" "$2"
}
SIGIL_VERSION=$(literal version "$SIGIL_GAME/src/core/build.lua")
[[ "$SIGIL_VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || die 'Invalid release version.'
SIGIL_TITLE=$(literal title "$SIGIL_GAME/src/app/release.lua")
qa_relative=$(literal qaOutput "$SIGIL_GAME/src/app/release.lua")
[ -n "$qa_relative" ] || die 'Missing literal release metadata: qaOutput'
[[ "$qa_relative" = work/* ]] || die 'QA metadata must name a path inside work/.'
# Keep the same rule as src/app/workspace.lua, including for two clones with
# the same basename. Sourcing this file alone never creates an output folder.
SIGIL_WORK=$(python3 -I - "$SIGIL_ROOT" << 'PY'
import hashlib, os, sys
project = os.path.realpath(sys.argv[1])
tries = os.environ.get('SIGIL_TRIES_DIR') or os.path.join(os.environ['HOME'], 'Work', 'tries')
if not os.path.isabs(tries):
    sys.exit('SIGIL_TRIES_DIR must be an absolute path')
digest = hashlib.sha256(project.encode('utf-8')).hexdigest()
print(tries.rstrip('/') + '/sigil-breach-' + digest + '/work')
PY
) || die 'Cannot resolve external work directory.'
SIGIL_QA="$SIGIL_WORK/${qa_relative#work/}"
SIGIL_NAME="SIGIL-BREACH-$SIGIL_VERSION"
SIGIL_OUTPUTS="$SIGIL_ROOT/outputs"

assert_child() { # path root: fails unless path stays inside root
  local full base
  full=$(realpath -m -- "$1")
  base=$(realpath -m -- "$2")
  case "$full" in
    "$base"/*) printf '%s\n' "$full" ;;
    *) die "Path must stay inside '$base': $full" ;;
  esac
}

# An AppImage mounted through FUSE needs libfuse2, which many systems lack; unpacked it needs
# nothing, and the unpacked copy is kept in /tmp between runs.
export APPIMAGE_EXTRACT_AND_RUN=1 NO_CLEANUP=1

# LOVE: SIGIL_LOVE, else the bundled AppImage, else love on PATH.
love_path() {
  local bundled="$SIGIL_ROOT/toolchain/love-11.5-linux/love-11.5-x86_64.AppImage"
  if [ -n "${SIGIL_LOVE:-}" ]; then
    [ -x "$SIGIL_LOVE" ] || command -v "$SIGIL_LOVE" > /dev/null \
      || die 'SIGIL_LOVE must name an existing LOVE 11.5 executable (without arguments).'
    command -v "$SIGIL_LOVE"
  elif [ -f "$bundled" ]; then
    [ -x "$bundled" ] || chmod +x "$bundled"
    printf '%s\n' "$bundled"
  else
    command -v love || die 'Missing bundled LOVE 11.5 and no love on PATH; set SIGIL_LOVE.'
  fi
}

stylua_path() {
  local bundled="$SIGIL_ROOT/toolchain/stylua/stylua" formatter version
  if [ -n "${SIGIL_STYLUA:-}" ]; then
    formatter=$SIGIL_STYLUA
  elif [ -f "$bundled" ]; then
    [ -x "$bundled" ] || chmod +x "$bundled"
    formatter=$bundled
  else
    formatter=$(command -v stylua) || die 'Missing StyLua 2.6.0; see toolchain/stylua/PROVENANCE.txt.'
  fi
  version=$("$formatter" --version)
  [ "$version" = 'stylua 2.6.0' ] || die "StyLua 2.6.0 is required; found: $version"
  printf '%s\n' "$formatter"
}

# With a desktop the game opens a window, and a real graphics card draws it. Without one, or
# with SIGIL_XVFB=1 to keep windows away, it runs on a virtual screen (software rendering).
display_prefix() {
  if [ -n "${SIGIL_XVFB:-}" ] || { [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; }; then
    command -v xvfb-run > /dev/null \
      || die 'No display: install xvfb (with xauth), or use a graphical desktop.'
    printf 'xvfb-run\n-a\n'
  fi
}

# One QA session per QA directory: a parallel run would rewrite the same reports while this
# one checks them. A later session waits. Scripts this one starts inherit the lock.
enter_qa_session() {
  mkdir -p "$SIGIL_QA"
  if [ "${SIGIL_QA_HELD:-}" = "$SIGIL_QA" ]; then
    return
  fi
  exec 9> "$SIGIL_QA/.qa-session.lock"
  if ! flock -n 9; then
    echo "Waiting for another QA session in $SIGIL_QA ..."
    flock -w 3600 9 || die "Another QA session still holds $SIGIL_QA after 3600 s."
  fi
  export SIGIL_QA_HELD=$SIGIL_QA
}

# Only the locked report directory is disposable. Manual reports, other clones
# and the previous delivery kept for rollback must survive a full test run.
clean_qa_session() {
  [ "${SIGIL_QA_HELD:-}" = "$SIGIL_QA" ] || die 'QA cleanup requires the session lock.'
  assert_child "$SIGIL_QA" "$SIGIL_WORK" > /dev/null
  find "$SIGIL_QA" -mindepth 1 -maxdepth 1 ! -name .qa-session.lock ! -name rollback \
    -exec rm -rf -- {} +
}

# Names as well as contents, so a renamed, added or removed asset invalidates old evidence.
# The same recipe as Windows: name, newline, upper-case hash, newline, sorted by bytes.
source_fingerprint() {
  (cd -- "${1:-$SIGIL_ROOT}/game" && find . -type f -printf '%P\n' | LC_ALL=C sort \
    | xargs -d '\n' sha256sum \
    | awk '{ print substr($0, 67); print toupper($1) }' \
    | sha256sum | awk '{ print toupper($1) }')
}

# Runs one child in the QA directory and keeps its evidence, as Invoke-IsolatedGame does.
# run_isolated <name> <timeout s> [--no-display] <qa dir> -- <love arguments>
# Sets RUN_ID, RUN_STDOUT, RUN_SOURCE, RUN_BUILD. A child that fails stops the script.
run_isolated() {
  local name=$1 seconds=$2 no_display='' qa
  shift 2
  if [ "$1" = '--no-display' ]; then
    no_display=1
    shift
  fi
  qa=$1
  shift 2
  local runtime stdout stderr started code after finished prefix=()
  runtime=$(love_path)
  stdout="$qa/$name.stdout.txt"
  stderr="$qa/$name.stderr.txt"
  started=$(date -u +%FT%TZ)
  RUN_SOURCE=$(source_fingerprint)
  RUN_BUILD="$RUN_SOURCE:$(sha256sum "$runtime" | awk '{ print toupper($1) }')"
  RUN_ID=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')
  RUN_STDOUT=$stdout
  [ -n "$no_display" ] || mapfile -t prefix < <(display_prefix)
  # The game's own saves stay in this QA directory (PLAN G6): two runs from two
  # clones never share the QA identity's save files.
  mkdir -p -- "$qa/save"
  code=0
  (cd -- "$SIGIL_ROOT" \
    && XDG_DATA_HOME=$qa/save SIGIL_UI_QA_DIR=$qa SIGIL_QA_SOURCE_FINGERPRINT=$RUN_SOURCE \
      SIGIL_QA_BUILD_FINGERPRINT=$RUN_BUILD SIGIL_QA_RUN=$RUN_ID \
      timeout --kill-after=10 "$seconds" "${prefix[@]}" "$runtime" "$@") \
    > "$stdout" 2> "$stderr" || code=$?
  finished=$(date -u +%FT%TZ)
  after=$(source_fingerprint)
  python3 -I - "$qa/$name.evidence.json" "$started" "$finished" "$RUN_ID" "$runtime" \
    "$RUN_SOURCE" "$after" "$RUN_BUILD" "$code" "$@" << 'PY'
import json, sys
out, started, finished, run, executable, source, after, build, code, *arguments = sys.argv[1:]
json.dump({'started': started, 'finished': finished, 'run': run, 'arguments': arguments,
           'executable': executable, 'sourceFingerprint': source, 'sourceAfter': after,
           'buildFingerprint': build, 'sourceStable': after == source,
           'exitCode': int(code)}, open(out, 'w'), indent=2)
PY
  [ "$code" -ne 124 ] && [ "$code" -ne 137 ] || die "Timeout: $name. See $stdout and $stderr."
  [ "$code" -eq 0 ] || die "Failed: $name; exit $code. See $stdout and $stderr."
  [ "$after" = "$RUN_SOURCE" ] \
    || die "Source changed while $name ran; evidence is not a stable build. Rerun on a stable tree."
}

# A report that carries its run's receipt (qa/output.lua) is checked by that identity.
require_fresh() { # path [run id]
  [ -f "$1" ] || die "Test did not create its report: $1"
  grep -Eq "^QA run: ${2:-$RUN_ID}[[:space:]]*$" "$1" \
    || die "Report was not written by run ${2:-$RUN_ID}: $1"
}

# For a report without a receipt (baked masks, exports): it must be newer than the marker.
first_id() { # the first id = 'word' of a spec or legend file
  sed -n "/id[[:space:]]*=[[:space:]]*'[A-Za-z0-9_]*'/{s/.*id[[:space:]]*=[[:space:]]*'\([A-Za-z0-9_]*\)'.*/\1/p;q}" "$1"
}

newer_than() { # path marker
  [ -f "$1" ] || die "Test did not create its report: $1"
  [ "$1" -nt "$2" ] || die "Report was not freshly rewritten: $1"
}
