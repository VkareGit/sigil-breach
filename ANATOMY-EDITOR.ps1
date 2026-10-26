# The anatomy region editor (plan v10 V7): an annotation over its painted
# frames, edited with the mouse and keys; S saves work/anatomy/<id>.lua.
# Usage: .\ANATOMY-EDITOR.ps1 <annotation id> [atlas id]
param([Parameter(Mandatory = $true)][string]$Id, [string]$Atlas)
$ErrorActionPreference = 'Stop'
$runtime = Join-Path $PSScriptRoot 'toolchain/love-11.5-win64/lovec.exe'
$arguments = @((Join-Path $PSScriptRoot 'tools/art/anatomy_editor'), (Join-Path $PSScriptRoot 'game'), $Id)
if ($Atlas) { $arguments += $Atlas }
& $runtime @arguments