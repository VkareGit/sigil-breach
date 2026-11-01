# Tests the source, which is all a run through `love game` needs. -Package also builds and
# verifies the EXE and the ZIPs, about twelve minutes more: only when a release is wanted.
param([switch]$Package)
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
. (Join-Path $PSScriptRoot 'tools\project.ps1')
# One lock for the whole run: tests, packaging and verification share the same outputs,
# and another run must not replace them between one step and the next.
$session = Enter-QaSession (Get-Project).Qa
try {
    if ($Package) { & (Join-Path $PSScriptRoot 'tools\package-check.ps1') }
    # The showcase walks every painted hall: it outgrew the default limit.
    & (Join-Path $PSScriptRoot 'TEST.ps1') -Suite All -TestTimeoutSeconds 600
    if ($Package) {
        & (Join-Path $PSScriptRoot 'tools\build.ps1')
        & (Join-Path $PSScriptRoot 'tools\verify.ps1') -TestTimeoutSeconds 600
    }
}
finally {
    Exit-QaSession $session
    Pop-Location
}