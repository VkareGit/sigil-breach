# Cheap regressions for the portability gate; no game or player saves are touched.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'project.ps1')
$project = Get-Project
$fixture = Assert-ChildPath (Join-Path $project.Qa ('platform-' + [Guid]::NewGuid().ToString('N'))) $project.Qa
$checks = 0
try {
    foreach ($name in @('src/Example.lua','assets/art/Example.png','tests/fixtures/Example.save')) {
        $path = Join-Path $fixture $name
        New-Item -ItemType Directory -Force (Split-Path -Parent $path) | Out-Null
        [IO.File]::WriteAllText($path, '')
    }
    $probe = Join-Path $fixture 'main.lua'
    $report = Join-Path $fixture 'case.txt'
    foreach ($literal in @('src.example','Assets/art/Example.png','assets/art/example.png','tests/fixtures/example.save','example.png')) {
        [IO.File]::WriteAllText($probe, ("return '" + $literal + "'"))
        $rejected = $false
        try { & (Join-Path $PSScriptRoot 'check-paths.ps1') -Source $fixture -Report $report 6>$null } catch { $rejected = $true }
        if (-not $rejected -or [IO.File]::ReadAllText($report) -notmatch '(?m)^CASE:') { throw "Case checker accepted $literal" }
        $checks++
    }
    [IO.File]::WriteAllText($probe, "return 'src.Example', 'assets/art/Example.png', 'tests/fixtures/Example.save'")
    & (Join-Path $PSScriptRoot 'check-paths.ps1') -Source $fixture -Report $report 6>$null
    $checks++
    $outside = Join-Path ($fixture + '-outside') 'file'
    $rejected = $false
    try { Assert-ChildPath $outside $fixture | Out-Null } catch { $rejected = $true }
    if (-not $rejected) { throw 'Sibling path accepted as a child.' }
    $checks++
    Write-Host "PLATFORM: $checks checks passed."
}
finally {
    $fixture = Assert-ChildPath $fixture $project.Qa
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
