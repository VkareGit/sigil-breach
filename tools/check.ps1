$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'project.ps1')
$project = Get-Project
New-Item -ItemType Directory -Force -Path $project.Qa | Out-Null
$manifest = Join-Path $project.Qa 'lua-files.txt'
$report = Join-Path $project.Qa 'architecture.txt'
$relativePaths = Get-ChildItem -LiteralPath $project.Source -File -Filter '*.lua' -Recurse | Sort-Object FullName | ForEach-Object { $_.FullName.Substring($project.Source.Length + 1).Replace('\', '/') }
[IO.File]::WriteAllLines($manifest, [string[]]$relativePaths, [Text.UTF8Encoding]::new($false))
$runtime = Join-Path $project.Root 'toolchain\love-11.5-win64\lovec.exe'
$literals = Join-Path $PSScriptRoot 'check\literals.txt'
$edges = Join-Path $PSScriptRoot 'check\presentation-edges.txt'
$arguments = @((Join-Path $PSScriptRoot 'check'), $manifest, $project.Source, $report, $literals, $edges) | ForEach-Object { '"' + $_ + '"' }
$null = Invoke-IsolatedGame $runtime $arguments $project.Root $project.Qa 'architecture' 60
Get-Content -LiteralPath $report | Select-Object -Last 1
