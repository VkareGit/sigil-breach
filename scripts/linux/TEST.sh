#!/usr/bin/env bash
# The whole test gate on Linux, the same as scripts/win/TEST.ps1.
# Usage: scripts/linux/TEST.sh [All|Architecture|Mechanics|Input|Render|Tools] [--timeout s]
#   [--jobs n]
# A full run needs --timeout 1800: the showcase walks every painted hall.
# --jobs n (1..8, default 1) runs the mechanics suites as n shards at once, each
# its own process and save folder, and also starts the input test and the
# showcase beside them; the measured tools stay alone and one after another.
# Only one process that holds every suite in turn catches a leak from one suite
# into the next, so a delivery (tools/linux/build.sh) still needs the evidence
# of a --jobs 1 run (source-selftest); the shards never write it.
source "$(dirname -- "${BASH_SOURCE[0]}")/../../tools/linux/project.sh"
suite=All
limit=300
jobs=1
while [ "$#" -gt 0 ]; do
  case "$1" in
    All | Architecture | Mechanics | Input | Render | Tools) suite=$1 ;;
    --timeout)
      limit=$2
      shift
      ;;
    --jobs)
      jobs=$2
      shift
      ;;
    *) die "Usage: TEST.sh [All|Architecture|Mechanics|Input|Render|Tools] [--timeout s] [--jobs n]" ;;
  esac
  shift
done
[ "$limit" -ge 10 ] && [ "$limit" -le 1800 ] || die 'The timeout must be 10..1800 s.'
[[ "$jobs" =~ ^[1-8]$ ]] || die 'The jobs must be 1..8.'
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
  All) flags=(selftest input-test showcase benchmark core-measure step-study audio-export startup-check resource-plateau measure-trial) ;;
  Mechanics) flags=(selftest) ;;
  Input) flags=(input-test) ;;
  Render) flags=(showcase) ;;
  Tools) flags=(benchmark core-measure step-study audio-export startup-check resource-plateau measure-trial) ;;
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
    resource-plateau) echo resource-plateau.txt ;;
  esac
}
# The mechanics shards (and, beside them, the input test and the showcase),
# each in the background with its own save folder; then every report checked.
parallel_start() { # flag name destination arguments...
  local flag=$1 name=$2 destination=$3
  shift 3
  (
    RUN_SAVE=$name
    run_isolated "$name" "$limit" "$destination" -- "$@"
    for report in "${PARALLEL_REPORTS[@]}"; do
      require_fresh "$destination/$report"
    done
  ) > "$SIGIL_QA/$name.parallel.txt" 2>&1 &
  parallel_pids+=("$!")
  parallel_names+=("$name")
}
if [ "$jobs" -gt 1 ]; then
  parallel_pids=()
  parallel_names=()
  remaining=()
  for flag in ${flags[@]+"${flags[@]}"}; do
    case "$flag" in
      selftest)
        for ((shard = 1; shard <= jobs; shard++)); do
          PARALLEL_REPORTS=("test-results-shard-$shard-of-$jobs.txt")
          echo "Testing source: --selftest shard $shard/$jobs (parallel)"
          parallel_start selftest "source-selftest-$shard-of-$jobs" "$SIGIL_QA" \
            "$SIGIL_GAME" --selftest "--shard=$shard/$jobs"
        done
        ;;
      input-test | showcase)
        read -r -a PARALLEL_REPORTS <<< "$(reports_of "$flag")"
        echo "Testing source: --$flag (parallel)"
        parallel_start "$flag" "source-$flag" "$SIGIL_QA" "$SIGIL_GAME" "--$flag"
        ;;
      *) remaining+=("$flag") ;;
    esac
  done
  failed=0
  for i in "${!parallel_pids[@]}"; do
    if wait "${parallel_pids[$i]}"; then
      echo "PASS: ${parallel_names[$i]}"
    else
      echo "FAIL: ${parallel_names[$i]}"
      cat "$SIGIL_QA/${parallel_names[$i]}.parallel.txt"
      failed=1
    fi
  done
  [ "$failed" -eq 0 ] || die 'A parallel run failed.'
  if [[ " ${flags[*]-} " == *" selftest "* ]]; then
    total=0
    for ((shard = 1; shard <= jobs; shard++)); do
      count=$(sed -n 's/^MECHANICS \/ ASSETS TOTAL: \([0-9]*\) passing checks\./\1/p' \
        "$SIGIL_QA/test-results-shard-$shard-of-$jobs.txt")
      [ -n "$count" ] || die "Shard $shard/$jobs has no total."
      total=$((total + count))
    done
    echo "MECHANICS / ASSETS TOTAL: $total passing checks in $jobs shards."
  fi
  flags=(${remaining[@]+"${remaining[@]}"})
fi
for flag in ${flags[@]+"${flags[@]}"}; do
  if [ "$flag" = measure-trial ]; then
    # The measurement protocol walked once as a measurement walks it, with its default
    # populations (tools' smoke profile, a few steps and frames): every phase builds its
    # crowd on the same map. Its numbers are not a measurement.
    echo 'Testing source: MEASURE.sh --pairs 1 --trial'
    trial="$SIGIL_QA/measure-trial"
    "$SIGIL_ROOT/scripts/linux/MEASURE.sh" --pairs 1 --trial --out "$trial" \
      > "$SIGIL_QA/measure-trial.txt" 2>&1 \
      || { tail -20 "$SIGIL_QA/measure-trial.txt"; die 'MEASURE.sh failed.'; }
    grep -q '^frame prepared_population_256_live' "$trial/summary.txt" \
      || die 'MEASURE.sh measured no frame of 256 bodies.'
    echo 'PASS: MEASURE.sh --trial'
    continue
  fi
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
  if [ "$flag" = resource-plateau ]; then
    # Three cycles show a left session still held (about a minute).
    SIGIL_RESOURCE_CYCLES=3 run_isolated "$name" "$limit" "$destination" -- "${arguments[@]}"
  else
    run_isolated "$name" "$limit" "$destination" -- "${arguments[@]}"
  fi
  for report in $(reports_of "$flag"); do
    path="$destination/$report"
    require_fresh "$path"
    if [ -n "$smoke" ] || [ "$flag" = startup-check ] || [ "$flag" = resource-plateau ]; then
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
