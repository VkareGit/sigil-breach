param([string]$Mode, [object[]]$Rows, [string]$Output, [int]$Scale = 2, [string]$Points = '')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../../project.ps1')
$project = Get-Project
New-Item -ItemType Directory -Force -Path $Output | Out-Null
$manifest = Join-Path $Output 'frames.csv'
$Rows | Export-Csv -LiteralPath $manifest -NoTypeInformation -Encoding UTF8
$arguments = @($PSScriptRoot, $project.Source, $manifest, $Output, $Mode, "$Scale", $Points) | ForEach-Object { '"' + $_ + '"' }
$process = Start-SigilProcess (Get-LoveRuntime -Console) $arguments $project.Root (Join-Path $Output 'stdout.txt') (Join-Path $Output 'stderr.txt')
$null = $process.Handle
if (-not $process.WaitForExit(120000)) { Stop-SigilProcess $process; throw 'Annotation export timed out.' }
$process.WaitForExit(); $process.Refresh()
if ($process.ExitCode -ne 0) { throw "Annotation export failed; see $Output/stdout.txt and stderr.txt." }
Get-Content -LiteralPath (Join-Path $Output 'stdout.txt')
