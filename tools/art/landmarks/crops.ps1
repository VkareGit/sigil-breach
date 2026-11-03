param(
    [Parameter(Mandatory = $true)][string]$Kind,
    [Parameter(Mandatory = $true)][int[]]$Frame,
    [string]$Points = '',
    [int]$Scale = 2
)
# Landmark annotation (plan v7 H0): a magnified crop of a painted frame with a
# source-pixel grid (lines every 16 px, labels every 32 px), optionally with
# numbered markers at source pixels "x,y;x,y". Frame cuts come from the game:
# run `lovec game --hit-review` first (work/qa-v<n>/hit-frame-rects.csv).
# Output: work/annotate/<kind>-<frame>.png. Kind 'art-leap' / 'art-evade'
# for the ability sheets.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../../project.ps1')
$project = Get-Project
$rects = Import-Csv (Join-Path $project.Qa 'hit-frame-rects.csv')
$out = Join-Path $project.Root 'work/annotate'
New-Item -ItemType Directory -Force -Path $out | Out-Null
if (-not (Test-SigilWindows)) {
    $selected = foreach ($f in $Frame) {
        $r = $rects | Where-Object { $_.kind -eq $Kind -and [int]$_.frame -eq $f } | Select-Object -First 1
        if (-not $r) { throw "no frame $Kind $f in hit-frame-rects.csv" }
        $r
    }
    & (Join-Path $PSScriptRoot '../annotations/export.ps1') -Mode crops -Rows @($selected) -Output $out -Scale $Scale -Points $Points
    return
}
Add-Type -AssemblyName System.Drawing
foreach ($f in $Frame) {
    $r = $rects | Where-Object { $_.kind -eq $Kind -and [int]$_.frame -eq $f } | Select-Object -First 1
    if (-not $r) { throw "no frame $Kind $f in hit-frame-rects.csv" }
    $x0 = [int]$r.x; $y0 = [int]$r.y; $w = [int]$r.w; $h = [int]$r.h
    $src = [System.Drawing.Image]::FromFile((Join-Path $project.Source $r.image))
    $bmp = New-Object System.Drawing.Bitmap ([int]($w * $Scale + 60)), ([int]($h * $Scale + 30))
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::FromArgb(255, 40, 70, 40))
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $dest = New-Object System.Drawing.Rectangle 50, 20, ([int]($w * $Scale)), ([int]($h * $Scale))
    $g.DrawImage($src, $dest, $x0, $y0, $w, $h, [System.Drawing.GraphicsUnit]::Pixel)
    $font = New-Object System.Drawing.Font 'Arial', 9
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(110, 255, 255, 255)), 1
    $strong = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(200, 0, 255, 255)), 1
    for ($x = [math]::Ceiling($x0 / 16) * 16; $x -lt $x0 + $w; $x += 16) {
        $px = 50 + ($x - $x0) * $Scale
        $p = $pen; if ($x % 64 -eq 0) { $p = $strong }
        $g.DrawLine($p, $px, 20, $px, 20 + $h * $Scale)
        if ($x % 32 -eq 0) { $g.DrawString("$x", $font, [System.Drawing.Brushes]::Yellow, $px - 10, 3) }
    }
    for ($y = [math]::Ceiling($y0 / 16) * 16; $y -lt $y0 + $h; $y += 16) {
        $py = 20 + ($y - $y0) * $Scale
        $p = $pen; if ($y % 64 -eq 0) { $p = $strong }
        $g.DrawLine($p, 50, $py, 50 + $w * $Scale, $py)
        if ($y % 32 -eq 0) { $g.DrawString("$y", $font, [System.Drawing.Brushes]::Yellow, 2, $py - 7) }
    }
    if ($Points) {
        $mark = New-Object System.Drawing.Pen ([System.Drawing.Color]::Magenta), 2
        $bold = New-Object System.Drawing.Font 'Arial', 10, ([System.Drawing.FontStyle]::Bold)
        $n = 0
        foreach ($pt in $Points.Split(';')) {
            $n++
            $xy = $pt.Split(','); $sx = 50 + ([int]$xy[0] - $x0) * $Scale; $sy = 20 + ([int]$xy[1] - $y0) * $Scale
            $g.DrawLine($mark, $sx - 6, $sy, $sx + 6, $sy); $g.DrawLine($mark, $sx, $sy - 6, $sx, $sy + 6)
            $g.DrawString("$n", $bold, [System.Drawing.Brushes]::Magenta, $sx + 4, $sy - 16)
        }
    }
    $file = Join-Path $out "$Kind-$f.png"
    $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose(); $src.Dispose()
    $file
}
