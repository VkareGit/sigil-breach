param(
  [Parameter(Mandatory)][string]$Space,      # e.g. mcp-tools-qwen-image
  [Parameter(Mandatory)][string]$Endpoint,   # e.g. generate_image
  [Parameter(Mandatory)][string]$DataJson,   # JSON array of positional inputs
  [Parameter(Mandatory)][string]$OutFile,
  [int]$TimeoutSec = 600
)
# Calls a public Hugging Face Gradio Space through its HTTP queue API and saves
# the first returned image. Anonymous calls share the Space's free GPU quota.
$ErrorActionPreference = 'Stop'
$base = "https://$Space.hf.space/gradio_api"
# Optional: a token the user sets in $env:HF_TOKEN raises the ZeroGPU quota.
# It is only sent to the Space as a header, never printed or saved.
$headers = @{}
if ($env:HF_TOKEN) { $headers['Authorization'] = "Bearer $($env:HF_TOKEN)" }
$start = Invoke-RestMethod -Method Post -Uri "$base/call/$Endpoint" -Headers $headers -ContentType 'application/json' -Body ('{"data":' + $DataJson + '}') -TimeoutSec 60
$id = $start.event_id
$stream = Invoke-WebRequest -UseBasicParsing -Uri "$base/call/$Endpoint/$id" -Headers $headers -TimeoutSec $TimeoutSec
$text = [Text.Encoding]::UTF8.GetString($stream.RawContentStream.ToArray())
$lines = $text -split "`n"
$event = ''; $payload = $null
foreach ($l in $lines) {
  if ($l -like 'event:*') { $event = $l.Substring(6).Trim() }
  elseif ($l -like 'data:*' -and ($event -eq 'complete' -or $event -eq 'error')) { $payload = $l.Substring(5).Trim(); break }
}
if ($event -ne 'complete') { throw "Space returned '$event': $payload`n$text" }
$data = $payload | ConvertFrom-Json
$url = $null
foreach ($item in $data) {
  if ($item -is [string] -and $item -match '^https?://') { $url = $item; break }
  if ($item.url) { $url = $item.url; break }
  if ($item.image.url) { $url = $item.image.url; break }
}
if (-not $url) { throw "No image in response: $payload" }
New-Item -ItemType Directory -Force (Split-Path $OutFile) | Out-Null
Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $OutFile -TimeoutSec 120
"saved $OutFile"
"url $url"
"meta $payload"
