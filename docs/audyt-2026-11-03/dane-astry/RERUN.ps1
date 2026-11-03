param([ValidateSet('State','Combat','Render')][string]$Probe='State')
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$env:APPDATA=Join-Path $taskRoot 'work/appdata'
New-Item -ItemType Directory -Force -Path (Join-Path $env:APPDATA 'LOVE/sigil-breach-qa') | Out-Null
$env:SIGIL_AUDIT_GAME=Join-Path $taskRoot 'game'
$folder=switch($Probe) { 'State' {'probe'} 'Combat' {'combat-probe'} 'Render' {'render-probe'} }
$source=Join-Path $PSScriptRoot $folder
$env:SIGIL_AUDIT_OUT=if($Probe -eq 'State') {$PSScriptRoot} else {$source}
if($Probe -eq 'Render' -and -not (Test-Path -LiteralPath (Join-Path $source 'assets'))) {
  Copy-Item -LiteralPath (Join-Path $taskRoot 'game/assets') -Destination (Join-Path $source 'assets') -Recurse
  New-Item -ItemType Directory -Force -Path (Join-Path $source 'qa') | Out-Null
  Copy-Item -LiteralPath (Join-Path $taskRoot 'game/qa/runtime.lua') -Destination (Join-Path $source 'qa/runtime.lua')
}
. (Join-Path $taskRoot 'tools/project.ps1')
Invoke-IsolatedGame -Executable (Join-Path $taskRoot 'toolchain/love-11.5-win64/lovec.exe') -Arguments @($source) -Root $taskRoot -Qa $env:SIGIL_AUDIT_OUT -Name ('rerun-'+$Probe) -TimeoutSeconds 600
