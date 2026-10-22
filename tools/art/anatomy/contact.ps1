param([string[]]$Kind = @('stolas','buer','boss','furfur','art-evade'), [string]$Rects = 'work/qa-v27/hit-frame-rects.csv')
# Diagnostic source-UV contact sheets only; never edits production art.
Add-Type -AssemblyName System.Drawing
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$rows = Import-Csv (Join-Path $root $Rects)
$out = Join-Path $root 'work\anatomy-contact'
New-Item -ItemType Directory -Force -Path $out | Out-Null
foreach ($name in $Kind) {
  $frames = @($rows | Where-Object { $_.kind -eq $name })
  $columns=4; $cell=320; $label=24
  $bmp = New-Object System.Drawing.Bitmap ($columns*$cell), ([int][Math]::Ceiling($frames.Count/$columns)*($cell+$label))
  $g=[Drawing.Graphics]::FromImage($bmp)
  $g.Clear([Drawing.Color]::FromArgb(255,44,48,45))
  $g.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
  $font=New-Object Drawing.Font 'Arial',12
  $grid=New-Object Drawing.Pen ([Drawing.Color]::FromArgb(85,255,255,255)),1
  for ($i=0;$i -lt $frames.Count;$i++) {
    $r=$frames[$i]; $x=($i%$columns)*$cell; $y=[Math]::Floor($i/$columns)*($cell+$label)
    $src=[Drawing.Image]::FromFile((Join-Path $root ('game/'+$r.image)))
    $dest=New-Object Drawing.Rectangle ([int]$x),([int]($y+$label)),$cell,$cell
    $g.DrawImage($src,$dest,[int]$r.x,[int]$r.y,[int]$r.w,[int]$r.h,[Drawing.GraphicsUnit]::Pixel)
    $src.Dispose()
    $g.DrawString(($name+' '+$r.frame),$font,[Drawing.Brushes]::White,$x+4,$y+2)
    for ($n=1;$n -lt 10;$n++) {
      $d=$cell*$n/10
      $g.DrawLine($grid,[single]($x+$d),[single]($y+$label),[single]($x+$d),[single]($y+$label+$cell))
      $g.DrawLine($grid,[single]$x,[single]($y+$label+$d),[single]($x+$cell),[single]($y+$label+$d))
    }
  }
  $file=Join-Path $out ($name+'.png'); $bmp.Save($file,[Drawing.Imaging.ImageFormat]::Png)
  $grid.Dispose();$font.Dispose();$g.Dispose();$bmp.Dispose()
  Write-Output $file
}
