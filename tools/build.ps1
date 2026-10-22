param(
    [string]$RuntimeRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) 'toolchain\love-11.5-win64')
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'project.ps1')
$project = Get-Project
$taskRoot = $project.Root
$sourceRoot = Join-Path $taskRoot 'game'
$qaRoot = $project.Qa
$outputsRoot = Join-Path $taskRoot 'outputs'
$releaseRoot = $project.Release
$stageRoot = Join-Path $outputsRoot ('.' + $project.Name + '-build-' + [Guid]::NewGuid().ToString('N'))
$documents = $project.Documents
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$stageRoot = Assert-ChildPath $stageRoot $outputsRoot
$releaseRoot = Assert-ChildPath $releaseRoot $outputsRoot
# A failed build removes its own unfinished stage instead of leaving it in outputs.
trap {
    if ($stageRoot -and (Test-Path -LiteralPath $stageRoot)) { Remove-Item -LiteralPath $stageRoot -Recurse -Force }
    break
}
foreach ($required in @('main.lua', 'conf.lua', 'assets\art\prompts-fresco-world-v12.json', 'assets\art\prompts-fresco-enemies-v12.json', 'assets\art\weapon-provenance-v16.json', 'assets\art\prompts-gui-v16.json', 'assets\fonts\painted-v16\prompts-v16.json', 'assets\art\prompts-detail-v17.json', 'assets\art\impact-scars-v17.png') + $documents) {
    if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot $required) -PathType Leaf)) { throw "Missing source file: $required" }
}
foreach ($required in @('love.exe', 'license.txt')) {
    if (-not (Test-Path -LiteralPath (Join-Path $RuntimeRoot $required) -PathType Leaf)) { throw "Missing LOVE runtime file: $required" }
}
$dlls = @(Get-ChildItem -LiteralPath $RuntimeRoot -Filter '*.dll' -File)
if ($dlls.Count -eq 0) { throw 'No LOVE runtime DLLs found.' }
if (-not (Test-Path -LiteralPath (Join-Path $qaRoot 'render-results.txt') -PathType Leaf)) { throw 'Missing current render report; run final --showcase first.' }
$layoutAuditPath = Join-Path $qaRoot 'ui-layout-audit.txt'
if (-not (Test-Path -LiteralPath $layoutAuditPath -PathType Leaf)) { throw 'Missing measured frame-interior audit.' }
$layoutAudit = [IO.File]::ReadAllText($layoutAuditPath)
if ($layoutAudit -notmatch '\d+ interior checks, 0 issues' -or $layoutAudit -match '\b[1-9]\d* issues\b') {
    throw 'The final UI showcase must report zero frame-interior/collision issues before packaging.'
}

Write-Output ('BUILD ' + $project.Version + ': source, documents, runtime and source render evidence. Packaged verification follows separately.')
New-Item -ItemType Directory -Force -Path $outputsRoot, $qaRoot | Out-Null
New-Item -ItemType Directory -Path $stageRoot | Out-Null
$sourceDestination = Join-Path $stageRoot 'source'
New-Item -ItemType Directory -Path $sourceDestination | Out-Null
Get-ChildItem -LiteralPath $sourceRoot -Force | Copy-Item -Destination $sourceDestination -Recurse -Force
foreach ($name in $documents) { Copy-Item -LiteralPath (Join-Path $sourceDestination $name) -Destination $stageRoot }

$lovePath = Join-Path $stageRoot 'SIGIL-BREACH.love'
Write-Archive $sourceDestination $lovePath
$exePath = Join-Path $stageRoot 'SIGIL-BREACH.exe'
$exeStream = [IO.File]::Open($exePath, [IO.FileMode]::CreateNew)
try {
    foreach ($part in @((Join-Path $RuntimeRoot 'love.exe'), $lovePath)) {
        $partStream = [IO.File]::OpenRead($part)
        try { $partStream.CopyTo($exeStream) } finally { $partStream.Dispose() }
    }
}
finally { $exeStream.Dispose() }
foreach ($dll in $dlls) { Copy-Item -LiteralPath $dll.FullName -Destination $stageRoot }
Copy-Item -LiteralPath (Join-Path $RuntimeRoot 'license.txt') -Destination (Join-Path $stageRoot 'LOVE-LICENSE.txt')
Copy-Item -LiteralPath (Join-Path $qaRoot 'architecture.txt') -Destination (Join-Path $stageRoot 'KONTROLA-KODU.txt')
Copy-Item -LiteralPath (Join-Path $qaRoot 'render-results.txt') -Destination (Join-Path $stageRoot 'RENDER.txt')
Copy-Item -LiteralPath (Join-Path $qaRoot 'ui-layout-audit.txt') -Destination (Join-Path $stageRoot 'GUI-UKLAD.txt')
Copy-Item -LiteralPath (Join-Path $qaRoot 'attack-timelines.txt') -Destination (Join-Path $stageRoot 'ANIMACJE-ATAKOW.txt')
Copy-Item -LiteralPath (Join-Path $qaRoot 'weapon-timeline.txt') -Destination (Join-Path $stageRoot 'ANIMACJE-BRONI.txt')
Copy-Item -LiteralPath (Join-Path $qaRoot 'fresco-motion-clocks.txt') -Destination (Join-Path $stageRoot 'ANIMACJE-BRONI-FRESK.txt')
foreach ($evidence in $project.RenderEvidence + @('DURABILITY-REVIEW.txt','art-checks.txt','type-tests.txt','ability-registration-v23.csv','golden-current.lua')) {
    Copy-Item -LiteralPath (Join-Path $qaRoot $evidence) -Destination $stageRoot
}
if (Test-Path -LiteralPath (Join-Path $qaRoot 'art-preservation.txt') -PathType Leaf) {
    Copy-Item -LiteralPath (Join-Path $qaRoot 'art-preservation.txt') -Destination $stageRoot
}

$buildInfo = @(
    ($project.Title + ' - source snapshot and Windows runtime build.'),
    ('Built UTC: ' + [DateTime]::UtcNow.ToString('o')),
    ('Build script: ' + $PSCommandPath),
    ('Source: ' + $sourceRoot),
    ('Runtime: ' + [IO.Path]::GetFullPath($RuntimeRoot)),
    ('Source files: ' + @(Get-ChildItem -LiteralPath $sourceDestination -File -Recurse -Force).Count),
    'SIGIL-BREACH.love is a ZIP of the exact included source snapshot.',
    'SIGIL-BREACH.exe consists of love.exe followed by that .love archive.',
    'Next: run tools/verify.ps1 from the development workspace.',
    'Verification runs the packaged EXE tests, verifies SHA-256, and creates the final Windows ZIP.',
    'The build step does not claim packaged test success or publish a new Windows ZIP.',
    'Balance and complete-run evidence are added only after a fresh packaged selftest.',
    'Native UI evidence is included only when a separate native-ui-results.txt exists.'
)
$buildInfo | Set-Content -LiteralPath (Join-Path $stageRoot 'BUDOWA-PACZKI.txt') -Encoding utf8

# A rebuild preserves the previous current-release directory; earlier releases are untouched.
if (Test-Path -LiteralPath $releaseRoot) {
    if (-not (Test-Path -LiteralPath $releaseRoot -PathType Container)) { throw 'The target release path is not a directory.' }
    $runningPath = Join-Path $releaseRoot 'SIGIL-BREACH.exe'
    $running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $runningPath })
    if ($running.Count -gt 0) { throw 'Close the currently running packaged game before rebuilding it.' }
    $backup = Join-Path $qaRoot ('release-before-build-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    $checkedRelease = Assert-ChildPath $releaseRoot $outputsRoot
    $checkedBackup = Assert-ChildPath $backup $qaRoot
    Move-Item -LiteralPath $checkedRelease -Destination $checkedBackup
    Write-Output ('Preserved previous current-release build: ' + $checkedBackup)
}
$checkedStage = Assert-ChildPath $stageRoot $outputsRoot
$checkedTarget = Assert-ChildPath $releaseRoot $outputsRoot
Move-Item -LiteralPath $checkedStage -Destination $checkedTarget

foreach ($preview in @(
    @{Source = '31-cover.png'; Target = ($project.Name + '.png')},
    @{Source = '05-shop.png'; Target = ($project.Name + '-sklep.png')},
    @{Source = '04-shrine.png'; Target = ($project.Name + '-zar.png')},
    @{Source = '12-help.png'; Target = ($project.Name + '-bestiariusz.png')},
    @{Source = '01-menu.png'; Target = ($project.Name + '-menu.png')},
    @{Source = '68-field-catalog.png'; Target = ($project.Name + '-poligon.png')},
    @{Source = 'archive-sign-6.png'; Target = ($project.Name + '-znaki.png')},
    @{Source = 'type-comparison-1280.png'; Target = ($project.Name + '-litery.png')}
)) {
    $from = Join-Path $qaRoot $preview.Source
    if (Test-Path -LiteralPath $from -PathType Leaf) { Copy-Item -LiteralPath $from -Destination (Join-Path $outputsRoot $preview.Target) -Force }
}
Write-Output ('BUILD complete: ' + $releaseRoot)
Write-Output 'Run tools/verify.ps1 to execute packaged tests and create the verified Windows ZIP.'
Get-Item -LiteralPath (Join-Path $releaseRoot 'SIGIL-BREACH.exe'), (Join-Path $releaseRoot 'SIGIL-BREACH.love') | Select-Object FullName, Length

