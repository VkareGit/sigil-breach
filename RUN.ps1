param([switch]$Release)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'tools/project.ps1')
$project = Get-Project
Push-Location $PSScriptRoot
try {
    if ($Release) { Assert-WindowsPackaging; & (Join-Path $project.Release 'SIGIL-BREACH.exe') }
    else { Invoke-Love @((Join-Path $PSScriptRoot 'game')) }
}
finally { Pop-Location }

