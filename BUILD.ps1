$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
. (Join-Path $PSScriptRoot 'tools\project.ps1')
# One lock for the whole release: tests, packaging and verification share the same outputs,
# and another run must not replace them between one step and the next.
$session = Enter-QaSession (Get-Project).Qa
try {
    & (Join-Path $PSScriptRoot 'tools\package-check.ps1')
    # The showcase walks every painted hall: it outgrew the default limit.
    & (Join-Path $PSScriptRoot 'TEST.ps1') -Suite All -TestTimeoutSeconds 600
    & (Join-Path $PSScriptRoot 'tools\build.ps1')
    & (Join-Path $PSScriptRoot 'tools\verify.ps1') -TestTimeoutSeconds 600
}
finally {
    Exit-QaSession $session
    Pop-Location
}