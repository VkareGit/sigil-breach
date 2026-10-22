param(
  [Parameter(Mandatory)][string]$Prompt,
  [Parameter(Mandatory)][string]$OutFile,
  [int]$Seed = 1,
  [int]$Width = 1024,
  [int]$Height = 1024,
  [string]$Model = 'flux'
)
# Free public text-to-image endpoint (no key). Only the prompt text is sent.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Web
$q = [System.Web.HttpUtility]::UrlEncode($Prompt).Replace('+', '%20')
$url = "https://image.pollinations.ai/prompt/$q`?width=$Width&height=$Height&seed=$Seed&model=$Model&nologo=true&enhance=false"
New-Item -ItemType Directory -Force (Split-Path $OutFile) | Out-Null
Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $OutFile -TimeoutSec 300
"saved $OutFile ($((Get-Item $OutFile).Length) bytes)"
