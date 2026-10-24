param([switch]$Apply)
# Checks the exact two archived v16 firearm PNGs. -Apply restores only missing
# files at their original paths; existing artwork is never overwritten.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$artRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'game/assets/art'))
$allowed = @(
    'game/assets/art/shotgun-iron-v16.png',
    'game/assets/art/revolver-iron-v16.png'
)
$manifestPath = Join-Path $PSScriptRoot 'manifest-weapons-0.32.csv'
$rows = @(Import-Csv -LiteralPath $manifestPath)
if ($rows.Count -ne $allowed.Count) { throw 'Expected exactly two manifest rows.' }
$manifest = @{}
foreach ($row in $rows) {
    if ($row.Path -cnotin $allowed -or $manifest.ContainsKey($row.Path)) {
        throw "Unexpected or duplicate manifest path: $($row.Path)"
    }
    if ($row.SHA256 -notmatch '^[A-Fa-f0-9]{64}$' -or [long]$row.Bytes -le 0) {
        throw "Invalid manifest evidence: $($row.Path)"
    }
    $manifest[$row.Path] = $row
}
$zipPath = Join-Path $PSScriptRoot 'SIGIL-BREACH-old-weapons-0.32.zip'
$zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
$sha = [Security.Cryptography.SHA256]::Create()
$pending = @()
$present = 0
try {
    if ($zip.Entries.Count -ne $allowed.Count) { throw 'Expected exactly two ZIP entries.' }
    $seen = @{}
    # Verify the entire archive before any write.
    foreach ($entry in $zip.Entries) {
        $row = $manifest[$entry.FullName]
        if (-not $row -or $seen.ContainsKey($entry.FullName)) {
            throw "Unexpected or duplicate ZIP entry: $($entry.FullName)"
        }
        $seen[$entry.FullName] = $true
        $stream = $entry.Open()
        try { $hash = ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
        finally { $stream.Dispose() }
        if ($entry.Length -ne [long]$row.Bytes -or $hash -ne $row.SHA256) {
            throw "ZIP differs from manifest: $($entry.FullName)"
        }
        $target = [IO.Path]::GetFullPath((Join-Path $projectRoot $entry.FullName))
        if (-not $target.StartsWith($artRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Path outside game/assets/art: $target"
        }
        if (Test-Path -LiteralPath $target) {
            if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $row.SHA256) {
                throw "Existing file differs; refusing to overwrite: $target"
            }
            $present++
        } else { $pending += [pscustomobject]@{ Entry = $entry; Target = $target } }
    }
    foreach ($item in $pending) {
        if ($Apply) {
            [IO.Directory]::CreateDirectory((Split-Path -Parent $item.Target)) | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($item.Entry, $item.Target, $false)
            Write-Output ('restored ' + $item.Entry.FullName)
        } else { Write-Output ('would restore ' + $item.Entry.FullName) }
    }
    $action = if ($Apply) { 'restored' } else { 'missing' }
    Write-Output ("2 entries match manifest; {0} already present; {1} {2}." -f $present, $pending.Count, $action)
    if (-not $Apply) { Write-Output 'Run with -Apply to restore missing files; never overwrites.' }
} finally { $sha.Dispose(); $zip.Dispose() }
