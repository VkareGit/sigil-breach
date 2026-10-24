$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
public static class CleanAtlas32 {
  static bool Spill(Color c) { return (c.G>65 && c.G>c.R*1.4 && c.G>c.B*1.4) || (c.R>155 && c.R>c.G*2.45 && c.R>c.B*2.45); }
  public static void Run(string input,string output) {
    using(var src=new Bitmap(input)) using(var dst=new Bitmap(src.Width,src.Height,PixelFormat.Format32bppArgb)) {
      int removed=0, repaired=0;
      for(int y=0;y<src.Height;y++) for(int x=0;x<src.Width;x++) {
        Color c=src.GetPixel(x,y);
        if(c.A<80) { removed++; continue; }
        int a=c.A>=240 ? 255 : (int)Math.Round((c.A-80)*255.0/160);
        bool edge=c.A<225;
        if(!edge && Spill(c)) {
          for(int dy=-2;dy<=2&&!edge;dy++) for(int dx=-2;dx<=2&&!edge;dx++) {
            int xx=x+dx,yy=y+dy;
            if(xx<0||yy<0||xx>=src.Width||yy>=src.Height||src.GetPixel(xx,yy).A<80) edge=true;
          }
        }
        if(edge && Spill(c)) {
          int best=999; Color donor=c;
          for(int dy=-8;dy<=8;dy++) for(int dx=-8;dx<=8;dx++) {
            int xx=x+dx, yy=y+dy, dist=dx*dx+dy*dy;
            if(xx<0||yy<0||xx>=src.Width||yy>=src.Height||dist>=best)continue;
            Color n=src.GetPixel(xx,yy);
            if(n.A>=240 && !Spill(n)) { donor=n; best=dist; }
          }
          if(best<999){c=donor;repaired++;} else {removed++;continue;}
        }
        dst.SetPixel(x,y,Color.FromArgb(a,c.R,c.G,c.B));
      }
      dst.Save(output,ImageFormat.Png);
      Console.WriteLine(input+": transparent pixels="+removed+", edge donor repairs="+repaired);
    }
  }
}
'@
foreach($kind in @('shotgun','revolver')) {
  [CleanAtlas32]::Run((Join-Path $PSScriptRoot ($kind+'-cycle-candidate.png')),(Join-Path $PSScriptRoot ($kind+'-cycle-clean.png')))
  $src=[Drawing.Bitmap]::new((Join-Path $PSScriptRoot ($kind+'-cycle-clean.png')))
  try {
    foreach($n in 6..12) {
      $col=($n-1)%4; $row=[math]::Floor(($n-1)/4)
      $x=[int][math]::Round($col*313.5); $y=[int][math]::Round($row*313.5)
      $crop=$src.Clone([Drawing.Rectangle]::new($x,$y,313,313),[Drawing.Imaging.PixelFormat]::Format32bppArgb)
      try { $crop.Save((Join-Path $PSScriptRoot ($kind+'-clean-'+$n+'.png')),[Drawing.Imaging.ImageFormat]::Png) } finally {$crop.Dispose()}
    }
  } finally {$src.Dispose()}
}
