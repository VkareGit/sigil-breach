$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'tools/project.ps1')
$project = Get-Project
New-Item -ItemType Directory -Force -Path $project.Qa | Out-Null
$runtime = Get-LoveRuntime -Console
$arguments = @(('"' + $project.Source + '"'), '--bake-hit-masks')
$baked = Join-Path $project.Qa 'hit-masks.lua'
$session = Enter-QaSession $project.Qa
try {
    $previous = Last-Write $baked
    $run = Invoke-IsolatedGame $runtime $arguments $project.Root $project.Qa 'bake-hit-masks' 300
    Require-Fresh $baked $run.Started $previous
    # Under the same lock: another run may not replace the result between the check and the copy.
    $destination = Join-Path $project.Source 'src/content/art/hit_masks.lua'
    Copy-Item -LiteralPath $baked -Destination $destination -Force
    & (Join-Path $project.Root 'FORMAT.ps1') -Target @('game/src/content/art/hit_masks.lua')
    if ($LASTEXITCODE -ne 0) { throw 'Baked masks failed formatting validation.' }
}
finally { Exit-QaSession $session }
Write-Host 'Masks rebuilt from existing art. Run TEST.ps1 before release.'
