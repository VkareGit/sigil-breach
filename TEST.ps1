param(
    [ValidateSet('All', 'Architecture', 'Mechanics', 'Input', 'Render')][string]$Suite = 'All',
    [ValidateRange(10, 1800)][int]$TestTimeoutSeconds = 300
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'tools\project.ps1')
$project = Get-Project
New-Item -ItemType Directory -Force -Path $project.Qa | Out-Null
if ($Suite -eq 'All' -or $Suite -eq 'Architecture') {
    & (Join-Path $PSScriptRoot 'FORMAT.ps1') -Check
    if ($LASTEXITCODE -ne 0) { throw 'Lua formatting differs; run FORMAT.ps1.' }
    & (Join-Path $PSScriptRoot 'tools\check.ps1')
}
$flags = switch ($Suite) {
    'All' { '--selftest'; '--input-test'; '--showcase' }
    'Mechanics' { '--selftest' }
    'Input' { '--input-test' }
    'Render' { '--showcase' }
}
foreach ($flag in $flags) {
    $name = 'source-' + $flag.TrimStart('-')
    Write-Host "Testing source: $flag"
    $arguments = @(('"' + $project.Source + '"'), $flag)
    $runtime = Join-Path $PSScriptRoot 'toolchain\love-11.5-win64\lovec.exe'
    $null = Invoke-IsolatedGame $runtime $arguments $project.Root $project.Qa $name $TestTimeoutSeconds
    Write-Host "PASS: $flag"
}
