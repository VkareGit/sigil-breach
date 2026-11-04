# The anatomy region editor (plan v10 V7): an annotation over its painted
# frames, edited with the mouse and keys; S saves work/anatomy/<id>.lua.
# Usage: .\ANATOMY-EDITOR.ps1 <annotation id> [atlas id]
param([Parameter(Mandatory = $true)][string]$Id, [string]$Atlas)
$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'tools/win/platform.ps1')
$arguments = @((Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'tools/art/anatomy_editor'), (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'game'), $Id)
if ($Atlas) { $arguments += $Atlas }
Invoke-Love $arguments
