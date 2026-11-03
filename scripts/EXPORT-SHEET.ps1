# The sheet tool (plan v10 V7). Re-measure an atlas sheet from its images
# (feet, sizes), or write the sheet of a new atlas from a spec file
# ({ id, size, idle?, sources = { { path, columns, rows, scale?, idle? } } }),
# and install it in game/src/content/art/sheets/. A new atlas also needs its
# line in content/art/sheets/index.lua.
# Usage: .\EXPORT-SHEET.ps1 <atlas>   or   .\EXPORT-SHEET.ps1 -Spec <file>
param([string]$Id, [string]$Spec)
$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'tools/project.ps1')
$project = Get-Project
New-Item -ItemType Directory -Force -Path $project.Qa | Out-Null
$runtime = Get-LoveRuntime -Console
if ($Spec) {
    $Spec = (Resolve-Path -LiteralPath $Spec).Path
    $text = Get-Content -LiteralPath $Spec -Raw
    if ($text -notmatch "id\s*=\s*'([\w]+)'") { throw 'The spec names no id.' }
    $Id = $Matches[1]
    $flag = '--sheet-spec=' + $Spec
} elseif ($Id) {
    $flag = '--sheet-export=' + $Id
} else { throw 'Give an atlas id or -Spec <file>.' }
$written = Join-Path $project.Qa ('sheet-' + $Id + '.lua')
$session = Enter-QaSession $project.Qa
try {
    $previous = Last-Write $written
    $run = Invoke-IsolatedGame $runtime @(('"' + $project.Source + '"'), ('"' + $flag + '"')) $project.Root $project.Qa ('sheet-' + $Id) 300
    Require-Fresh $written $run.Started $previous
}
finally { Exit-QaSession $session }
$destination = Join-Path $project.Source ('src/content/art/sheets/' + $Id + '.lua')
Copy-Item -LiteralPath $written -Destination $destination -Force
& (Join-Path $project.Root 'FORMAT.ps1') -Target @(('game/src/content/art/sheets/' + $Id + '.lua'))
if ($LASTEXITCODE -ne 0) { throw 'The sheet failed formatting validation.' }
Get-Content -LiteralPath $run.Stdout
Write-Host ('Sheet installed: ' + $destination + '. Check its anchors, then BAKE-HIT-MASKS.ps1.')