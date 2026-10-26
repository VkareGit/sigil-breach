# One check of a demon (plan v10 V7): every element the game needs of it,
# each OK or MISSING with what is wrong. Usage: .\CHECK-CREATURE.ps1 <id>
param([Parameter(Mandatory = $true)][string]$Id)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'tools/project.ps1')
$project = Get-Project
New-Item -ItemType Directory -Force -Path $project.Qa | Out-Null
$runtime = Join-Path $project.Root 'toolchain/love-11.5-win64/lovec.exe'
$report = Join-Path $project.Qa ('creature-' + $Id + '.txt')
$session = Enter-QaSession $project.Qa
try {
    $previous = Last-Write $report
    $run = Invoke-IsolatedGame $runtime @(('"' + $project.Source + '"'), ('--check-creature=' + $Id)) $project.Root $project.Qa ('check-creature-' + $Id) 300
    Require-Fresh $report $run.Started $previous
}
finally { Exit-QaSession $session }
Get-Content -LiteralPath $report
exit $run.ExitCode