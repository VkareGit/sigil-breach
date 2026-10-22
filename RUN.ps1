param([switch]$Release)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'tools\project.ps1')
$project = Get-Project
Push-Location $PSScriptRoot
try {
    if ($Release) { & (Join-Path $project.Release 'SIGIL-BREACH.exe') }
    else { & (Join-Path $PSScriptRoot 'toolchain\love-11.5-win64\love.exe') (Join-Path $PSScriptRoot 'game') }
}
finally { Pop-Location }

