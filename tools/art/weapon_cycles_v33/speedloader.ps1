param(
    [Parameter(Mandatory=$true)][string]$OriginalAtlas,
    [Parameter(Mandatory=$true)][string]$OutputAtlas,
    [Parameter(Mandatory=$true)][string]$PreviewDirectory
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Imaging;
public static class Speedloader33 {
  const int Stride=318, Padding=2;
  struct Hole {
    public double X,Y,RX,RY;
    public Hole(double x,double y,double rx,double ry){X=x;Y=y;RX=rx;RY=ry;}
  }
  static readonly Hole[][] Sockets={
    new[]{new Hole(184,156,12,12),new Hole(177,137,11,10),new Hole(177,176,12,12),new Hole(158,185,10,7),new Hole(144,168,8,10),new Hole(146,112,8,8)},
    new[]{new Hole(184,150,12,12),new Hole(177,135,11,9),new Hole(179,173,12,12),new Hole(165,184,10,7),new Hole(154,128,10,8)}
  };
  static bool Spill(Color c){return (c.G>65&&c.G>c.R*1.4&&c.G>c.B*1.4)||(c.R>155&&c.R>c.G*2.45&&c.R>c.B*2.45);}
  static Bitmap Cell(Bitmap source,int pose){
    int col=(pose-1)%4,row=(pose-1)/4;
    int x=(int)Math.Round(col*313.5),y=(int)Math.Round(row*313.5);
    int right=(int)Math.Round((col+1)*313.5),bottom=(int)Math.Round((row+1)*313.5);
    using(var raw=source.Clone(new Rectangle(x,y,right-x,bottom-y),PixelFormat.Format32bppArgb)){
      var clean=new Bitmap(raw.Width,raw.Height,PixelFormat.Format32bppArgb);
      for(int yy=0;yy<raw.Height;yy++)for(int xx=0;xx<raw.Width;xx++){
        Color c=raw.GetPixel(xx,yy);if(c.A<80)continue;
        bool edge=c.A<225;
        if(!edge&&Spill(c))for(int dy=-2;dy<=2&&!edge;dy++)for(int dx=-2;dx<=2&&!edge;dx++){
          int sx=xx+dx,sy=yy+dy;if(sx<0||sy<0||sx>=raw.Width||sy>=raw.Height||raw.GetPixel(sx,sy).A<80)edge=true;
        }
        if(edge&&Spill(c)){
          int best=999;Color donor=c;
          for(int dy=-8;dy<=8;dy++)for(int dx=-8;dx<=8;dx++){
            int sx=xx+dx,sy=yy+dy,d=dx*dx+dy*dy;
            if(sx<0||sy<0||sx>=raw.Width||sy>=raw.Height||d>=best)continue;
            Color n=raw.GetPixel(sx,sy);if(n.A>=240&&!Spill(n)){donor=n;best=d;}
          }
          if(best==999)continue;c=Color.FromArgb(c.A,donor.R,donor.G,donor.B);
        }
        int alpha=c.A>=240?255:(int)Math.Round((c.A-80)*255.0/160);
        clean.SetPixel(xx,yy,Color.FromArgb(alpha,c.R,c.G,c.B));
      }
      return clean;
    }
  }
  static void EmptySocket(Bitmap cell,Bitmap original,Hole h){
    // Borrow the existing painted empty chamber. The loader's unseen sixth
    // socket remains behind the glove; it never gets a fabricated outline.
    for(int y=(int)Math.Floor(h.Y-h.RY-1);y<=h.Y+h.RY+1;y++)for(int x=(int)Math.Floor(h.X-h.RX-1);x<=h.X+h.RX+1;x++){
      double u=(x-h.X)/h.RX,v=(y-h.Y)/h.RY,d=Math.Sqrt(u*u+v*v);
      if(d>=1||x<0||y<0||x>=cell.Width||y>=cell.Height)continue;
      Color old=cell.GetPixel(x,y);if(old.A<200)continue;
      double blend=Math.Min(1,(1-d)*Math.Min(h.RX,h.RY)*1.5);
      // Original atlas pose7: measured empty bore, plus its two-pixel gutter.
      Color donor=original.GetPixel(1908+138+(int)Math.Round(u*9),142+(int)Math.Round(v*10));
      cell.SetPixel(x,y,Color.FromArgb(old.A,
        (int)Math.Round(old.R*(1-blend)+donor.R*blend),
        (int)Math.Round(old.G*(1-blend)+donor.G*blend),
        (int)Math.Round(old.B*(1-blend)+donor.B*blend)));
    }
  }
  static void Put(Bitmap atlas,Bitmap cell,int index){
    int left=(index-1)%8*Stride,top=(index-1)/8*Stride;
    for(int y=0;y<Stride;y++)for(int x=0;x<Stride;x++)atlas.SetPixel(left+x,top+y,Color.Transparent);
    for(int y=0;y<cell.Height;y++)for(int x=0;x<cell.Width;x++)atlas.SetPixel(left+Padding+x,top+Padding+y,cell.GetPixel(x,y));
  }
  public static void Run(string originalPath,string sourcePath,string outputPath,string preview){
    Directory.CreateDirectory(preview);
    using(var original=new Bitmap(originalPath))using(var source=new Bitmap(sourcePath))
    using(var result=original.Clone(new Rectangle(0,0,original.Width,original.Height),PixelFormat.Format32bppArgb)){
      if(original.Width!=2544||original.Height!=2544||source.Width!=1254||source.Height!=1254)throw new Exception("Unexpected atlas dimensions");
      int[] poses={9,10,11},firstVariants={31,38,45};
      for(int phase=0;phase<3;phase++)using(var authored=Cell(source,phase==0?9:10)){
        Put(result,authored,poses[phase]);
        for(int rounds=0;rounds<=6;rounds++)using(var cell=authored.Clone(new Rectangle(0,0,authored.Width,authored.Height),PixelFormat.Format32bppArgb)){
          Hole[] holes=Sockets[phase==0?0:1];
          for(int slot=rounds;slot<holes.Length;slot++)EmptySocket(cell,original,holes[slot]);
          Put(result,cell,firstVariants[phase]+rounds);
          if(rounds==0||rounds==1||rounds==6)cell.Save(Path.Combine(preview,"loader-phase-"+poses[phase]+"-rounds-"+rounds+".png"),ImageFormat.Png);
        }
      }
      // Every other source pixel must be unchanged, including all ready,
      // firing, opened, completed-load, interrupted-close and latch poses.
      int otherChanges=0;
      for(int y=0;y<result.Height;y++)for(int x=0;x<result.Width;x++){
        int index=(y/Stride)*8+x/Stride+1;
        bool changed=index==9||index==10||index==11||(index>=31&&index<=51);
        if(!changed&&result.GetPixel(x,y).ToArgb()!=original.GetPixel(x,y).ToArgb())otherChanges++;
      }
      if(otherChanges!=0)throw new Exception("Unrelated atlas pixels changed");
      result.Save(outputPath,ImageFormat.Png);
      Console.WriteLine("Updated only insertion poses 9/10/11 and their 0..6 loader variants; all other pixels identical.");
    }
  }
}
'@
[Speedloader33]::Run(
    [IO.Path]::GetFullPath($OriginalAtlas),
    (Join-Path $PSScriptRoot 'revolver-speedloader-source.png'),
    [IO.Path]::GetFullPath($OutputAtlas),
    [IO.Path]::GetFullPath($PreviewDirectory)
)
