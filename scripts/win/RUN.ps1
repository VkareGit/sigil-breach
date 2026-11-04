param([switch]$Release)
$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'tools/win/project.ps1')
$project = Get-Project
Push-Location (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
try {
    if ($Release) { & (Join-Path $project.Release 'SIGIL-BREACH.exe') }
    else { Invoke-Love @((Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'game')) }
}
finally { Pop-Location }

