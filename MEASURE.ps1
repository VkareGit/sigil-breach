param(
    # The game tree measured as "before" (a worktree of the reference commit)
    # and, optionally, as "after" (usually game, the tree under change).
    [string]$Before = 'game',
    [string]$After = '',
    [ValidateRange(1, 50)][int]$Pairs = 5,
    [string]$Populations = '20,96,256',
    [string]$Out = ''
)
# The measurement protocol: every measurement is its own process with a
# 300-step warm-up; pairs alternate their order (before-after, after-before,
# ...); the median and the interquartile range (IQR) of each variant are
# reported separately for the simulation step (--core-measure, map qa_crowd)
# and the rendered frame (--benchmark), and a comparison is one of
#   NO REGRESSION   median after <= 1.05 x median before, both IQR <= 5 %
#   REGRESSION      median after > 1.05 x before and the gap > both IQR
#   INCONCLUSIVE    anything else (repeat with more pairs; still
#                   inconclusive counts as a regression)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'tools/project.ps1')
$project = Get-Project
$runtime = Get-LoveRuntime -Console
if (-not $Out) { $Out = Join-Path $project.Root ('work/v11-measure/' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
$Out = [IO.Path]::GetFullPath($Out)
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$variants = [ordered]@{ before = [IO.Path]::GetFullPath($Before) }
if ($After) { $variants['after'] = [IO.Path]::GetFullPath($After) }
$counts = $Populations.Split(',') | ForEach-Object { [int]$_.Trim() }
$samples = @{}
function Add-Sample([string]$Variant, [string]$Metric, [double]$Value) {
    $key = $Variant + '|' + $Metric
    if (-not $samples.ContainsKey($key)) { $samples[$key] = New-Object System.Collections.Generic.List[double] }
    $samples[$key].Add($Value)
}
# Every measured process runs at high priority. (Pinning it to six logical
# processors was tried for E1 and made the spread worse: not used.)
function Invoke-Pinned([string]$Tree, [string]$Flag, [string]$Log) {
    $process = Start-SigilProcess $runtime @(('"' + $Tree + '"'), $Flag) $project.Root $Log ($Log + '.stderr.txt')
    $null = $process.Handle
    try {
        $process.PriorityClass = 'High'
    }
    catch { }
    if (-not $process.WaitForExit(1800 * 1000)) { Stop-SigilProcess $process; throw "Timeout: $Flag; see $Log" }
    $process.WaitForExit(); $process.Refresh()
    if ($process.ExitCode -ne 0) { throw "$Flag failed in $Tree (exit $($process.ExitCode)); see $Log" }
}
function Invoke-Measure([string]$Variant, [string]$Tree, [int]$Index) {
    foreach ($count in $counts) {
        $dir = Join-Path $Out ("$Variant/core-$count-$Index")
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $env:SIGIL_UI_QA_DIR = $dir
        $env:SIGIL_CORE_POPULATION = "$count"
        $env:SIGIL_CROWD_MAP = 'qa_crowd'
        $env:SIGIL_CORE_WARMUP = '300'
        $env:SIGIL_CORE_STEPS = '2400'
        $env:SIGIL_CORE_JOURNAL_SECONDS = '1'
        Invoke-Pinned $Tree '--core-measure' (Join-Path $dir 'stdout.txt')
        $text = Get-Content -Raw (Join-Path $dir 'core-measure.txt')
        $m = [regex]::Match($text, 'step: (\d+) bodies awake; whole simulation step median ([\d.]+) ms')
        if (-not $m.Success) { throw "No step measurement in $dir" }
        Add-Sample $Variant ('step ' + $m.Groups[1].Value + ' bodies (ms)') ([double]$m.Groups[2].Value)
    }
    $dir = Join-Path $Out ("$Variant/bench-$Index")
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $env:SIGIL_UI_QA_DIR = $dir
    $env:SIGIL_BENCH_POPULATIONS = $Populations
    $env:SIGIL_BENCH_WARMUP = '300'
    $env:SIGIL_BENCH_FRAMES = '720'
    Invoke-Pinned $Tree '--benchmark' (Join-Path $dir 'stdout.txt')
    foreach ($line in Get-Content (Join-Path $dir 'benchmark.txt')) {
        $m = [regex]::Match($line, '^(complete_\w+|prepared_population_\d+_live) total n=\d+ median_ms=([\d.]+)')
        if ($m.Success) { Add-Sample $Variant ('frame ' + $m.Groups[1].Value + ' (ms)') ([double]$m.Groups[2].Value) }
    }
}
function Quantile([double[]]$Values, [double]$P) {
    $sorted = $Values | Sort-Object
    $position = ($sorted.Count - 1) * $P
    $low = [math]::Floor($position)
    $high = [math]::Ceiling($position)
    return $sorted[$low] + ($sorted[$high] - $sorted[$low]) * ($position - $low)
}
$session = Enter-QaSession $project.Qa
try {
    for ($i = 1; $i -le $Pairs; $i++) {
        $order = @($variants.Keys)
        if ($i % 2 -eq 0) { [array]::Reverse($order) }
        foreach ($variant in $order) {
            Write-Host "Pair $i : $variant"
            Invoke-Measure $variant $variants[$variant] $i
        }
    }
}
finally {
    foreach ($name in 'SIGIL_UI_QA_DIR', 'SIGIL_CORE_POPULATION', 'SIGIL_CROWD_MAP', 'SIGIL_CORE_WARMUP', 'SIGIL_CORE_STEPS', 'SIGIL_BENCH_FRAMES',
        'SIGIL_CORE_JOURNAL_SECONDS', 'SIGIL_BENCH_POPULATIONS', 'SIGIL_BENCH_WARMUP') {
        Remove-Item "Env:$name" -ErrorAction SilentlyContinue
    }
    Exit-QaSession $session
}
$report = New-Object System.Collections.Generic.List[string]
$report.Add('V11 MEASUREMENT PROTOCOL')
foreach ($variant in $variants.Keys) { $report.Add("$variant = $($variants[$variant])") }
$report.Add("pairs = $Pairs (order alternates), populations = $Populations, warm-up 300 steps/frames, 2400 steps and 720 frames sampled, map qa_crowd, high priority")
$metrics = $samples.Keys | ForEach-Object { $_.Split('|')[1] } | Sort-Object -Unique
foreach ($metric in $metrics) {
    $stats = @{}
    foreach ($variant in $variants.Keys) {
        $values = [double[]]$samples[$variant + '|' + $metric]
        $median = Quantile $values 0.5
        $iqr = (Quantile $values 0.75) - (Quantile $values 0.25)
        $stats[$variant] = @{ Median = $median; Iqr = $iqr }
        $report.Add(('{0,-48} {1,-6} median {2,9:F4}  IQR {3,8:F4} ({4,5:F1} %)  n={5}  [{6}]' -f
                $metric, $variant, $median, $iqr, (100 * $iqr / [math]::Max(1e-9, $median)), $values.Count,
                (($values | ForEach-Object { $_.ToString('F4') }) -join ' ')))
    }
    if ($After) {
        $b, $a = $stats['before'], $stats['after']
        $ratio = $a.Median / [math]::Max(1e-9, $b.Median)
        $tight = ($b.Iqr -le 0.05 * $b.Median) -and ($a.Iqr -le 0.05 * $a.Median)
        $verdict = if ($ratio -le 1.05 -and $tight) { 'NO REGRESSION' }
        elseif ($ratio -gt 1.05 -and ($a.Median - $b.Median) -gt ($a.Iqr + $b.Iqr)) { 'REGRESSION' }
        else { 'INCONCLUSIVE' }
        $report.Add(('{0,-48} after/before {1:F3}  {2}' -f $metric, $ratio, $verdict))
        if ($verdict -ne 'NO REGRESSION') { $regressed = $true }
    }
}
$path = Join-Path $Out 'summary.txt'
[IO.File]::WriteAllLines($path, $report)
$report | ForEach-Object { Write-Host $_ }
Write-Host "Summary: $path"
# A build can stop on this: anything but a clean comparison counts as a regression.
if ($regressed) { exit 1 }
