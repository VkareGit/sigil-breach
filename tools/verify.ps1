param(
    [string]$RuntimeRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) 'toolchain\love-11.5-win64'),
    [ValidateRange(10, 1800)][int]$TestTimeoutSeconds = 300
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'project.ps1')
$project = Get-Project
$taskRoot = $project.Root
$sourceRoot = Join-Path $taskRoot 'game'
$releaseRoot = $project.Release
$qaRoot = $project.Qa
$exePath = Join-Path $releaseRoot 'SIGIL-BREACH.exe'
$lovePath = Join-Path $releaseRoot 'SIGIL-BREACH.love'
$runtimePath = Join-Path $RuntimeRoot 'love.exe'
$zipPath = $project.Zip
$documents = $project.Documents
& (Join-Path $PSScriptRoot 'check.ps1')
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Run-PackagedTest([string]$Argument, [string]$LogName) {
    Write-Host ('Running packaged EXE ' + $Argument)
    return Invoke-IsolatedGame $exePath @($Argument) $taskRoot $qaRoot $LogName $TestTimeoutSeconds
}

foreach ($path in @($exePath, $lovePath, $runtimePath)) { if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing package/runtime file: $path" } }
New-Item -ItemType Directory -Force -Path $qaRoot | Out-Null


# Every archived source file must match both the development source and release/source.
$archive = [IO.Compression.ZipFile]::OpenRead($lovePath)
$count = 0
$seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
try {
    foreach ($entry in $archive.Entries) {
        if ($entry.FullName.EndsWith('/')) { continue }
        if (-not $seen.Add($entry.FullName)) { throw "Duplicate .love archive entry: $($entry.FullName)" }
        $localPath = Assert-ChildPath (Join-Path $sourceRoot $entry.FullName) $sourceRoot
        $releaseSourceRoot = Join-Path $releaseRoot 'source'
        $releaseSource = Assert-ChildPath (Join-Path $releaseSourceRoot $entry.FullName) $releaseSourceRoot
        $inputStream = $entry.Open()
        try { $packedHash = Hash-Stream $inputStream } finally { $inputStream.Dispose() }
        Check-Hash $packedHash (Get-FileHash -LiteralPath $localPath -Algorithm SHA256).Hash ('archive/source ' + $entry.FullName)
        Check-Hash $packedHash (Get-FileHash -LiteralPath $releaseSource -Algorithm SHA256).Hash ('archive/release source ' + $entry.FullName)
        $count++
    }
}
finally { $archive.Dispose() }
if ($count -ne @(Get-ChildItem -LiteralPath $sourceRoot -File -Recurse -Force).Count) { throw 'Missing development source files in .love archive.' }
if ($count -ne @(Get-ChildItem -LiteralPath (Join-Path $releaseRoot 'source') -File -Recurse -Force).Count) { throw 'Unexpected or missing files in release/source.' }

$exe = [IO.File]::ReadAllBytes($exePath)
$runtimeLength = [int](Get-Item -LiteralPath $runtimePath).Length
$loveLength = (Get-Item -LiteralPath $lovePath).Length
if ($exe.LongLength -ne $runtimeLength + $loveLength) { throw 'Fused EXE length differs from runtime plus game archive.' }
$prefix = [IO.MemoryStream]::new($exe, 0, $runtimeLength)
$suffix = [IO.MemoryStream]::new($exe, $runtimeLength, $exe.Length - $runtimeLength)
try {
    Check-Hash (Get-FileHash -LiteralPath $runtimePath -Algorithm SHA256).Hash (Hash-Stream $prefix) 'fused runtime prefix'
    Check-Hash (Get-FileHash -LiteralPath $lovePath -Algorithm SHA256).Hash (Hash-Stream $suffix) 'embedded .love suffix'
}
finally { $prefix.Dispose(); $suffix.Dispose(); $exe = $null }
$dlls = @(Get-ChildItem -LiteralPath $RuntimeRoot -Filter '*.dll' -File)
if ($dlls.Count -eq 0 -or $dlls.Count -ne @(Get-ChildItem -LiteralPath $releaseRoot -Filter '*.dll' -File).Count) { throw 'Runtime DLL set differs from the package.' }
foreach ($dll in $dlls) { Check-Hash (Get-FileHash -LiteralPath $dll.FullName -Algorithm SHA256).Hash (Get-FileHash -LiteralPath (Join-Path $releaseRoot $dll.Name) -Algorithm SHA256).Hash ('runtime DLL ' + $dll.Name) }
Check-Hash (Get-FileHash -LiteralPath (Join-Path $RuntimeRoot 'license.txt') -Algorithm SHA256).Hash (Get-FileHash -LiteralPath (Join-Path $releaseRoot 'LOVE-LICENSE.txt') -Algorithm SHA256).Hash 'runtime license'
foreach ($name in $documents) { Check-Hash (Get-FileHash -LiteralPath (Join-Path $sourceRoot $name) -Algorithm SHA256).Hash (Get-FileHash -LiteralPath (Join-Path $releaseRoot (Split-Path -Leaf $name)) -Algorithm SHA256).Hash ('release document ' + $name) }
Write-Output "SHA-256 source/archive/runtime/DLL checks passed for $count source files and $($dlls.Count) DLLs."
Copy-Item -LiteralPath (Join-Path $qaRoot 'architecture.txt') -Destination (Join-Path $releaseRoot 'KONTROLA-KODU.txt') -Force

$testReport = Join-Path $qaRoot 'test-results.txt'
$inputReport = Join-Path $qaRoot 'input-results.txt'
$bitmapReport = Join-Path $qaRoot 'bitmap-ui-audit.txt'
$balanceReport = Join-Path $qaRoot 'balance-results.txt'
$playtestReport = Join-Path $qaRoot 'playtest-results.txt'
$oldTestTime = Last-Write $testReport
$oldBitmapTime = Last-Write $bitmapReport
$oldBalanceTime = Last-Write $balanceReport
$oldPlaytestTime = Last-Write $playtestReport
$durabilityReport = Join-Path $qaRoot 'DURABILITY-REVIEW.txt'
$oldDurabilityTime = Last-Write $durabilityReport
$abilityReport = Join-Path $qaRoot 'ability-registration-v23.csv'
$oldAbilityTime = Last-Write $abilityReport
# The helper logs progress on the host stream, leaving one structured result here.
$selftest = Run-PackagedTest '--selftest' 'packaged-selftest'
Require-Fresh $testReport $selftest.Started $oldTestTime
Require-Fresh $bitmapReport $selftest.Started $oldBitmapTime
$bitmapText = Get-Content -LiteralPath $bitmapReport -Raw
if ($bitmapText -notmatch '; 0 issues\.' -or $bitmapText -match '(?m)^FAIL\b') { throw 'Packaged bitmap GUI audit did not report zero issues.' }
Require-Fresh $balanceReport $selftest.Started $oldBalanceTime
Require-Fresh $playtestReport $selftest.Started $oldPlaytestTime
Require-Fresh $durabilityReport $selftest.Started $oldDurabilityTime
Copy-Item -LiteralPath $durabilityReport -Destination $releaseRoot -Force
Require-Fresh $abilityReport $selftest.Started $oldAbilityTime
Copy-Item -LiteralPath $abilityReport -Destination $releaseRoot -Force
$testText = Get-Content -LiteralPath $testReport -Raw
$totals = [regex]::Matches($testText, '(?m)^MECHANICS / ASSETS TOTAL: (\d+) passing checks\.\s*$')
if ($totals.Count -ne 1 -or $testText -notmatch '(?m)^STATUS: PASSED\s*$' -or $testText -match '(?m)^FAIL\b') { throw 'Selftest did not finish with one valid passing summary.' }
$mechanicsCount = [int]$totals[0].Groups[1].Value
$executedCount = [regex]::Matches($testText, '(?m)^PASS ').Count
$suiteCount = 0
foreach ($match in [regex]::Matches($testText, '(?m)^SUITE [\w-]+: (\d+) passing checks\.')) { $suiteCount += [int]$match.Groups[1].Value }
if ($mechanicsCount -le 0 -or $mechanicsCount -ne $executedCount -or $mechanicsCount -ne $suiteCount) { throw 'Selftest summary differs from executed assertions or suite totals.' }

$oldInputTime = Last-Write $inputReport
$inputTest = Run-PackagedTest '--input-test' 'packaged-input'
Require-Fresh $inputReport $inputTest.Started $oldInputTime
$inputText = Get-Content -LiteralPath $inputReport -Raw
$inputSummary = [regex]::Match($inputText, '(?m)^(\d+) controller checks\.')
if (-not $inputSummary.Success -or $inputText -match '(?m)^FAIL\b') { throw 'Packaged input test did not produce a valid passing summary.' }
$inputCount = [int]$inputSummary.Groups[1].Value
if ($inputCount -le 0 -or $inputCount -ne [regex]::Matches($inputText, '(?m)^PASS ').Count) { throw 'Input summary count differs from executed PASS lines.' }

$renderReport = Join-Path $qaRoot 'render-results.txt'
$layoutReport = Join-Path $qaRoot 'ui-layout-audit.txt'
$oldRenderTime = Last-Write $renderReport
$oldLayoutTime = Last-Write $layoutReport
$renderTest = Run-PackagedTest '--showcase' 'packaged-render'
Require-Fresh $renderReport $renderTest.Started $oldRenderTime
Require-Fresh $layoutReport $renderTest.Started $oldLayoutTime
$layoutText = Get-Content -LiteralPath $layoutReport -Raw
if ($layoutText -notmatch '\d+ interior checks, 0 issues' -or $layoutText -match '\b[1-9]\d* issues\b') { throw 'Packaged render has frame-interior or collision failures.' }
Copy-Item -LiteralPath $layoutReport -Destination (Join-Path $releaseRoot 'GUI-UKLAD.txt') -Force
Copy-Item -LiteralPath (Join-Path $qaRoot 'attack-timelines.txt') -Destination (Join-Path $releaseRoot 'ANIMACJE-ATAKOW.txt') -Force
Copy-Item -LiteralPath (Join-Path $qaRoot 'weapon-timeline.txt') -Destination (Join-Path $releaseRoot 'ANIMACJE-BRONI.txt') -Force
Copy-Item -LiteralPath (Join-Path $qaRoot 'fresco-motion-clocks.txt') -Destination (Join-Path $releaseRoot 'ANIMACJE-BRONI-FRESK.txt') -Force
foreach ($evidence in $project.RenderEvidence) {
    $evidencePath = Join-Path $qaRoot $evidence
    if ((Get-Item -LiteralPath $evidencePath).LastWriteTimeUtc -lt $renderTest.Started) { throw "Stale render evidence: $evidence" }
    Copy-Item -LiteralPath (Join-Path $qaRoot $evidence) -Destination $releaseRoot -Force
}

# These reports are regenerated by this invocation, in the current QA directory.
Copy-Item -LiteralPath $balanceReport -Destination (Join-Path $releaseRoot 'BALANS.txt') -Force
Copy-Item -LiteralPath $playtestReport -Destination (Join-Path $releaseRoot 'PRZEJSCIE-TESTOWE.txt') -Force
Copy-Item -LiteralPath $testReport -Destination (Join-Path $releaseRoot 'TESTY.txt') -Force
Copy-Item -LiteralPath $inputReport -Destination (Join-Path $releaseRoot 'STEROWANIE-TESTY.txt') -Force
Copy-Item -LiteralPath $bitmapReport -Destination (Join-Path $releaseRoot 'GUI-BITMAPY-AUDYT.txt') -Force
Copy-Item -LiteralPath (Join-Path $qaRoot 'render-results.txt') -Destination (Join-Path $releaseRoot 'RENDER.txt') -Force
$nativePath = Join-Path $qaRoot 'native-ui-results.txt'
$nativeIncluded = Test-Path -LiteralPath $nativePath -PathType Leaf
if ($nativeIncluded) { Copy-Item -LiteralPath $nativePath -Destination (Join-Path $releaseRoot 'GUI-TESTY.txt') -Force }
else {
    $staleNative = Assert-ChildPath (Join-Path $releaseRoot 'GUI-TESTY.txt') $releaseRoot
    if (Test-Path -LiteralPath $staleNative -PathType Leaf) { Remove-Item -LiteralPath $staleNative }
}

# Tests take time. Refuse to certify a snapshot if development files changed
# while the packaged process was running.
$stableArchive = [IO.Compression.ZipFile]::OpenRead($lovePath)
try {
    foreach ($entry in $stableArchive.Entries) {
        if ($entry.FullName.EndsWith('/')) { continue }
        $currentSource = Assert-ChildPath (Join-Path $sourceRoot $entry.FullName) $sourceRoot
        $stream = $entry.Open()
        try { $expected = Hash-Stream $stream } finally { $stream.Dispose() }
        Check-Hash $expected (Get-FileHash -LiteralPath $currentSource -Algorithm SHA256).Hash ('source remained stable during tests: ' + $entry.FullName)
    }
    if ($count -ne @(Get-ChildItem -LiteralPath $sourceRoot -File -Recurse -Force).Count) { throw 'Development source file set changed during tests.' }
}
finally { $stableArchive.Dispose() }
$exeHash = (Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash
$lines = @(
    ($project.Title + ' - executed package verification.'),
    ('Verified UTC: ' + [DateTime]::UtcNow.ToString('o')),
    ('Verifier: ' + $PSCommandPath),
    "Verified $count files against development source, included source and .love using SHA-256.",
    'Verified fused EXE contains the expected LOVE runtime followed by the exact .love archive.',
    "Verified all $($dlls.Count) runtime DLLs, the runtime license and $($documents.Count) release documents using SHA-256.",
    "Packaged EXE --selftest: exit 0; $mechanicsCount mechanics/asset checks reported by this execution.",
    ('Selftest UTC: ' + $selftest.Started.ToString('o') + ' to ' + $selftest.Finished.ToString('o')),
    "Packaged EXE --input-test: exit 0; $inputCount executed controller/save checks in isolated QA identity.",
    ('Input test UTC: ' + $inputTest.Started.ToString('o') + ' to ' + $inputTest.Finished.ToString('o')),
    'Both reports were freshly rewritten by these specific packaged EXE invocations.',
    'The independent bitmap GUI audit was also freshly regenerated by the packaged EXE: zero detected layout issues in its tested states.',
    'Balance and full-run reports were regenerated by that selftest; their freshness is checked.',
    ('Native UI report included: ' + $nativeIncluded + '. Its observations are separate from automated verification.'),
    'Packaged EXE --showcase regenerated render evidence and layout reports; exit0 and zero measured layout issues.',
    'Automated tests invoke real game callbacks and rendering, with desktop mouse capture disabled; this is not a native mouse playtest.',
    'Only Limbo is playable. Test completion does not establish human difficulty or subjective weapon feel.',
    'Hit outcome timing reports measure remaining presented-pose/resolved-pose differences; passing mechanics tests do not mean these differences are zero. See the acceptance document.',
    ('EXE SHA256: ' + $exeHash),
    ('LOVE SHA256: ' + (Get-FileHash -LiteralPath $lovePath -Algorithm SHA256).Hash),
    'The final Windows ZIP is created after these checks and rehashed entry-by-entry against this release folder.'
)
$lines | Set-Content -LiteralPath (Join-Path $releaseRoot 'WERYFIKACJA-PACZKI.txt') -Encoding utf8

# Create a fresh archive only after actual packaged test success. Preserve any
# previous verified ZIP until the new archive has passed its own content check.
$temporaryZip = $zipPath + '.verified-' + [Guid]::NewGuid().ToString('N') + '.tmp'
$temporaryZip = Assert-ChildPath $temporaryZip (Join-Path $taskRoot 'outputs')
# A failed check removes the unverified archive; the previous verified ZIP stays.
trap {
    if ($temporaryZip -and (Test-Path -LiteralPath $temporaryZip)) { Remove-Item -LiteralPath $temporaryZip -Force }
    break
}
Write-Archive $releaseRoot $temporaryZip
$finalArchive = [IO.Compression.ZipFile]::OpenRead($temporaryZip)
$zipEntries = 0
try {
    foreach ($entry in $finalArchive.Entries) {
        if ($entry.FullName.EndsWith('/')) { continue }
        $local = Assert-ChildPath (Join-Path $releaseRoot $entry.FullName) $releaseRoot
        $stream = $entry.Open()
        try { $zipHash = Hash-Stream $stream } finally { $stream.Dispose() }
        Check-Hash $zipHash (Get-FileHash -LiteralPath $local -Algorithm SHA256).Hash ('Windows ZIP entry ' + $entry.FullName)
        $zipEntries++
    }
}
finally { $finalArchive.Dispose() }
if ($zipEntries -ne @(Get-ChildItem -LiteralPath $releaseRoot -File -Recurse -Force).Count) { throw 'Windows ZIP file count mismatch.' }
$checkedZip = Assert-ChildPath $zipPath (Join-Path $taskRoot 'outputs')
if (Test-Path -LiteralPath $checkedZip) {
    $zipBackup = Assert-ChildPath (Join-Path $qaRoot ('verified-zip-before-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '.zip')) $qaRoot
    Move-Item -LiteralPath $checkedZip -Destination $zipBackup
}
Move-Item -LiteralPath $temporaryZip -Destination $checkedZip
$zipResult = @(
    ('Verified final ZIP entries: ' + $zipEntries),
    ('ZIP SHA256: ' + (Get-FileHash -LiteralPath $checkedZip -Algorithm SHA256).Hash),
    ('ZIP: ' + $checkedZip)
)
($lines + '' + $zipResult) | Set-Content -LiteralPath (Join-Path $qaRoot 'package-verification.txt') -Encoding utf8
$lines
$zipResult
Get-Item -LiteralPath $exePath, $checkedZip | Select-Object FullName, Length

