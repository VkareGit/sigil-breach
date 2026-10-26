# Packaging primitives. No execution on dot-source. The game tree is the build
# identity; generated fingerprints/manifests are explicitly outside that tree.
function Get-PackageTree([string]$Root, [string[]]$Exclude = @()) {
    $base = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $files = @(Get-ChildItem -LiteralPath $base -File -Recurse -Force)
    $names = [string[]]@($files | ForEach-Object { $_.FullName.Substring($base.Length + 1).Replace('\', '/') })
    [Array]::Sort($names, [StringComparer]::Ordinal)
    foreach ($name in $names) {
        if ($name -in $Exclude) { continue }
        $path = Assert-ChildPath (Join-Path $base $name) $base
        $file = Get-Item -LiteralPath $path
        if ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Package cannot contain a link: $name" }
        [PSCustomObject]@{ path = $name; bytes = $file.Length; sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
    }
}

function Copy-PackageFile([string]$From, [string]$Root, [string]$Relative) {
    $destination = Assert-ChildPath (Join-Path $Root $Relative) $Root
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
    Copy-Item -LiteralPath $From -Destination $destination -Force
}

function Write-BuildFingerprint([string]$Root, [string]$Fingerprint) {
    if ($Fingerprint -notmatch '^[A-Fa-f0-9]{64}$') { throw 'Invalid game fingerprint.' }
    [IO.File]::WriteAllText((Join-Path $Root 'build-fingerprint.txt'), $Fingerprint + "`n", [Text.UTF8Encoding]::new($false))
}

function Assert-PackageEvidence([string]$Qa, [string]$Name, [string]$Fingerprint, [string[]]$Reports, [string]$Executable = '') {
    $path = Join-Path $Qa ($Name + '.evidence.json')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing fingerprint evidence: $path" }
    $proof = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ($proof.sourceFingerprint -ne $Fingerprint -or $proof.sourceAfter -ne $Fingerprint -or -not $proof.sourceStable -or $proof.exitCode -ne 0) {
        throw "Evidence does not certify this game tree: $Name"
    }
    if ($Executable) {
        $exeHash = (Get-FileHash -LiteralPath $Executable -Algorithm SHA256).Hash
        Check-Hash $exeHash $proof.executableFingerprint ('evidence executable ' + $Name)
        Check-Hash ($Fingerprint + ':' + $exeHash) $proof.buildFingerprint ('evidence build ' + $Name)
    }
    $started = ([DateTimeOffset]$proof.started).UtcDateTime
    $finished = ([DateTimeOffset]$proof.finished).UtcDateTime
    $hashes = @()
    foreach ($report in $Reports) {
        $file = Get-Item -LiteralPath (Join-Path $Qa $report) -ErrorAction Stop
        if ($file.LastWriteTimeUtc -lt $started -or $file.LastWriteTimeUtc -gt $finished) { throw "Report not produced by $Name`: $report" }
        $hashes += [ordered]@{ path = $report; sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash }
    }
    return [ordered]@{ invocation = $Name; sourceFingerprint = $Fingerprint; buildFingerprint = $proof.buildFingerprint; reports = $hashes }
}

function Write-FusedGame([string]$Runtime, [string]$Game, [string]$Destination) {
    $target = [IO.File]::Open($Destination, [IO.FileMode]::CreateNew)
    try {
        foreach ($part in @($Runtime, $Game)) {
            $source = [IO.File]::OpenRead($part)
            try { $source.CopyTo($target) } finally { $source.Dispose() }
        }
    }
    finally { $target.Dispose() }
}

function Export-PlayerPackage([string]$Source, [string]$Destination, [string]$RuntimeRoot, [string]$Fingerprint) {
    New-Item -ItemType Directory -Path $Destination | Out-Null
    $payload = Join-Path $Destination '.payload'
    New-Item -ItemType Directory -Path $payload | Out-Null
    foreach ($file in Get-ChildItem -LiteralPath $Source -File -Recurse -Force) {
        $name = $file.FullName.Substring($Source.Length + 1).Replace('\', '/')
        $runtime = $name -in @('main.lua', 'conf.lua') -or $name.StartsWith('src/') -or ($name.StartsWith('assets/') -and $file.Extension -in @('.png', '.lua'))
        if ($runtime) { Copy-PackageFile $file.FullName $payload $name }
        elseif ($name.StartsWith('assets/') -and $file.Extension -in @('.json', '.txt')) {
            Copy-PackageFile $file.FullName $Destination ('legal/' + $name)
        }
    }
    Write-BuildFingerprint $payload $Fingerprint
    # A player runs the EXE: the game archive lives only inside it, not as a
    # second copy beside it (verification reads it back out of the EXE).
    $archive = Join-Path $Destination '.game.love'
    Write-Archive $payload $archive
    Write-FusedGame (Join-Path $RuntimeRoot 'love.exe') $archive (Join-Path $Destination 'SIGIL-BREACH.exe')
    Remove-Item -LiteralPath (Assert-ChildPath $archive $Destination) -Force
    foreach ($dll in Get-ChildItem -LiteralPath $RuntimeRoot -File -Filter '*.dll') { Copy-Item -LiteralPath $dll.FullName -Destination $Destination }
    Copy-PackageFile (Join-Path $RuntimeRoot 'license.txt') $Destination 'LOVE-LICENSE.txt'
    Copy-PackageFile (Join-Path $Source 'docs/INSTRUKCJA.txt') $Destination 'INSTRUKCJA.txt'
    # Lua inside the executable's LÖVE payload is runtime code, not a loose
    # developer source checkout. No QA module is hidden in the player archive.
    $checked = Assert-ChildPath $payload $Destination
    Remove-Item -LiteralPath $checked -Recurse -Force
}

# Files git tracks under a folder (relative, '\' separators). A workspace
# without git (a relocated developer package) has only tracked files anyway.
function Get-TrackedFiles([string]$Root, [string]$Folder) {
    if (-not (Test-Path -LiteralPath (Join-Path $Root '.git'))) {
        return @(Get-ChildItem -LiteralPath (Join-Path $Root $Folder) -File -Recurse -Force |
            ForEach-Object { $_.FullName.Substring($Root.Length + 1) })
    }
    $listed = @(& git -C $Root ls-files -z -- $Folder)
    if ($LASTEXITCODE -ne 0) { throw "git ls-files failed for $Folder" }
    return @(($listed -join '').Split([char]0, [StringSplitOptions]::RemoveEmptyEntries) |
        Where-Object { Test-Path -LiteralPath (Join-Path $Root $_) -PathType Leaf } |
        ForEach-Object { $_.Replace('/', '\') })
}

function Export-DeveloperWorkspace([string]$Root, [string]$Destination, [string]$RuntimeRoot) {
    New-Item -ItemType Directory -Path $Destination | Out-Null
    # Explicit allowlist: generators may contain service settings; private
    # machine config, work, previous deliveries and git are never traversed.
    foreach ($name in @('game', 'tools/check', 'tools/art')) {
        $path = Join-Path $Root $name
        foreach ($file in Get-ChildItem -LiteralPath $path -File -Recurse -Force) {
            $relative = $file.FullName.Substring($Root.Length + 1)
            Copy-PackageFile $file.FullName $Destination $relative
        }
    }
    # docs: only what the repository tracks. Untracked work in progress there
    # (a handbook being written, its renderer and page renders) is not delivered.
    foreach ($relative in @(Get-TrackedFiles $Root 'docs')) {
        Copy-PackageFile (Join-Path $Root $relative) $Destination $relative
    }
    foreach ($name in @('BUILD.ps1', 'TEST.ps1', 'RUN.ps1', 'FORMAT.ps1', 'BAKE-HIT-MASKS.ps1', 'START-HERE.txt', '.stylua.toml')) {
        Copy-PackageFile (Join-Path $Root $name) $Destination $name
    }
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $Root 'tools') -File -Filter '*.ps1') {
        Copy-PackageFile $file.FullName $Destination ('tools/' + $file.Name)
    }
    foreach ($file in Get-ChildItem -LiteralPath $RuntimeRoot -File) {
        if ($file.Extension -in @('.exe', '.dll') -or $file.Name -in @('license.txt', 'readme.txt')) {
            Copy-PackageFile $file.FullName $Destination ('toolchain/love-11.5-win64/' + $file.Name)
        }
    }
    foreach ($name in @('stylua.exe', 'LICENSE.md', 'PROVENANCE.txt')) {
        Copy-PackageFile (Join-Path $Root ('toolchain/stylua/' + $name)) $Destination ('toolchain/stylua/' + $name)
    }
}

function Write-PackageManifest([string]$Root, [string]$Variant, [string]$Version, [string]$Fingerprint, $SourceFiles, $Evidence = @()) {
    foreach ($receipt in @($Evidence)) {
        if ($null -eq $receipt -or $receipt -is [string] -or $receipt.sourceFingerprint -ne $Fingerprint) {
            throw 'Manifest evidence must contain structured receipts for this source fingerprint.'
        }
    }
    $manifest = [ordered]@{
        schema = 1; variant = $Variant; version = $Version
        sourceFingerprint = $Fingerprint; createdUtc = [DateTime]::UtcNow.ToString('o')
        fingerprintScope = 'Sorted path LF SHA256 LF for every original game file. Generated build-fingerprint.txt is excluded.'
        sourceFiles = @($SourceFiles); evidence = @($Evidence)
        files = @(Get-PackageTree $Root @('PACKAGE-MANIFEST.json'))
    }
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Root 'PACKAGE-MANIFEST.json') -Encoding utf8
}

function Assert-PackageManifest([string]$Root, [string]$Fingerprint) {
    $manifest = Get-Content -LiteralPath (Join-Path $Root 'PACKAGE-MANIFEST.json') -Raw | ConvertFrom-Json
    if ($manifest.schema -ne 1 -or $manifest.sourceFingerprint -ne $Fingerprint) { throw 'Package manifest identifies a different source.' }
    foreach ($receipt in @($manifest.evidence)) {
        if ($null -eq $receipt -or $receipt -is [string] -or $receipt.sourceFingerprint -ne $Fingerprint) {
            throw 'Package manifest has invalid evidence receipts.'
        }
    }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($file in $manifest.files) {
        if (-not $seen.Add($file.path)) { throw "Duplicate package manifest path: $($file.path)" }
        $path = Assert-ChildPath (Join-Path $Root $file.path) $Root
        if ((Get-Item -LiteralPath $path).Length -ne $file.bytes) { throw "Package length mismatch: $($file.path)" }
        Check-Hash $file.sha256 (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash ('manifest ' + $file.path)
    }
    if ($seen.Count -ne @(Get-PackageTree $Root @('PACKAGE-MANIFEST.json')).Count) { throw 'Package has files not in its manifest.' }
    return $manifest
}
