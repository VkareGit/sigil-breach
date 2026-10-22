param(
    [switch]$Check,
    [Alias('Path')][string[]]$Target = @('game/src', 'game/qa', 'game/tests', 'game/main.lua', 'game/conf.lua', 'tools/check')
)

$ErrorActionPreference = 'Stop'
$formatter = Join-Path $PSScriptRoot 'toolchain/stylua/stylua.exe'
$expectedHash = '8BE0383E979B3C699BF6BFBFC0770038534D071B0479FEE188636C4B54CD338B'
if (-not (Test-Path -LiteralPath $formatter -PathType Leaf)) {
    throw 'Pinned StyLua 2.6.0 is missing from toolchain/stylua. See its PROVENANCE.txt.'
}
if ((Get-FileHash -LiteralPath $formatter -Algorithm SHA256).Hash -ne $expectedHash) {
    throw 'StyLua executable does not match the pinned 2.6.0 binary. See toolchain/stylua/PROVENANCE.txt.'
}

$formatArguments = @('--config-path', (Join-Path $PSScriptRoot '.stylua.toml'), '--verify', '--color', 'Never')
if ($Check) {
    $formatArguments += @('--check', '--output-format', 'Summary')
}
$formatArguments += '--'
foreach ($item in $Target) {
    $resolved = if ([IO.Path]::IsPathRooted($item)) { $item } else { Join-Path $PSScriptRoot $item }
    if (-not (Test-Path -LiteralPath $resolved)) {
        throw "Formatting target does not exist: $resolved"
    }
    $formatArguments += $resolved
}

# Only the selected source tree is traversed; release packages, backups and
# downloaded dependencies are excluded from the default invocation.
Push-Location $PSScriptRoot
try {
    & $formatter @formatArguments
    $formatExitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}
exit $formatExitCode
