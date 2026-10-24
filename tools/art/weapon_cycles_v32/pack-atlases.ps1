$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System.Drawing;
public static class PackProof32 {
  public static void Copy(Bitmap a,Bitmap b,int ax,int ay,int bx,int by,int w,int h) {
    for(int y=0;y<h;y++)for(int x=0;x<w;x++)b.SetPixel(bx+x,by+y,a.GetPixel(ax+x,ay+y));
  }
  public static int Difference(Bitmap a,Bitmap b,int ax,int ay,int bx,int by,int w,int h) {
    int count=0;
    for(int y=0;y<h;y++)for(int x=0;x<w;x++)if(a.GetPixel(ax+x,ay+y).ToArgb()!=b.GetPixel(bx+x,by+y).ToArgb())count++;
    return count;
  }
}
'@
$padding=2
$cell=318
foreach($kind in @('shotgun','revolver')) {
  $meta=Get-Content (Join-Path $PSScriptRoot ($kind+'-variants.json')) -Raw | ConvertFrom-Json
  $cols=if($kind-eq'shotgun'){4}else{8}
  $count=16+$meta.variants.Count
  $rows=[int][math]::Ceiling($count/[double]$cols)
  $src=[Drawing.Bitmap]::new((Join-Path $PSScriptRoot ($kind+'-cycle-retouched.png')))
  $dst=[Drawing.Bitmap]::new($cols*$cell,$rows*$cell,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $bases=@();$variants=@();$mismatch=0
  try {
    for($index=1;$index-le$count;$index++) {
      if($index-le16){
        $col=($index-1)%4;$row=[int][math]::Floor(($index-1)/4)
        $left=[int][math]::Round($col*313.5);$top=[int][math]::Round($row*313.5)
        $width=[int][math]::Round(($col+1)*313.5)-$left;$height=[int][math]::Round(($row+1)*313.5)-$top
        $rect=@($left,$top,$width,$height)
      }else{ $v=$meta.variants | Where-Object {$_.index-eq$index};$rect=@($v.rect) }
      $x=(($index-1)%$cols)*$cell;$y=[int][math]::Floor(($index-1)/$cols)*$cell
      # GDI+ drawing premultiplies semi-transparent edges. Copy exact ARGB
      # instead; this packer may translate pigment, never repaint it.
      [PackProof32]::Copy($src,$dst,$rect[0],$rect[1],($x+$padding),($y+$padding),$rect[2],$rect[3])
      $out=[ordered]@{index=$index;rect=@($x,$y,($rect[2]+2*$padding),($rect[3]+2*$padding));padding=$padding;sourceRect=$rect}
      if($index-le16){$bases+=[pscustomobject]$out}else{$out.base=$v.base;$out.rounds=$v.rounds;$variants+=[pscustomobject]$out}
    }
    $png=Join-Path $PSScriptRoot ($kind+'-cycle-packed.png')
    $dst.Save($png,[Drawing.Imaging.ImageFormat]::Png)
    [ordered]@{width=$dst.Width;height=$dst.Height;cell=318;padding=$padding;bases=$bases;variants=$variants} | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $PSScriptRoot ($kind+'-packed.json')) -Encoding utf8
    # The only transformation is integer translation. Compare every retained
    # source pixel with its placed counterpart before approving this packing.
    foreach($entry in @($bases)+@($variants)){
      $mismatch += [PackProof32]::Difference($src,$dst,$entry.sourceRect[0],$entry.sourceRect[1],($entry.rect[0]+$padding),($entry.rect[1]+$padding),$entry.sourceRect[2],$entry.sourceRect[3])
    }
    if($mismatch-ne0){throw "Packing changed $mismatch source pixels"}
    Write-Output ($kind+' packed '+$dst.Width+'x'+$dst.Height+'; '+$count+' poses; zero changed source pixels')
  }finally{$dst.Dispose();$src.Dispose()}
}
