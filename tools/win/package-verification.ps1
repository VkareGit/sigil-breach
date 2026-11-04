# Installed-package checks, kept separate from the complete developer test run.
# The game archive fused after the runtime in a package's EXE: the runtime
# prefix must be the exact love.exe and the archive must end the file (its
# end-of-central-directory record, no comment), so appended bytes are refused.
function Get-FusedArchive([string]$Root, [string]$RuntimeRoot) {
    $exe = [IO.File]::ReadAllBytes((Join-Path $Root 'SIGIL-BREACH.exe'))
    $runtimePath = Join-Path $RuntimeRoot 'love.exe'
    $runtimeLength = [int](Get-Item -LiteralPath $runtimePath).Length
    $end = $exe.Length - 22
    if ($end -lt $runtimeLength -or [BitConverter]::ToUInt32($exe, $end) -ne 0x06054b50 -or [BitConverter]::ToUInt16($exe, $end + 20) -ne 0) {
        throw 'Fused EXE does not end with its game archive.'
    }
    $prefix = [IO.MemoryStream]::new($exe, 0, $runtimeLength)
    try { Check-Hash (Get-FileHash -LiteralPath $runtimePath -Algorithm SHA256).Hash (Hash-Stream $prefix) 'installed runtime prefix' }
    finally { $prefix.Dispose() }
    return [IO.MemoryStream]::new($exe, $runtimeLength, $exe.Length - $runtimeLength, $false)
}

# A developer package also ships its .love beside the EXE: the same bytes. A
# player package ships none (the EXE is its only copy).
function Assert-FusedGame([string]$Root, [string]$RuntimeRoot) {
    $suffix = Get-FusedArchive $Root $RuntimeRoot
    try {
        $lovePath = Join-Path $Root 'SIGIL-BREACH.love'
        if (Test-Path -LiteralPath $lovePath -PathType Leaf) {
            Check-Hash (Get-FileHash -LiteralPath $lovePath -Algorithm SHA256).Hash (Hash-Stream $suffix) 'installed game suffix'
        }
        else {
            $archive = [IO.Compression.ZipArchive]::new($suffix, [IO.Compression.ZipArchiveMode]::Read, $true)
            try { if ($archive.Entries.Count -eq 0) { throw 'Fused EXE carries an empty game archive.' } }
            finally { $archive.Dispose() }
        }
    }
    finally { $suffix.Dispose() }
}

function Assert-PlayerPayload([string]$Root, [string]$Source, [string]$Fingerprint, [string]$RuntimeRoot) {
    if (Test-Path -LiteralPath (Join-Path $Root 'SIGIL-BREACH.love')) { throw 'Player delivery carries a second copy of its game archive.' }
    $archive = [IO.Compression.ZipArchive]::new((Get-FusedArchive $Root $RuntimeRoot), [IO.Compression.ZipArchiveMode]::Read)
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $expected = @{}
    foreach ($file in Get-ChildItem -LiteralPath $Source -File -Recurse -Force) {
        $name = $file.FullName.Substring($Source.Length + 1).Replace('\', '/')
        if (Test-PlayerRuntimeFile $name) { $expected[$name] = $file.FullName }
    }
    try {
        foreach ($entry in $archive.Entries) {
            if ($entry.FullName.EndsWith('/')) { continue }
            if (-not $seen.Add($entry.FullName)) { throw "Duplicate player payload: $($entry.FullName)" }
            $stream = $entry.Open()
            try {
                if ($entry.FullName -eq 'build-fingerprint.txt') {
                    $reader = [IO.StreamReader]::new($stream)
                    try { Check-Hash $Fingerprint $reader.ReadToEnd().Trim() 'player embedded identity' } finally { $reader.Dispose() }
                }
                else {
                    if (-not $expected.ContainsKey($entry.FullName)) { throw "Disallowed player payload: $($entry.FullName)" }
                    Check-Hash (Get-FileHash -LiteralPath $expected[$entry.FullName] -Algorithm SHA256).Hash (Hash-Stream $stream) ('player payload ' + $entry.FullName)
                }
            }
            finally { $stream.Dispose() }
        }
    }
    finally { $archive.Dispose() }
    if ($seen.Count -ne $expected.Count + 1 -or -not $seen.Contains('build-fingerprint.txt')) { throw 'Player runtime payload is incomplete.' }
    foreach ($name in @('source', 'development', 'qa', 'tests', 'docs')) {
        if (Test-Path -LiteralPath (Join-Path $Root $name)) { throw "Developer directory in player delivery: $name" }
    }
    return $seen.Count
}

function Invoke-PackageProcess([string]$Executable, [string[]]$Arguments, [string]$WorkingDirectory, [string]$Evidence, [string]$Name, [int]$TimeoutSeconds) {
    New-Item -ItemType Directory -Force -Path $Evidence | Out-Null
    $oldQa, $oldSource, $oldBuild = $env:SIGIL_UI_QA_DIR, $env:SIGIL_QA_SOURCE_FINGERPRINT, $env:SIGIL_QA_BUILD_FINGERPRINT
    try {
        $env:SIGIL_UI_QA_DIR = $Evidence
        # Read the embedded fingerprint, not the caller's environment override.
        $env:SIGIL_QA_SOURCE_FINGERPRINT = $null
        $env:SIGIL_QA_BUILD_FINGERPRINT = $null
        $process = Start-Process -FilePath $Executable -ArgumentList $Arguments -WorkingDirectory $WorkingDirectory -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $Evidence ($Name + '.stdout.txt')) -RedirectStandardError (Join-Path $Evidence ($Name + '.stderr.txt'))
    }
    finally { $env:SIGIL_UI_QA_DIR, $env:SIGIL_QA_SOURCE_FINGERPRINT, $env:SIGIL_QA_BUILD_FINGERPRINT = $oldQa, $oldSource, $oldBuild }
    # Windows PowerShell reports no exit code unless the handle is held open.
    $null = $process.Handle
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        Stop-Process -Id $process.Id -Force
        throw "Installed package timed out: $Name. Evidence: $Evidence"
    }
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw "Installed package failed: $Name ($($process.ExitCode)). Evidence: $Evidence" }
}

function Test-InstalledPackages([string]$Player, [string]$Developer, [string]$Qa, [string]$Fingerprint, [int]$TimeoutSeconds) {
    $temporary = [IO.Path]::GetTempPath()
    # A path containing spaces and an unrelated current directory catch both
    # accidental repository imports and unquoted launch assumptions.
    $probe = Assert-ChildPath (Join-Path $temporary ('SIGIL package probe ' + [Guid]::NewGuid().ToString('N'))) $temporary
    New-Item -ItemType Directory -Path $probe | Out-Null
    $playerCopy = Join-Path $probe 'Player install'
    $devCopy = Join-Path $probe 'Developer install'
    $cwd = Join-Path $probe 'Unrelated working directory'
    $evidence = Join-Path $probe 'evidence'
    New-Item -ItemType Directory -Path $cwd, $evidence | Out-Null
    Copy-Item -LiteralPath $Player -Destination $playerCopy -Recurse
    Copy-Item -LiteralPath (Join-Path $Developer 'development') -Destination $devCopy -Recurse
    $null = Assert-PackageManifest $playerCopy $Fingerprint
    Check-Hash $Fingerprint (Get-SourceFingerprint $devCopy) 'relocated developer game tree'
    $success = $false
    try {
        Invoke-PackageProcess (Join-Path $playerCopy 'SIGIL-BREACH.exe') @('--package-smoke') $cwd $evidence 'installed-player' $TimeoutSeconds
        $report = Get-Content -LiteralPath (Join-Path $evidence 'package-smoke.txt') -Raw
        if (-not $report.Contains('PACKAGE SMOKE: PASSED') -or -not $report.Contains('Source fingerprint: ' + $Fingerprint)) { throw 'Installed player did not attest its embedded build.' }
        # The full EXE suite is handled by verify.ps1. Here check that a fresh
        # developer checkout can use its own pinned formatter, checker and Lua.
        $shell = (Get-Process -Id $PID).Path
        Invoke-PackageProcess $shell @('-NoProfile', '-File', ('"' + (Join-Path $devCopy 'scripts/win/TEST.ps1') + '"'), '-Suite', 'Architecture') $cwd $evidence 'installed-dev-architecture' $TimeoutSeconds
        Invoke-PackageProcess (Join-Path $devCopy 'toolchain/love-11.5-win64/lovec.exe') @(('"' + (Join-Path $devCopy 'game') + '"'), '--suite=foundation-contracts') $cwd $evidence 'installed-dev-contracts' $TimeoutSeconds
        $contracts = Get-Content -LiteralPath (Join-Path $evidence 'installed-dev-contracts.stdout.txt') -Raw
        if ($contracts -notmatch 'SUITE foundation-contracts: \d+ passing checks\.') { throw 'Relocated developer contract suite did not complete.' }
        $destination = Join-Path $Qa 'installed-packages'
        New-Item -ItemType Directory -Force -Path $destination | Out-Null
        Get-ChildItem -LiteralPath $evidence -File | Copy-Item -Destination $destination -Force
        $proof = [ordered]@{
            sourceFingerprint = $Fingerprint; playerExe = (Get-FileHash -LiteralPath (Join-Path $playerCopy 'SIGIL-BREACH.exe')).Hash
            developerExe = (Get-FileHash -LiteralPath (Join-Path $Developer 'SIGIL-BREACH.exe')).Hash
            relocated = $true; unrelatedWorkingDirectory = $true; player = 'PASS'; developerArchitecture = 'PASS'; developerContracts = 'PASS'
            verifiedUtc = [DateTime]::UtcNow.ToString('o')
        }
        $proof | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $destination 'installed-packages.json') -Encoding utf8
        $success = $true
        return $proof
    }
    finally {
        # Preserve failures for diagnosis. Every delete is checked against the
        # exact temporary parent and happens only after successful execution.
        if ($success) { Remove-Item -LiteralPath (Assert-ChildPath $probe $temporary) -Recurse -Force }
        else { Write-Warning "Installed-package probe preserved: $probe" }
    }
}

function Publish-PackageArchive([string]$Root, [string]$Destination, [string]$Outputs, [string]$Qa) {
    $target = Assert-ChildPath $Destination $Outputs
    $staging = Assert-ChildPath ($target + '.verified-' + [Guid]::NewGuid().ToString('N') + '.tmp') $Outputs
    try {
        Write-Archive $Root $staging
        $archive = [IO.Compression.ZipFile]::OpenRead($staging)
        $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        try {
            foreach ($entry in $archive.Entries) {
                if ($entry.FullName.EndsWith('/')) { continue }
                if (-not $seen.Add($entry.FullName)) { throw "Duplicate ZIP entry: $($entry.FullName)" }
                $file = Assert-ChildPath (Join-Path $Root $entry.FullName) $Root
                $stream = $entry.Open()
                try { Check-Hash (Get-FileHash -LiteralPath $file).Hash (Hash-Stream $stream) ('delivery ZIP ' + $entry.FullName) } finally { $stream.Dispose() }
            }
        }
        finally { $archive.Dispose() }
        if ($seen.Count -ne @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force).Count) { throw 'Delivery ZIP file count differs.' }
        if (Test-Path -LiteralPath $target) {
            Move-Item -LiteralPath $target -Destination (Reset-Rollback $Qa ([IO.Path]::GetFileName($target)))
        }
        Move-Item -LiteralPath $staging -Destination $target
        $hash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
        ($hash + '  ' + [IO.Path]::GetFileName($target)) | Set-Content -LiteralPath ($target + '.sha256') -Encoding ascii
        return $hash
    }
    finally { if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath (Assert-ChildPath $staging $Outputs) -Force } }
}
