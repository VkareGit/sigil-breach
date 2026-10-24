$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    & (Join-Path $PSScriptRoot 'tools\package-check.ps1')
    & (Join-Path $PSScriptRoot 'TEST.ps1') -Suite All
    & (Join-Path $PSScriptRoot 'tools\build.ps1')
    & (Join-Path $PSScriptRoot 'tools\verify.ps1')
}
finally { Pop-Location }

