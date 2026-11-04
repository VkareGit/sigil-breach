# The anatomy tools (plan v10 V7). Export an annotation as data, or generate
# one from part layers (a legend file: { id, atlas, body, parts = { { id,
# zone, material, hittable?, masks = { [image] = mask image } } } }).
# -Install copies the data file into game/src/content/art/anatomy/ (list it
# in content/art/anatomy/index.lua), then bake the masks.
# Usage: .\EXPORT-ANATOMY.ps1 <id> [-Install]   or   -Legend <file> [-Install]
param([string]$Id, [string]$Legend, [switch]$Install)
$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'tools/win/project.ps1')
$project = Get-Project
New-Item -ItemType Directory -Force -Path $project.Qa | Out-Null
$runtime = Get-LoveRuntime -Console
if ($Legend) {
    $Legend = (Resolve-Path -LiteralPath $Legend).Path
    $text = Get-Content -LiteralPath $Legend -Raw
    if ($text -notmatch "id\s*=\s*'([\w]+)'") { throw 'The legend names no id.' }
    $Id = $Matches[1]
    $flag = '--anatomy-layers=' + $Legend
} elseif ($Id) {
    $flag = '--anatomy-export=' + $Id
} else { throw 'Give an annotation id or -Legend <file>.' }
$written = Join-Path $project.Qa ('anatomy-' + $Id + '.lua')
$session = Enter-QaSession $project.Qa
try {
    $previous = Last-Write $written
    $run = Invoke-IsolatedGame $runtime @(('"' + $project.Source + '"'), ('"' + $flag + '"')) $project.Root $project.Qa ('anatomy-' + $Id) 300
    Require-Fresh $written $run.Started $previous
}
finally { Exit-QaSession $session }
Get-Content -LiteralPath $run.Stdout
if ($run.ExitCode -ne 0) { throw ('The annotation has problems; see ' + $run.Stdout) }
if ($Install) {
    $destination = Join-Path $project.Source ('src/content/art/anatomy/' + $Id + '.lua')
    Copy-Item -LiteralPath $written -Destination $destination -Force
    & (Join-Path $project.Root 'scripts/win/FORMAT.ps1') -Target @(('game/src/content/art/anatomy/' + $Id + '.lua'))
    if ($LASTEXITCODE -ne 0) { throw 'The annotation failed formatting validation.' }
    Write-Host ('Annotation installed: ' + $destination)
} else { Write-Host ('Annotation written: ' + $written) }
