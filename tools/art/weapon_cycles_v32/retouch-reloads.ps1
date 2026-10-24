$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
public static class ReloadRetouch32 {
  // Exact authored chamber positions. Hidden chambers deliberately have no
  // visible patch: the existing painted glove remains in front of them.
  class Hole {public int Slot; public double X,Y,RX,RY,MinX; public Hole(int slot,double x,double y,double rx,double ry,double minX=-1){Slot=slot;X=x;Y=y;RX=rx;RY=ry;MinX=minX;}}
  static int Edge(int n){return (int)Math.Round(n*313.5);}
  static Bitmap Cell(Bitmap src,int n){int col=(n-1)%4,row=(n-1)/4;return src.Clone(new Rectangle(Edge(col),Edge(row),Edge(col+1)-Edge(col),Edge(row+1)-Edge(row)),PixelFormat.Format32bppArgb);}
  static Color Sample(Bitmap s,double x,double y){return s.GetPixel(Math.Max(0,Math.Min(s.Width-1,(int)Math.Round(x))),Math.Max(0,Math.Min(s.Height-1,(int)Math.Round(y))));}
  static void Stamp(Bitmap dst,Bitmap donor,Hole h,double sx,double sy,double radius,bool primer,double shade) {
    for(int y=(int)Math.Floor(h.Y-h.RY-1);y<=(int)Math.Ceiling(h.Y+h.RY+1);y++) for(int x=(int)Math.Floor(h.X-h.RX-1);x<=(int)Math.Ceiling(h.X+h.RX+1);x++) {
      if(x<0||y<0||x>=dst.Width||y>=dst.Height||x<h.MinX)continue;
      double u=(x-h.X)/h.RX,v=(y-h.Y)/h.RY, d=Math.Sqrt(u*u+v*v);
      double blend=Math.Min(1,Math.Max(0,(1-d)*Math.Min(h.RX,h.RY)));
      if(blend<=0)continue;
      Color old=dst.GetPixel(x,y); if(old.A<200)continue;
      Color n=Sample(donor,sx+u*radius,sy+v*radius);
      int r=(int)Math.Round(old.R*(1-blend)+n.R*shade*blend),g=(int)Math.Round(old.G*(1-blend)+n.G*shade*blend),b=(int)Math.Round(old.B*(1-blend)+n.B*shade*blend);
      dst.SetPixel(x,y,Color.FromArgb(old.A,Math.Min(255,r),Math.Min(255,g),Math.Min(255,b)));
    }
  }
  static void DrawNative(Graphics g,Bitmap b,int x,int y){g.DrawImageUnscaled(b,x,y);}
  public static void Run(string folder,string kind) {
    bool shot=kind=="shotgun"; int capacity=shot?2:6;
    var holes=new Dictionary<int,Hole[]>();
    if(shot){
      holes[6]=new[]{new Hole(0,201,149,14,14),new Hole(1,225,144,14,14)};
      holes[7]=new[]{new Hole(0,155,137,15,16),new Hole(1,182,126,14,16)};
      holes[9]=new[]{new Hole(0,168,128,15,16),new Hole(1,193,119,15,16)};
      holes[10]=new[]{new Hole(0,169,130,14,15),new Hole(1,193,116,14,16)};
      holes[11]=new[]{new Hole(0,165,136,12,14,159),new Hole(1,192,129,14,16)};
    }else{
      holes[6]=new[]{new Hole(0,128,165,7,8),new Hole(1,144,168,6,8),new Hole(2,148,184,4,7),new Hole(3,141,198,5,7),new Hole(5,114,180,6,7)};
      holes[7]=new[]{new Hole(0,136,140,8,9),new Hole(1,152,139,8,9),new Hole(2,164,156,8,9),new Hole(3,154,173,8,9),new Hole(4,135,172,8,9),new Hole(5,126,155,8,9)};
      holes[9]=new[]{new Hole(1,173,145,7,8),new Hole(2,180,161,7,8),new Hole(3,163,178,7,8),new Hole(4,147,173,6,7)};
      holes[10]=new[]{new Hole(1,173,154,6,8),new Hole(2,167,172,7,8),new Hole(3,154,183,6,7)};
      holes[11]=new[]{new Hole(0,164,141,10,9,156),new Hole(1,180,151,9,10),new Hole(2,178,170,10,11),new Hole(3,159,182,7,7,156)};
      holes[12]=new[]{new Hole(0,140,139,10,10),new Hole(1,165,141,10,11),new Hole(2,167,162,10,11),new Hole(3,150,175,10,10),new Hole(4,135,161,10,11),new Hole(5,151,134,6,7)};
    }
    int total=16+holes.Count*(capacity+1), rows=shot?(int)Math.Ceiling(total/4.0):8, width=shot?1254:2508, height=Edge(rows);
    using(var src=new Bitmap(Path.Combine(folder,kind+"-cycle-clean.png")))
    using(var dst=new Bitmap(width,height,PixelFormat.Format32bppArgb))
    using(var empty=Cell(src,7)) using(var loaded=Cell(src,shot?11:12)) using(var g=Graphics.FromImage(dst)) {
      g.CompositingMode=System.Drawing.Drawing2D.CompositingMode.SourceCopy;
      g.DrawImageUnscaled(src,0,0);
      // The generated eighth pose crosses its neighbour's cell. Remove only
      // the isolated strip from that neighbour; its own arm stays untouched.
      if(shot)for(int y=Edge(1);y<Edge(2);y++)for(int x=Edge(2)+307;x<Edge(3);x++)dst.SetPixel(x,y,Color.Transparent);
      var json=new StringBuilder("{\"width\":"+width+",\"height\":"+height+",\"variants\":[");
      bool first=true; int index=16;
      foreach(var pair in holes) {
        for(int count=0;count<=capacity;count++) using(var cell=Cell(src,pair.Key)) {
          if(shot&&pair.Key==7)for(int y=0;y<cell.Height;y++)for(int x=307;x<cell.Width;x++)cell.SetPixel(x,y,Color.Transparent);
          foreach(var hole in pair.Value) {
            // Borrow the painted bore and brass primer from this very sheet.
            // No geometry/UI font approximation and no new metallic highlights.
            Stamp(cell,empty,hole,shot?155:136,shot?137:140,shot?14:8,false,1);
            if(hole.Slot<count)Stamp(cell,loaded,hole,shot?192:140,shot?129:139,shot?13:9,true,shot?0.93:0.86);
          }
          int offset=index-16,col=index%4,row=index/4;
          // Keep the original sixteen poses in the upper-left 4x4. Pack
          // cylinder variants beside/below them, staying under 4096 per axis.
          if(!shot){ if(offset<16){col=4+offset%4;row=offset/4;}else{col=(offset-16)%8;row=4+(offset-16)/8;} }
          int tx=Edge(col),ty=Edge(row);
          DrawNative(g,cell,tx,ty);
          if(!first)json.Append(','); first=false;
          json.Append("{\"base\":"+pair.Key+",\"rounds\":"+count+",\"index\":"+(index+1)+",\"rect\":["+tx+","+ty+","+cell.Width+","+cell.Height+"]}");
          if(pair.Key==(shot?11:12))cell.Save(Path.Combine(folder,kind+"-loaded-"+count+".png"),ImageFormat.Png);
          index++;
        }
      }
      json.Append("]}");
      File.WriteAllText(Path.Combine(folder,kind+"-variants.json"),json.ToString());
      dst.Save(Path.Combine(folder,kind+"-cycle-retouched.png"),ImageFormat.Png);
      Console.WriteLine(kind+" "+total+" registered frames, "+height+" px high.");
    }
  }
}
'@
[ReloadRetouch32]::Run($PSScriptRoot,'shotgun')
[ReloadRetouch32]::Run($PSScriptRoot,'revolver')
