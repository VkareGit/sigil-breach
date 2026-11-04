#!/usr/bin/env bash
# The whole test gate on Linux, the same as scripts/win/TEST.ps1.
# Usage: scripts/linux/TEST.sh [All|Architecture|Mechanics|Input|Render|Tools] [--timeout s]
# A full run needs --timeout 1800: the showcase walks every painted hall.
source "$(dirname -- "${BASH_SOURCE[0]}")/../../tools/linux/project.sh"
suite=All
limit=300
while [ "$#" -gt 0 ]; do
  case "$1" in
    All | Architecture | Mechanics | Input | Render | Tools) suite=$1 ;;
    --timeout)
      limit=$2
      shift
      ;;
    *) die "Usage: TEST.sh [All|Architecture|Mechanics|Input|Render|Tools] [--timeout s]" ;;
  esac
  shift
done
[ "$limit" -ge 10 ] && [ "$limit" -le 1800 ] || die 'The timeout must be 10..1800 s.'
enter_qa_session
if [ "$suite" = All ]; then
  # A full run starts from an empty folder, so every report in it is this run's and nothing
  # a retired test wrote lingers. The session lock and the delivery kept for rollback stay.
  clean_qa_session
fi
if [ "$suite" = All ] || [ "$suite" = Architecture ]; then
  "$SIGIL_ROOT/scripts/linux/FORMAT.sh" --check || die 'Lua formatting differs; run FORMAT.sh.'
  "$SIGIL_ROOT/tools/linux/check-platform.sh"
  "$SIGIL_ROOT/tools/linux/check.sh"
fi
case "$suite" in
  All) flags=(selftest input-test showcase benchmark core-measure step-study audio-export startup-check) ;;
  Mechanics) flags=(selftest) ;;
  Input) flags=(input-test) ;;
  Render) flags=(showcase) ;;
  Tools) flags=(benchmark core-measure step-study audio-export startup-check) ;;
  *) flags=() ;;
esac
reports_of() {
  case "$1" in
    selftest) echo test-results.txt ;;
    input-test) echo input-results.txt ;;
    showcase) echo render-results.txt ;;
    benchmark) echo benchmark.txt ;;
    core-measure) echo core-measure.txt ;;
    step-study) echo step-study.txt ;;
    audio-export) echo audio-export.txt sounds/report.txt music/report.txt ;;
    startup-check) echo startup-check.txt ;;
  esac
}
for flag in ${flags[@]+"${flags[@]}"}; do
  smoke=''
  case "$flag" in benchmark | core-measure | step-study | audio-export) smoke=1 ;; esac
  name="source-$flag"
  arguments=("$SIGIL_GAME" "--$flag")
  # Smoke never overwrites the full measurement reports used for comparison.
  destination=$SIGIL_QA
  if [ -n "$smoke" ]; then
    name+=-smoke
    arguments+=(--qa-smoke)
    destination="$SIGIL_QA/tool-smoke"
  fi
  mkdir -p "$destination"
  echo "Testing source: --$flag (smoke=${smoke:-0})"
  run_isolated "$name" "$limit" "$destination" -- "${arguments[@]}"
  for report in $(reports_of "$flag"); do
    path="$destination/$report"
    require_fresh "$path"
    if [ -n "$smoke" ] || [ "$flag" = startup-check ]; then
      profile=full
      [ -z "$smoke" ] || profile=smoke
      grep -Fq "QA COMPLETE: $(basename "$report") profile=$profile" "$path" \
        || die "Incomplete tool report: $path"
      grep -Fq "Source fingerprint: $RUN_SOURCE" "$path" \
        || die "Tool report belongs to another source: $path"
      grep -Fq "Build fingerprint: $RUN_BUILD" "$path" \
        || die "Tool report belongs to another runtime: $path"
    fi
  done
  echo "PASS: --$flag"
done
