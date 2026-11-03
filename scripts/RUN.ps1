param([switch]$Release)
$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'tools/project.ps1')
$project = Get-Project
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    if ($Release) { Assert-WindowsPackaging; & (Join-Path $project.Release 'SIGIL-BREACH.exe') }
    else { Invoke-Love @((Join-Path (Split-Path -Parent $PSScriptRoot) 'game')) }
}
finally { Pop-Location }

