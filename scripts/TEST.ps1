param(
    [ValidateSet('All', 'Architecture', 'Mechanics', 'Input', 'Render', 'Tools')][string]$Suite = 'All',
    [ValidateRange(10, 1800)][int]$TestTimeoutSeconds = 300
)
$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'tools/project.ps1')
$project = Get-Project
$session = Enter-QaSession $project.Qa
try {
    if ($Suite -eq 'All' -or $Suite -eq 'Architecture') {
        & (Join-Path $PSScriptRoot 'FORMAT.ps1') -Check
        if ($LASTEXITCODE -ne 0) { throw 'Lua formatting differs; run FORMAT.ps1.' }
        & (Join-Path (Split-Path -Parent $PSScriptRoot) 'tools/check-platform.ps1')
        & (Join-Path (Split-Path -Parent $PSScriptRoot) 'tools/check.ps1')
    }
    $flags = switch ($Suite) {
        'All' { '--selftest'; '--input-test'; '--showcase'; '--benchmark'; '--core-measure'; '--step-study'; '--audio-export'; '--startup-check' }
        'Mechanics' { '--selftest' }
        'Input' { '--input-test' }
        'Render' { '--showcase' }
        'Tools' { '--benchmark'; '--core-measure'; '--step-study'; '--audio-export'; '--startup-check' }
    }
    $reports = @{
        '--selftest' = @('test-results.txt')
        '--input-test' = @('input-results.txt')
        '--showcase' = @('render-results.txt')
        '--benchmark' = @('benchmark.txt')
        '--core-measure' = @('core-measure.txt')
        '--step-study' = @('step-study.txt')
        '--audio-export' = @('audio-export.txt', 'sounds/report.txt', 'music/report.txt')
        '--startup-check' = @('startup-check.txt')
    }
    foreach ($flag in $flags) {
        $smoke = $flag -in @('--benchmark', '--core-measure', '--step-study', '--audio-export')
        $name = 'source-' + $flag.TrimStart('-')
        if ($smoke) { $name += '-smoke' }
        # Smoke never overwrites the full measurement reports used for comparison.
        $destination = if ($smoke) { Join-Path $project.Qa 'tool-smoke' } else { $project.Qa }
        New-Item -ItemType Directory -Force -Path $destination | Out-Null
        Write-Host "Testing source: $flag (smoke=$smoke)"
        $arguments = @(('"' + $project.Source + '"'), $flag)
        if ($smoke) { $arguments += '--qa-smoke' }
        $runtime = Get-LoveRuntime -Console
        $run = Invoke-IsolatedGame $runtime $arguments $project.Root $destination $name $TestTimeoutSeconds
        foreach ($report in $reports[$flag]) {
            $path = Join-Path $destination $report
            # Every report names the run that wrote it (qa/output.lua).
            Require-Fresh $path $run.Started ([DateTime]::MinValue) $run.RunId
            if ($smoke -or $flag -eq '--startup-check') {
                $content = Get-Content -LiteralPath $path -Raw
                $profile = if ($smoke) { 'smoke' } else { 'full' }
                $marker = 'QA COMPLETE: ' + (Split-Path $report -Leaf) + ' profile=' + $profile
                if (-not $content.Contains($marker)) { throw "Incomplete tool report: $path" }
                if (-not $content.Contains('Source fingerprint: ' + $run.SourceFingerprint)) {
                    throw "Tool report belongs to another source: $path"
                }
                if (-not $content.Contains('Build fingerprint: ' + $run.BuildFingerprint)) {
                    throw "Tool report belongs to another runtime: $path"
                }
            }
        }
        Write-Host "PASS: $flag"
    }
}
finally { Exit-QaSession $session }
