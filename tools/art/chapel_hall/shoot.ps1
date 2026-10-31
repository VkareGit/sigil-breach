param([string]$Output, [string]$Flag = '--hall-review', [int]$Seconds = 170)
$root = (Resolve-Path "$PSScriptRoot\..\..\..").Path
New-Item -ItemType Directory -Force $Output | Out-Null
$env:SIGIL_UI_QA_DIR = $Output.Replace('\', '/')
$love = Join-Path $root 'toolchain\love-11.5-win64\lovec.exe'
$before = if (Test-Path "$root\sigil-error.log") { (Get-Item "$root\sigil-error.log").LastWriteTime } else { $null }
$watch = [Diagnostics.Stopwatch]::StartNew()
$process = Start-Process -FilePath $love -ArgumentList "`"$root\game`"", $Flag -WorkingDirectory $root -WindowStyle Hidden -PassThru -RedirectStandardOutput "$Output\stdout.txt" -RedirectStandardError "$Output\stderr.txt"
if (-not $process.WaitForExit($Seconds * 1000)) { Stop-Process -Id $process.Id -Force; 'TIMEOUT' }
"finished after $([int]$watch.Elapsed.TotalSeconds)s"
Get-Content "$Output\stderr.txt" -Tail 10
if ((Test-Path "$root\sigil-error.log") -and (Get-Item "$root\sigil-error.log").LastWriteTime -ne $before) { Get-Content "$root\sigil-error.log" -TotalCount 12 }
(Get-ChildItem $Output -Filter *.png).Count
