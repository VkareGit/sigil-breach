param(
    [string]$RuntimeRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) 'toolchain\love-11.5-win64')
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'project.ps1')
. (Join-Path $PSScriptRoot 'package.ps1')
$project = Get-Project
$taskRoot = $project.Root
$sourceRoot = Join-Path $taskRoot 'game'
$qaRoot = $project.Qa
$outputsRoot = Join-Path $taskRoot 'outputs'
$releaseRoot = $project.Release
$stageRoot = Join-Path $outputsRoot ('.' + $project.Name + '-build-' + [Guid]::NewGuid().ToString('N'))
$playerRoot = Join-Path $outputsRoot ($project.Name + '-Player')
$playerStage = Join-Path $outputsRoot ('.' + $project.Name + '-player-build-' + [Guid]::NewGuid().ToString('N'))
$documents = $project.Documents
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$stageRoot = Assert-ChildPath $stageRoot $outputsRoot
$releaseRoot = Assert-ChildPath $releaseRoot $outputsRoot
$playerRoot = Assert-ChildPath $playerRoot $outputsRoot
$playerStage = Assert-ChildPath $playerStage $outputsRoot
# A failed build removes its own unfinished stage instead of leaving it in outputs.
trap {
    if ($stageRoot -and (Test-Path -LiteralPath $stageRoot)) { Remove-Item -LiteralPath $stageRoot -Recurse -Force }
    if ($playerStage -and (Test-Path -LiteralPath $playerStage)) { Remove-Item -LiteralPath $playerStage -Recurse -Force }
    break
}
foreach ($required in @('main.lua', 'conf.lua', 'assets\art\prompts-fresco-world-v12.json', 'assets\art\prompts-fresco-enemies-v12.json', 'assets\art\weapon-provenance-v16.json', 'assets\art\shotgun-iron-v16.png', 'assets\art\revolver-iron-v16.png', 'assets\art\prompts-gui-v16.json', 'assets\fonts\painted-v16\prompts-v16.json', 'assets\art\prompts-detail-v17.json', 'assets\art\impact-scars-v17.png', 'assets\art\ritual-medallion-v31.png', 'assets\art\ritual-provenance-v31.json') + $documents) {
    if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot $required) -PathType Leaf)) { throw "Missing source file: $required" }
}
foreach ($required in @('love.exe', 'lovec.exe', 'license.txt')) {
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
$sourceFingerprint = Get-SourceFingerprint $taskRoot
$sourceFiles = @(Get-PackageTree $sourceRoot)
$evidenceRuntime = Join-Path $RuntimeRoot 'lovec.exe'
if (Test-Path -LiteralPath (Join-Path $sourceRoot 'build-fingerprint.txt')) { throw 'Generated build-fingerprint.txt must not live in the development game tree.' }
$evidence = @(
    (Assert-PackageEvidence $qaRoot 'architecture' $sourceFingerprint @('architecture.txt') $evidenceRuntime),
    (Assert-PackageEvidence $qaRoot 'source-selftest' $sourceFingerprint @('test-results.txt') $evidenceRuntime),
    (Assert-PackageEvidence $qaRoot 'source-input-test' $sourceFingerprint @('input-results.txt') $evidenceRuntime),
    (Assert-PackageEvidence $qaRoot 'source-showcase' $sourceFingerprint @('render-results.txt', 'ui-layout-audit.txt') $evidenceRuntime)
)

Write-Output ('BUILD ' + $project.Version + ': source, documents, runtime and source render evidence. Packaged verification follows separately.')
New-Item -ItemType Directory -Force -Path $outputsRoot, $qaRoot | Out-Null
New-Item -ItemType Directory -Path $stageRoot | Out-Null
$sourceDestination = Join-Path $stageRoot 'source'
New-Item -ItemType Directory -Path $sourceDestination | Out-Null
Get-ChildItem -LiteralPath $sourceRoot -Force | Copy-Item -Destination $sourceDestination -Recurse -Force
Write-BuildFingerprint $sourceDestination $sourceFingerprint
foreach ($name in $documents) { Copy-Item -LiteralPath (Join-Path $sourceDestination $name) -Destination $stageRoot }

$lovePath = Join-Path $stageRoot 'SIGIL-BREACH.love'
Write-Archive $sourceDestination $lovePath
$exePath = Join-Path $stageRoot 'SIGIL-BREACH.exe'
Write-FusedGame (Join-Path $RuntimeRoot 'love.exe') $lovePath $exePath
foreach ($dll in $dlls) { Copy-Item -LiteralPath $dll.FullName -Destination $stageRoot }
Copy-Item -LiteralPath (Join-Path $RuntimeRoot 'license.txt') -Destination (Join-Path $stageRoot 'LOVE-LICENSE.txt')
Copy-Item -LiteralPath (Join-Path $qaRoot 'architecture.txt') -Destination (Join-Path $stageRoot 'KONTROLA-KODU.txt')
Copy-Item -LiteralPath (Join-Path $qaRoot 'render-results.txt') -Destination (Join-Path $stageRoot 'RENDER.txt')
Copy-Item -LiteralPath (Join-Path $qaRoot 'ui-layout-audit.txt') -Destination (Join-Path $stageRoot 'GUI-UKLAD.txt')
Copy-Item -LiteralPath (Join-Path $qaRoot 'attack-timelines.txt') -Destination (Join-Path $stageRoot 'ANIMACJE-ATAKOW.txt')
Copy-Item -LiteralPath (Join-Path $qaRoot 'weapon-timeline.txt') -Destination (Join-Path $stageRoot 'ANIMACJE-BRONI.txt')
Copy-Item -LiteralPath (Join-Path $qaRoot 'fresco-motion-clocks.txt') -Destination (Join-Path $stageRoot 'ANIMACJE-BRONI-FRESK.txt')
foreach ($artifactName in $project.RenderEvidence + @('DURABILITY-REVIEW.txt','art-checks.txt','type-tests.txt','ability-registration-v23.csv','golden-current.lua')) {
    Copy-Item -LiteralPath (Join-Path $qaRoot $artifactName) -Destination $stageRoot
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
    'SIGIL-BREACH.love is a ZIP of the exact included source snapshot plus build-fingerprint.txt.',
    ('Game tree SHA256: ' + $sourceFingerprint),
    'development/ is a self-contained source workspace with pinned tools; use its RUN.ps1, TEST.ps1 and BUILD.ps1.',
    'The separate Player package contains the game, runtime and legal/provenance without QA/tests/developer documents; its game archive exists only inside its EXE.',
    'SIGIL-BREACH.exe consists of love.exe followed by that .love archive.',
    'Next: run tools/verify.ps1 from the development workspace.',
    'Verification runs the packaged EXE tests, verifies SHA-256, and creates the final Windows ZIP.',
    'The build step does not claim packaged test success or publish a new Windows ZIP.',
    'Balance and complete-run evidence are added only after a fresh packaged selftest.',
    'Native UI evidence is included only with a matching source fingerprint and report-hash receipt.'
)
$buildInfo | Set-Content -LiteralPath (Join-Path $stageRoot 'BUDOWA-PACZKI.txt') -Encoding utf8
Export-DeveloperWorkspace $taskRoot (Join-Path $stageRoot 'development') $RuntimeRoot
Export-PlayerPackage $sourceRoot $playerStage $RuntimeRoot $sourceFingerprint
Write-PackageManifest $stageRoot 'developer' $project.Version $sourceFingerprint $sourceFiles $evidence
Write-PackageManifest $playerStage 'player' $project.Version $sourceFingerprint $sourceFiles $evidence
Check-Hash $sourceFingerprint (Get-SourceFingerprint $taskRoot) 'game tree remained stable during packaging'
foreach ($candidate in @($releaseRoot, $playerRoot)) {
    if (Test-Path -LiteralPath $candidate) {
        if (-not (Test-Path -LiteralPath $candidate -PathType Container)) { throw "The target release path is not a directory: $candidate" }
        $runningPath = Join-Path $candidate 'SIGIL-BREACH.exe'
        if (@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $runningPath }).Count -gt 0) { throw 'Close the currently running packaged game before rebuilding it.' }
    }
}

# A rebuild preserves the previous current-release directory; earlier releases are untouched.
if (Test-Path -LiteralPath $releaseRoot) {
    $backup = Join-Path $qaRoot ('release-before-build-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    $checkedRelease = Assert-ChildPath $releaseRoot $outputsRoot
    $checkedBackup = Assert-ChildPath $backup $qaRoot
    Move-Item -LiteralPath $checkedRelease -Destination $checkedBackup
    Write-Output ('Preserved previous current-release build: ' + $checkedBackup)
}
$checkedStage = Assert-ChildPath $stageRoot $outputsRoot
$checkedTarget = Assert-ChildPath $releaseRoot $outputsRoot
Move-Item -LiteralPath $checkedStage -Destination $checkedTarget
if (Test-Path -LiteralPath $playerRoot) {
    $backup = Assert-ChildPath (Join-Path $qaRoot ('player-before-build-' + [Guid]::NewGuid().ToString('N'))) $qaRoot
    Move-Item -LiteralPath $playerRoot -Destination $backup
}
Move-Item -LiteralPath $playerStage -Destination $playerRoot

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
Write-Output ('Player candidate: ' + $playerRoot)
Write-Output 'Run tools/verify.ps1 to execute packaged tests and create the verified Windows ZIP.'
Get-Item -LiteralPath (Join-Path $releaseRoot 'SIGIL-BREACH.exe'), (Join-Path $releaseRoot 'SIGIL-BREACH.love') | Select-Object FullName, Length

