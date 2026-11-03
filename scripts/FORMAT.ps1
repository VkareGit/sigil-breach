param(
    [switch]$Check,
    [Alias('Path')][string[]]$Target = @('game/src', 'game/qa', 'game/tests', 'game/main.lua', 'game/conf.lua', 'tools/check')
)

$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'tools/platform.ps1')
$formatter = Get-Stylua

$formatArguments = @('--config-path', (Join-Path (Split-Path -Parent $PSScriptRoot) '.stylua.toml'), '--verify', '--color', 'Never')
if ($Check) {
    $formatArguments += @('--check', '--output-format', 'Summary')
}
$formatArguments += '--'
foreach ($item in $Target) {
    $resolved = if ([IO.Path]::IsPathRooted($item)) { $item } else { Join-Path (Split-Path -Parent $PSScriptRoot) $item }
    if (-not (Test-Path -LiteralPath $resolved)) {
        throw "Formatting target does not exist: $resolved"
    }
    $formatArguments += $resolved
}

# Only the selected source tree is traversed; release packages, backups and
# downloaded dependencies are excluded from the default invocation.
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    & $formatter @formatArguments
    $formatExitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}
exit $formatExitCode
