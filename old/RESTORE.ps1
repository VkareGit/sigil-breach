param([switch]$Apply)
# Restores the archived old files to their original paths in the project.
# Without -Apply: checks every zip entry against manifest.csv (SHA-256) and
# lists what would be restored. With -Apply: writes missing files only;
# an existing file is never overwritten. notes/* stay inside the archive.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$zipPath = Join-Path $PSScriptRoot 'SIGIL-BREACH-old-assets-0.31.zip'
$manifest = @{}
foreach ($row in Import-Csv -LiteralPath (Join-Path $PSScriptRoot 'manifest.csv')) { $manifest[$row.Path] = $row.SHA256 }
$sha = [Security.Cryptography.SHA256]::Create()
$zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
$restored, $present, $checked = 0, 0, 0
try {
    foreach ($entry in $zip.Entries) {
        $expected = $manifest[$entry.FullName]
        if (-not $expected) { throw "Entry not in manifest: $($entry.FullName)" }
        $stream = $entry.Open()
        try { $hash = ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') } finally { $stream.Dispose() }
        if ($hash -ne $expected) { throw "Hash differs from manifest: $($entry.FullName)" }
        $checked++
        if ($entry.FullName -like 'notes/*') { continue }
        $target = [IO.Path]::GetFullPath((Join-Path $root $entry.FullName))
        if (-not $target.StartsWith($root + [IO.Path]::DirectorySeparatorChar)) { throw "Path outside project: $($entry.FullName)" }
        if (Test-Path -LiteralPath $target) { $present++; continue }
        if ($Apply) {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $false)
            $restored++
        } else {
            Write-Output ('would restore ' + $entry.FullName)
        }
    }
} finally { $zip.Dispose() }
Write-Output ("{0} entries match the manifest; {1} already present; {2} restored." -f $checked, $present, $restored)
if (-not $Apply) { Write-Output 'Run with -Apply to restore the missing files.' }
