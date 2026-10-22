-- Import illustrated manuscript letters. No TTF, outline extraction or font fallback.
local utf8=require('utf8')
local sizes={11,12,13,14,16,18,20,22,24,28,36,42,48,64,94}
local function read(path)local f=assert(io.open(path,'rb'));local v=f:read('*a');f:close();return v end
local function write(path,v)local f=assert(io.open(path,'wb'));f:write(v);f:close()end
local function fileData(path)return love.filesystem.newFileData(read(path),path:match('[^/\\]+$'))end
local function sorted(t)local keys={};for k in pairs(t)do keys[#keys+1]=k end;table.sort(keys);return keys end
local function serialize(value)
 if type(value)=='string'then return string.format('%q',value)end
 if type(value)~='table'then return tostring(value)end
 local out={'{'};for _,k in ipairs(sorted(value))do out[#out+1]='['..serialize(k)..']='..serialize(value[k])..','end;out[#out+1]='}';return table.concat(out)
end
local function capture(root,path)
 local old=assert(loadstring(read(root..'/assets/fonts/painted/catalog.lua')))();local result={sizes={}}
 for _,size in ipairs(sizes)do local m=old.sizes[size];local target={height=m.height,top=m.top,glyphs={}}
  for cp,g in pairs(m.glyphs)do target.glyphs[cp]={advance=g.advance,w=g.w,h=g.h,dx=g.dx,dy=g.dy}end
  result.sizes[size]=target
 end
 write(path,'-- Preserved interface baseline/line-height geometry only; never used as glyph artwork.\nreturn '..serialize(result)..'\n')
 return result
end
local sourceDefs={
 {file='assets/art/alphabet-upper-v11.png',chars='ABCDEFGHIJKLMNOPQRSTUVWXYZĄĆĘŁŃÓŚŹŻ',cols=5,bands={0,234,434,641,855,1034,1267,1536},baselines={211,413,613,817,1027,1226,1469},kind='letter'},
 {file='assets/art/alphabet-lower-v11.png',chars='abcdefghijklmnopqrstuvwxyząćęłńóśźż',cols=5,bands={0,253,500,724,951,1130,1332,1536},baselines={230,448,679,882,1089,1272,1490},kind='letter'},
 {file='assets/art/alphabet-punctuation-v11.png',chars='.,:;!?+-()[]°∞=×',cols=4,kind='punctuation'},
}
local function ink(data,x,y)local _,_,_,a=data:getPixel(x,y);return a>.55 end
local function crop(data,l,t,r,b)
 local x0,y0,x1,y1=r,b,l-1,t-1
 for y=t,b do for x=l,r do if ink(data,x,y)then x0=math.min(x0,x);y0=math.min(y0,y);x1=math.max(x1,x);y1=math.max(y1,y)end end end
 assert(x1>=x0 and y1>=y0,'Empty illustrated glyph cell')
 return {x=x0,y=y0,w=x1-x0+1,h=y1-y0+1}
end
local function columnCuts(data,cols,t,b)
 local w=data:getWidth();local cuts={0}
 for col=1,cols-1 do
  local guess=w*col/cols;local radius=w/cols*.28;local candidates={}
  for x=math.floor(guess-radius),math.ceil(guess+radius)do local mass=0
   for y=t,b do if ink(data,x,y)then mass=mass+1 end end
   if mass==0 then candidates[#candidates+1]=x end
  end
  assert(#candidates>0,'No empty vertical gutter at row '..t..' / column '..col)
  local best,dist;for _,x in ipairs(candidates)do local d=math.abs(x-guess);if not dist or d<dist then best,dist=x,d end end
  -- Use the middle of its empty run, not a position immediately next to a flourish.
  local l,r=best,best;local allowed={};for _,x in ipairs(candidates)do allowed[x]=true end
  while allowed[l-1]do l=l-1 end;while allowed[r+1]do r=r+1 end
  cuts[#cuts+1]=math.floor((l+r)/2)
 end
 cuts[#cuts+1]=w;return cuts
end
local function rowCut(data,l,r,guess)
 if guess==0 or guess==data:getHeight()then return guess end
 local allowed={};local best,dist
 for y=math.max(0,guess-44),math.min(data:getHeight()-1,guess+44)do local clear=true
  for x=l,r do if ink(data,x,y)then clear=false;break end end
  if clear then allowed[y]=true;local d=math.abs(y-guess);if not dist or d<dist then best,dist=y,d end end
 end
 assert(best,'No empty horizontal gutter near '..guess..' x '..l..'..'..r)
 local top,bottom=best,best;while allowed[top-1]do top=top-1 end;while allowed[bottom+1]do bottom=bottom+1 end
 return math.floor((top+bottom)/2)
end
local function components(data)
 local w,h=data:getDimensions();local labels,parts={},{}
 for y=0,h-1 do for x=0,w-1 do if ink(data,x,y)then labels[y*w+x+1]=-1 end end end
 for seed in pairs(labels)do if labels[seed]==-1 then
  local id=#parts+1;local part={x=w,y=h,right=-1,bottom=-1,count=0,sx=0,sy=0};local queue={seed};labels[seed]=id;local head=1
  while head<=#queue do local index=queue[head];head=head+1;local x,y=(index-1)%w,math.floor((index-1)/w)
   part.x=math.min(part.x,x);part.y=math.min(part.y,y);part.right=math.max(part.right,x);part.bottom=math.max(part.bottom,y);part.count=part.count+1;part.sx=part.sx+x;part.sy=part.sy+y
   for dy=-1,1 do for dx=-1,1 do local nx,ny=x+dx,y+dy;if nx>=0 and nx<w and ny>=0 and ny<h then local n=ny*w+nx+1;if labels[n]==-1 then labels[n]=id;queue[#queue+1]=n end end end end
  end
  part.cx=part.sx/part.count;part.cy=part.sy/part.count;part.id=id;parts[id]=part
 end end
 return labels,parts
end
local accent={};for _,cp in utf8.codes('ĆŃÓŚŹŻćńóśźżij')do accent[cp]=true end
local function letterSources(root,def,data,map)
 local w,h=data:getDimensions();local labels,parts=components(data);local assigned={};local codes={};for _,cp in utf8.codes(def.chars)do codes[#codes+1]=cp end
 local cores={}
 for i,cp in ipairs(codes)do local row=math.floor((i-1)/def.cols)+1;local col=(i-1)%def.cols;local ax=(col+.5)*w/def.cols;local ay=def.baselines[row]-(def.file:find('lower')and 60 or 80)
  local best,score
  for _,p in ipairs(parts)do if p.count>250 and math.abs(p.cx-ax)<100 and math.abs(p.cy-ay)<95 then local rank=math.abs(p.cy-ay)*3+math.abs(p.cx-ax);if not score or rank<score then best,score=p,rank end end end
  assert(best,'Missing illustrated letter body: '..utf8.char(cp));assert(not cores[best.id],'Two letters selected one connected body: '..utf8.char(cp));cores[best.id]=cp
  local box={file=def.file,kind='letter',baseline=def.baselines[row],x=best.x,y=best.y,right=best.right,bottom=best.bottom,selector=cp,maskFile='assets/fonts/painted/selection-'..(def.file:find('lower')and 'lower' or 'upper')..'.png'}
  map[cp]=box;assigned[best.id]=cp
 end
 for _,cp in ipairs(codes)do local box=map[cp]
  for _,p in ipairs(parts)do if not cores[p.id]then
   local interior=p.cx>=box.x and p.cx<=box.right and p.cy>=box.y and p.cy<=box.bottom
   local mark=accent[cp]and p.cx>=box.x-20 and p.cx<=box.right+20 and p.cy>=box.y-85 and p.cy<box.y+8
   if interior or mark then assert(not assigned[p.id]or assigned[p.id]==cp,'Ambiguous illustrated accent: '..utf8.char(cp));assigned[p.id]=cp
    box.x=math.min(box.x,p.x);box.y=math.min(box.y,p.y);box.right=math.max(box.right,p.right);box.bottom=math.max(box.bottom,p.bottom)
   end
  end end
  box.w=box.right-box.x+1;box.h=box.bottom-box.y+1;box.right=nil;box.bottom=nil
 end
 local selected={};local mask=love.image.newImageData(w,h)
 for index,id in pairs(labels)do local cp=assigned[id];if cp then selected[index]=cp;local x,y=(index-1)%w,math.floor((index-1)/w);mask:setPixel(x,y,(cp%256)/255,math.floor(cp/256)/255,0,1)end end
 for _,p in ipairs(parts)do assert(p.count<12 or assigned[p.id],'Unassigned illustrated island at '..p.x..','..p.y..' ('..p.count..' px)')end
 write(root..'/'..map[codes[1]].maskFile,mask:encode('png'):getString());mask:release();return selected
end
local function sources(root)
 local map,images,selectors={},{},{}
 for _,def in ipairs(sourceDefs)do
  local data=love.image.newImageData(fileData(root..'/'..def.file));images[def.file]=data
  local w,h=data:getDimensions();local codes={};for _,cp in utf8.codes(def.chars)do codes[#codes+1]=cp end
  local rows=math.ceil(#codes/def.cols);local bands=def.bands or {};if not def.bands then for row=0,rows do bands[row+1]=math.floor(row*h/rows)end end
  assert(bands[#bands]==h,'Unexpected source sheet dimensions: '..def.file)
  if def.kind=='letter'then selectors[def.file]=letterSources(root,def,data,map)else
  for row=1,rows do local t,b=bands[row],bands[row+1]-1;local cuts=columnCuts(data,def.cols,t,b)
   for col=1,def.cols do local cp=codes[(row-1)*def.cols+col];if cp then
    local l,r=cuts[col],cuts[col+1]-1;local top,bottom=rowCut(data,l,r,t),rowCut(data,l,r,b+1)-1;local box=crop(data,l,top,r,bottom)
    assert(box.x>l and box.x+box.w<r+1,'Glyph reaches a column gutter: '..utf8.char(cp))
    assert(box.y>top and box.y+box.h<bottom+1,'Glyph reaches a row gutter: '..utf8.char(cp))
    box.file=def.file;box.kind=def.kind;box.baseline=def.baselines and def.baselines[row]or nil;map[cp]=box
   end end
  end
  end
 end
 -- Use precisely the same calibrated numeral crops as the live HUD.
 local nativeData=love.image.newImageData
 love.image.newImageData=function(path,...)if type(path)=='string'then return nativeData(fileData(root..'/'..path))end;return nativeData(path,...)end
 local N=assert(loadstring(read(root..'/src/ui/fonts/painted_numbers.lua')))();N.init();love.image.newImageData=nativeData
 local numberFile='assets/art/numerals-v11.png';images[numberFile]=love.image.newImageData(fileData(root..'/'..numberFile))
 for char,g in pairs(N.glyphs)do local x,y,w,h=g.q:getViewport();map[string.byte(char)]={file=numberFile,x=x,y=y,w=w,h=h,kind='numeral'}end
 map[0x2212]=map[45]
 return map,images,selectors
end
local puncHeight={['.']=.18,[',']=.30,[':']=.62,[';']=.76,['!']=1,['?']=1,['+']=.70,['-']=.15,['−']=.15,['(']=1.1,[')']=1.1,['[']=1.1,[']']=1.1,['°']=.35,['∞']=.65,['=']=.42,['×']=.65}
local function geometry(cp,src,cap,baseline)
 local scale,dy
 if src.kind=='letter'then scale=cap/174;dy=math.floor(baseline+(src.y-src.baseline)*scale+.5)
 else
  local char=utf8.char(cp);local relative=puncHeight[char]or 1;scale=cap*relative/src.h
  local height=src.h*scale
  if char==',' or char==';'then dy=math.floor(baseline-height*.68+.5)
  elseif char=='.'then dy=math.floor(baseline-height+.5)
  elseif char=='°'then dy=math.floor(baseline-cap+.5)
  elseif char=='+'or char=='-'or char=='−'or char=='∞'or char=='='or char=='×'or char==':'then dy=math.floor(baseline-cap*.48-height*.5+.5)
  else dy=math.floor(baseline-height+.5)end
 end
 return math.max(1,math.floor(src.w*scale+.5)),math.max(1,math.floor(src.h*scale+.5)),dy
end
local function sampledPixel(image,selector,src,x,y,dw,dh,size)
 local left,top=src.x+x*src.w/dw,src.y+y*src.h/dh
 local right,bottom=src.x+(x+1)*src.w/dw,src.y+(y+1)*src.h/dh
 local red,green,blue,covered=0,0,0,0;local iw=image:getWidth()
 for sy=math.floor(top),math.ceil(bottom)-1 do for sx=math.floor(left),math.ceil(right)-1 do
  local r,g,b,a=image:getPixel(sx,sy)
  if a>.55 and(not src.selector or selector[sy*iw+sx+1]==src.selector)then
   local weight=(math.min(right,sx+1)-math.max(left,sx))*(math.min(bottom,sy+1)-math.max(top,sy))
   covered=covered+weight;red=red+r*weight;green=green+g*weight;blue=blue+b*weight
  end
 end end
 if covered/((right-left)*(bottom-top))>.23 then
  -- In a tiny bitmap the source's black painted contour would swallow the bone
  -- core. Lift that same silhouette toward ivory pigment; preserve its warm cuts.
  local pigment=size<=24 and .70 or .35;local keep=1-pigment
  return red/covered*keep+.94*pigment,green/covered*keep+.89*pigment,blue/covered*keep+.77*pigment,1
 end
 return 0,0,0,0
end
local function bake(root,layout,map,images,selectors)
 local out=root..'/assets/fonts/painted';local catalog={version=2,source='Individually illustrated manuscript glyph sheets; no font outlines',sampler='source alpha > .55; area-weighted RGB; coverage > .23; ivory blend .70 <=24 / .35 >24',sourceMap='assets/fonts/painted/source-map.lua',sizes={}}
 local codes=sorted(map)
 for _,size in ipairs(sizes)do
  local old=layout.sizes[size];local cap=math.max(7,old.glyphs[72].h-(size<=24 and 1 or 3));local baseline=old.glyphs[72].dy+old.glyphs[72].h-2
  local cw,ch=math.ceil(cap*1.8)+12,old.height*2+16;local cols=16;local rows=math.ceil(#codes/cols)
  local atlas=love.image.newImageData(cw*cols,ch*rows);local meta={image='assets/fonts/painted/sigil-'..size..'.png',height=old.height,top=old.top,tracking=0,glyphs={},kern={}}
  for i,cp in ipairs(codes)do local src=map[cp];local dw,dh,dy=geometry(cp,src,cap,baseline);assert(dw<cw-4 and dh<ch-4,'Glyph exceeds packing cell')
   local ox,oy=(i-1)%cols*cw+4,math.floor((i-1)/cols)*ch+4;local minx,miny,maxx,maxy=dw,dh,-1,-1;local image=images[src.file]
   -- Area coverage retains punctuation and detached Polish accents at tiny sizes.
   for y=0,dh-1 do for x=0,dw-1 do local r,g,b,a=sampledPixel(image,selectors[src.file],src,x,y,dw,dh,size)
    if a>0 then atlas:setPixel(ox+x,oy+y,r,g,b,1);minx=math.min(minx,x);miny=math.min(miny,y);maxx=math.max(maxx,x);maxy=math.max(maxy,y)end
   end end
   assert(maxx>=minx,'Illustrated glyph lost at '..size..': '..utf8.char(cp)..' source '..serialize(src)..' sample '..dw..'x'..dh)
   meta.glyphs[cp]={advance=dw+1,x=ox+minx,y=oy+miny,w=maxx-minx+1,h=maxy-miny+1,dx=minx,dy=dy+miny,sourceCp=cp,sampleW=dw,sampleH=dh,trimX=minx,trimY=miny}
  end
  local space=math.max(4,math.ceil(cap*.38))
  meta.glyphs[32]={advance=space};meta.glyphs[160]={advance=space}
  write(out..'/sigil-'..size..'.png',atlas:encode('png'):getString());atlas:release();catalog.sizes[size]=meta
 end
 write(out..'/source-map.lua','-- Exact inspected source crop for every illustrated Unicode glyph.\nreturn '..serialize(map)..'\n')
 write(out..'/catalog.lua','return '..serialize(catalog)..'\n')
 for _,image in pairs(images)do image:release()end
 print('Imported '..#codes..' illustrated glyphs into '..#sizes..' PNG alphabets; no TTF/Font API used.')
end
function love.load(args)
 local ok,err=xpcall(function()
  local root=assert(os.getenv('SIGIL_FONT_SOURCE'),'Set SIGIL_FONT_SOURCE to game directory')
  local metrics=root..'/tools/bake_ui_font/layout_metrics.lua';local exists=io.open(metrics,'rb');if exists then exists:close()else capture(root,metrics)end
  if args and args[1]=='--capture-metrics'then print('Preserved line-height and baseline geometry.');return end
  local layout=assert(loadstring(read(metrics)))();local map,images,selectors=sources(root);bake(root,layout,map,images,selectors)
 end,debug.traceback)
 if not ok then print(err)end;love.event.quit(ok and 0 or 1)
end
