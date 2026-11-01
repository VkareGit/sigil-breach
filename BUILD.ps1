$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    & (Join-Path $PSScriptRoot 'tools\package-check.ps1')
    # The showcase walks every painted hall: it outgrew the default limit.
    & (Join-Path $PSScriptRoot 'TEST.ps1') -Suite All -TestTimeoutSeconds 600
    & (Join-Path $PSScriptRoot 'tools\build.ps1')
    & (Join-Path $PSScriptRoot 'tools\verify.ps1') -TestTimeoutSeconds 600
}
finally { Pop-Location }

