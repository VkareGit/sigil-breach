$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'project.ps1')
$project = Get-Project
New-Item -ItemType Directory -Force -Path $project.Qa | Out-Null
& (Join-Path $PSScriptRoot 'check-paths.ps1') -Source $project.Source -Report (Join-Path $project.Qa 'path-case.txt')
$manifest = Join-Path $project.Qa 'lua-files.txt'
$filesManifest = Join-Path $project.Qa 'game-files.txt'
$report = Join-Path $project.Qa 'architecture.txt'
$allPaths = @(Get-ChildItem -LiteralPath $project.Source -File -Recurse | Sort-Object FullName | ForEach-Object { $_.FullName.Substring($project.Source.Length + 1).Replace('\', '/') })
$relativePaths = $allPaths | Where-Object { $_.EndsWith('.lua') }
[IO.File]::WriteAllLines($manifest, [string[]]$relativePaths, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllLines($filesManifest, [string[]]$allPaths, [Text.UTF8Encoding]::new($false))
$runtime = Get-LoveRuntime -Console
$literals = Join-Path $PSScriptRoot 'check/literals.txt'
$edges = Join-Path $PSScriptRoot 'check/presentation-edges.txt'
$arguments = @((Join-Path $PSScriptRoot 'check'), $manifest, $project.Source, $report, $literals, $edges, $filesManifest) | ForEach-Object { '"' + $_ + '"' }
$session = Enter-QaSession $project.Qa
try { $null = Invoke-IsolatedGame $runtime $arguments $project.Root $project.Qa 'architecture' 60 -NoDisplay }
finally { Exit-QaSession $session }
Get-Content -LiteralPath $report | Select-Object -Last 1
