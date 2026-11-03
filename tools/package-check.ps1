param([switch]$Installed, [ValidateRange(10, 1800)][int]$TestTimeoutSeconds = 180)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'project.ps1')
if ($Installed) { Assert-WindowsPackaging }
. (Join-Path $PSScriptRoot 'package.ps1')
. (Join-Path $PSScriptRoot 'package-verification.ps1')
$project = Get-Project
$work = Join-Path $project.Root 'work'
$fixture = Assert-ChildPath (Join-Path $work ('package-check-' + [Guid]::NewGuid().ToString('N'))) $work
New-Item -ItemType Directory -Path $fixture | Out-Null
$checks = 0
function Check-Package([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $script:checks++
}
function Reject-Package([scriptblock]$Action, [string]$Message) {
    $rejected = $false
    try { & $Action | Out-Null } catch { $rejected = $true }
    Check-Package $rejected $Message
}
$success = $false
try {
    $source = Join-Path $fixture 'game'
    $runtime = Join-Path $fixture 'runtime'
    foreach ($pair in @{
        'game/main.lua'='return true'; 'game/conf.lua'='return true'; 'game/src/example.lua'='return {}'
        'game/assets/art/example.png'='fixture image'; 'game/assets/art/masks.lua'='return {}'
        'game/assets/art/photo.jpg'='fixture image'
        'game/assets/art/provenance.json'='{}'; 'game/qa/private.lua'='excluded'
        'game/tests/private.lua'='excluded'; 'game/qa/notes.txt'='excluded'
        'game/INSTRUKCJA.txt'='instructions'; 'runtime/love.exe'='fixture runtime'
        'runtime/love.dll'='fixture dll'; 'runtime/license.txt'='fixture license'
    }.GetEnumerator()) {
        $path = Join-Path $fixture $pair.Key
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
        [IO.File]::WriteAllText($path, $pair.Value)
    }
    $fingerprint = Get-SourceFingerprint $fixture
    $player = Join-Path $fixture 'player'
    Export-PlayerPackage $source $player $runtime $fingerprint
    Assert-FusedGame $player $runtime
    Check-Package ((Assert-PlayerPayload $player $source $fingerprint $runtime) -eq 7) 'Player payload missing runtime files or includes development data.'
    Check-Package (-not (Test-Path -LiteralPath (Join-Path $player 'SIGIL-BREACH.love'))) 'Player ships a second copy of its game archive.'
    Check-Package (-not (Test-Path -LiteralPath (Join-Path $player '.game.love'))) 'Player keeps its packaging intermediate.'
    Check-Package (Test-Path -LiteralPath (Join-Path $player 'legal/assets/art/provenance.json')) 'Art provenance missing.'
    Write-PackageManifest $player 'player' 'fixture' $fingerprint @(Get-PackageTree $source)
    $manifest = Assert-PackageManifest $player $fingerprint
    Check-Package ($manifest.files.Count -gt 0 -and $manifest.sourceFiles.Count -eq 11) 'Manifest must describe complete game tree and installed files.'
    Reject-Package { Assert-PackageManifest $player ('0' * 64) } 'Different source fingerprint accepted.'
    [IO.File]::AppendAllText((Join-Path $player 'SIGIL-BREACH.exe'), 'tamper')
    Reject-Package { Assert-PackageManifest $player $fingerprint } 'Modified EXE accepted by manifest.'
    Reject-Package { Assert-FusedGame $player $runtime } 'Modified fused EXE accepted.'
    $qa = Join-Path $fixture 'qa'
    New-Item -ItemType Directory -Path $qa | Out-Null
    $started = [DateTime]::UtcNow.AddSeconds(-1)
    'PASS' | Set-Content -LiteralPath (Join-Path $qa 'result.txt')
    $runtimeHash = (Get-FileHash -LiteralPath (Join-Path $runtime 'love.exe')).Hash
    $proof = @{ sourceFingerprint=$fingerprint; sourceAfter=$fingerprint; sourceStable=$true; exitCode=0; started=$started.ToString('o'); finished=[DateTime]::UtcNow.AddSeconds(1).ToString('o'); executableFingerprint=$runtimeHash; buildFingerprint=($fingerprint + ':' + $runtimeHash) }
    $proof | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $qa 'fixture.evidence.json')
    $binding = Assert-PackageEvidence $qa 'fixture' $fingerprint @('result.txt')
    Check-Package ($binding.reports[0].sha256 -eq (Get-FileHash -LiteralPath (Join-Path $qa 'result.txt')).Hash) 'Report hash was not bound to invocation.'
    $boundRuntime = Assert-PackageEvidence $qa 'fixture' $fingerprint @('result.txt') (Join-Path $runtime 'love.exe')
    Check-Package ($boundRuntime.buildFingerprint -eq $proof.buildFingerprint) 'Runtime fingerprint was not preserved.'
    Write-PackageManifest $player 'player' 'fixture' $fingerprint @(Get-PackageTree $source) @($binding, $boundRuntime)
    $manifest = Assert-PackageManifest $player $fingerprint
    Check-Package ($manifest.evidence.Count -eq 2 -and $manifest.evidence[0].invocation -eq 'fixture' -and $manifest.evidence[1].reports.Count -eq 1) 'Receipt array lost its invocation/report structure.'
    Reject-Package { Write-PackageManifest $player 'player' 'fixture' $fingerprint @() 'golden-current.lua' } 'A loop iterator string replaced the evidence array.'
    $films = @('weapon-shotgun-16-poses.png','weapon-revolver-16-poses.png','weapon-shotgun-partial-one.png','weapon-revolver-partial-one.png','weapon-shotgun-cancel-resume.png','weapon-revolver-cancel-resume.png','weapon-revolver-trigger-interrupt.png')
    Check-Package (@($films | Where-Object { $_ -notin $project.RenderEvidence }).Count -eq 0) 'Required full/partial/interrupt filmstrips missing from build and verifier evidence.'
    Reject-Package { Assert-PackageEvidence $qa 'fixture' $fingerprint @('missing-filmstrip.png') } 'An invocation certified a missing required filmstrip.'
    Reject-Package { Assert-PackageEvidence $qa 'fixture' $fingerprint @('result.txt') (Join-Path $runtime 'love.dll') } 'Different runtime binary accepted.'
    Reject-Package { Assert-PackageEvidence $qa 'fixture' ('0' * 64) @('result.txt') } 'Fresh timestamp bypassed wrong source hash.'
    $proof.sourceStable=$false
    $proof | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $qa 'fixture.evidence.json')
    Reject-Package { Assert-PackageEvidence $qa 'fixture' $fingerprint @('result.txt') } 'Unstable source certified.'
    Reject-Package { Assert-ChildPath (Join-Path $fixture '../outside') $fixture } 'Traversal accepted.'
    if ($Installed) {
        $runtime = Join-Path $project.Root 'toolchain/love-11.5-win64'
        $current = Get-SourceFingerprint $project.Root
        $livePlayer = Join-Path $fixture 'current-player'
        $liveDev = Join-Path $fixture 'current-developer'
        New-Item -ItemType Directory -Path $liveDev | Out-Null
        Export-PlayerPackage $project.Source $livePlayer $runtime $current
        Write-PackageManifest $livePlayer 'player' $project.Version $current @(Get-PackageTree $project.Source)
        Export-DeveloperWorkspace $project.Root (Join-Path $liveDev 'development') $runtime
        # Relocation evidence records the tested developer runtime too; this
        # candidate is not a production archive and is never published.
        Copy-PackageFile (Join-Path $runtime 'love.exe') $liveDev 'SIGIL-BREACH.exe'
        $evidence = Join-Path $work 'qa-foundation-v9-packaging'
        New-Item -ItemType Directory -Force -Path $evidence | Out-Null
        $null = Test-InstalledPackages $livePlayer $liveDev $evidence $current $TestTimeoutSeconds
        Check-Package $true 'Installed smoke did not finish.'
    }
    $success = $true
    Write-Output "PACKAGE CHECK: $checks passing checks. Installed=$Installed."
}
finally {
    if ($success) { Remove-Item -LiteralPath (Assert-ChildPath $fixture $work) -Recurse -Force }
    else { Write-Warning "Package fixture preserved: $fixture" }
}
