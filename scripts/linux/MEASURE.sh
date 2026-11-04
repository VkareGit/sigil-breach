#!/usr/bin/env bash
# The measurement protocol, as scripts/win/MEASURE.ps1: every measurement is its own process
# with a 300-step warm-up; pairs alternate their order; the median and IQR of each variant are
# reported for the simulation step (--core-measure, map qa_crowd) and the rendered frame
# (--benchmark), and a comparison is one of
#   NO REGRESSION   median after <= 1.05 x median before, both IQR <= 5 %
#   REGRESSION      median after > 1.05 x before and the gap > both IQR
#   INCONCLUSIVE    anything else (repeat with more pairs; still inconclusive is a regression)
# Usage: scripts/linux/MEASURE.sh [--before tree] [--after tree] [--pairs n]
#                                 [--populations 20,96,256] [--out dir]
source "$(dirname -- "${BASH_SOURCE[0]}")/../../tools/linux/project.sh"
before=game
after=''
pairs=5
populations=20,96,256
out=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --before) before=$2 ;;
    --after) after=$2 ;;
    --pairs) pairs=$2 ;;
    --populations) populations=$2 ;;
    --out) out=$2 ;;
    *) die 'Unknown option; see the head of MEASURE.sh.' ;;
  esac
  shift 2
done
[ "$pairs" -ge 1 ] && [ "$pairs" -le 50 ] || die 'Pairs must be 1..50.'
[ -n "$out" ] || out="$SIGIL_ROOT/work/qa/measure-$(date +%Y%m%d-%H%M%S)"
out=$(realpath -m -- "$out")
mkdir -p "$out"
before=$(realpath -- "$before")
[ -z "$after" ] || after=$(realpath -- "$after")
runtime=$(love_path)
mapfile -t prefix < <(display_prefix)
samples="$out/samples.txt"
: > "$samples"
# Each process asks for high priority where the system allows it.
priority=()
if nice -n -5 true 2> /dev/null; then
  priority=(nice -n -5)
fi
pinned() { # tree flag log
  local tree=$1 flag=$2 log=$3
  (cd -- "$SIGIL_ROOT" \
    && timeout --kill-after=10 1800 "${priority[@]}" "${prefix[@]}" "$runtime" "$tree" "$flag") \
    > "$log" 2> "$log.stderr.txt" || die "$flag failed in $tree; see $log"
}
measure() { # variant tree index
  local variant=$1 tree=$2 index=$3 count dir line
  for count in ${populations//,/ }; do
    dir="$out/$variant/core-$count-$index"
    mkdir -p "$dir"
    SIGIL_UI_QA_DIR=$dir SIGIL_CORE_POPULATION=$count SIGIL_CROWD_MAP=qa_crowd \
      SIGIL_CORE_WARMUP=300 SIGIL_CORE_STEPS=2400 SIGIL_CORE_JOURNAL_SECONDS=1 \
      pinned "$tree" --core-measure "$dir/stdout.txt"
    line=$(sed -n '/step: [0-9]* bodies awake/{s/.*step: \([0-9]*\) bodies awake; whole simulation step median \([0-9.]*\) ms.*/\1 \2/p;q}' \
      "$dir/core-measure.txt")
    [ -n "$line" ] || die "No step measurement in $dir"
    echo "$variant|step ${line% *} bodies (ms)|${line#* }" >> "$samples"
  done
  dir="$out/$variant/bench-$index"
  mkdir -p "$dir"
  SIGIL_UI_QA_DIR=$dir SIGIL_BENCH_POPULATIONS=$populations SIGIL_BENCH_WARMUP=300 \
    SIGIL_BENCH_FRAMES=720 pinned "$tree" --benchmark "$dir/stdout.txt"
  sed -n -E "s/^(complete_[A-Za-z0-9_]+|prepared_population_[0-9]+_live) total n=[0-9]+ median_ms=([0-9.]+).*/$variant|frame \1 (ms)|\2/p" \
    "$dir/benchmark.txt" >> "$samples"
}
enter_qa_session
for ((i = 1; i <= pairs; i++)); do
  order=(before after)
  [ $((i % 2)) -ne 0 ] || order=(after before)
  for variant in "${order[@]}"; do
    tree=$before
    [ "$variant" = before ] || tree=$after
    [ -n "$tree" ] || continue
    echo "Pair $i : $variant"
    measure "$variant" "$tree" "$i"
  done
done
python3 -I - "$samples" "$out/summary.txt" "$before" "$after" "$pairs" "$populations" << 'PY'
import sys
samples, summary, before, after, pairs, populations = sys.argv[1:]
values = {}
for line in open(samples):
    variant, metric, value = line.rstrip('\n').split('|')
    values.setdefault((variant, metric), []).append(float(value))
def quantile(data, p):
    data = sorted(data)
    position = (len(data) - 1) * p
    low, high = int(position), min(int(position) + 1, len(data) - 1)
    return data[low] + (data[high] - data[low]) * (position - low)
variants = ['before'] + (['after'] if after else [])
report = ['V11 MEASUREMENT PROTOCOL', f'before = {before}']
if after:
    report.append(f'after = {after}')
report.append(f'pairs = {pairs} (order alternates), populations = {populations}, warm-up 300 '
              'steps/frames, 2400 steps and 720 frames sampled, map qa_crowd, high priority')
regressed = False
for metric in sorted({m for _, m in values}):
    stats = {}
    for variant in variants:
        data = values[(variant, metric)]
        median = quantile(data, 0.5)
        iqr = quantile(data, 0.75) - quantile(data, 0.25)
        stats[variant] = median, iqr
        shown = ' '.join(f'{v:.4f}' for v in data)
        report.append(f'{metric:<48} {variant:<6} median {median:9.4f}  IQR {iqr:8.4f} '
                      f'({100 * iqr / max(1e-9, median):5.1f} %)  n={len(data)}  [{shown}]')
    if after:
        (b, bi), (a, ai) = stats['before'], stats['after']
        ratio = a / max(1e-9, b)
        tight = bi <= 0.05 * b and ai <= 0.05 * a
        if ratio <= 1.05 and tight:
            verdict = 'NO REGRESSION'
        elif ratio > 1.05 and a - b > ai + bi:
            verdict = 'REGRESSION'
        else:
            verdict = 'INCONCLUSIVE'
        report.append(f'{metric:<48} after/before {ratio:.3f}  {verdict}')
        regressed = regressed or verdict != 'NO REGRESSION'
open(summary, 'w').write('\n'.join(report) + '\n')
print('\n'.join(report))
print('Summary:', summary)
# A build can stop on this: anything but a clean comparison counts as a regression.
sys.exit(1 if regressed else 0)
PY
