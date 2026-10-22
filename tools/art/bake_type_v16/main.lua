-- Technical atlas importer: selects and samples illustrated source pixels only.
-- No font API, outline generation, dilation or replacement shapes.
local utf8=require('utf8')
local sizes={11,12,13,14,16,18,20,22,24,28,36,42,48,64,94}
local function read(p)local f=assert(io.open(p,'rb'));local s=f:read('*a');f:close();return s end
local function write(p,s)local f=assert(io.open(p,'wb'));f:write(s);f:close()end
local function keys(t)local a={};for k in pairs(t)do a[#a+1]=k end;table.sort(a);return a end
local function serial(v)
 if type(v)=='string'then return string.format('%q',v)end
 if type(v)~='table'then return tostring(v)end
 local a={'{'};for _,k in ipairs(keys(v))do a[#a+1]='['..serial(k)..']='..serial(v[k])..','end
 a[#a+1]='}';return table.concat(a)
end
local function crop(d,l,t,r,b)
 local x0,y0,x1,y1=r,b,l-1,t-1
 for y=t,b do for x=l,r do local _,_,_,a=d:getPixel(x,y)
  if a>.55 then x0=math.min(x0,x);y0=math.min(y0,y);x1=math.max(x1,x);y1=math.max(y1,y)end
 end end
 assert(x1>=x0,'Empty illustrated cell at '..l..','..t)
 return {x=x0,y=y0,w=x1-x0+1,h=y1-y0+1}
end
local function run(root)
 local old=assert(loadstring(read(root..'/assets/fonts/painted/catalog.lua')))()
 local original=assert(loadstring(read(root..'/assets/fonts/painted/source-map.lua')))()
 local map,images={},{}
 local function image(path)
  if not images[path]then images[path]=love.image.newImageData(love.filesystem.newFileData(read(root..'/'..path),path))end
  return images[path]
 end
 local sheets={
  {file='assets/art/alphabet-upper-v16.png',chars='ABCDEFGHIJKLMNOPQRSTUVWXYZĄĆĘŁŃÓŚŹŻ',
   bands={0,240,460,675,888,1080,1300,1536},baselines={214,423,636,845,1058,1267,1485},unit=151},
  {file='assets/art/alphabet-lower-v16.png',chars='abcdefghijklmnopqrstuvwxyząćęłńóśźż',
   bands={0,275,525,735,965,1148,1338,1536},baselines={250,469,694,888,1100,1295,1495},unit=174},
 }
 for _,def in ipairs(sheets)do
  local d=image(def.file);local iw,ih=d:getDimensions();assert(iw==1024 and ih==1536,'Unexpected generated sheet size')
  local index=0
  for _,cp in utf8.codes(def.chars)do index=index+1;local col=(index-1)%5;local row=math.floor((index-1)/5)+1
   local box=crop(d,math.floor(col*iw/5),def.bands[row],math.floor((col+1)*iw/5)-1,def.bands[row+1]-1)
   box.file=def.file;box.kind='letter';box.baseline=def.baselines[row];box.unit=def.unit
   box.selection='inspected isolated cell';map[cp]=box
  end
 end
 local numeralFile='assets/art/numerals-v16.png';local numbers=image(numeralFile)
 local numberCuts={{0,281,481,741,981,1251,1536},{0,277,489,736,974,1233,1401}}
 local order='0123456789%/';local numberMap={}
 for i=1,#order do local col=(i-1)%6;local row=math.floor((i-1)/6)
  -- Last source cell contains an unrequested detached dot. This crop selects
  -- the slash artwork itself; no glyph is redrawn or background synthesized.
  local l,r=numberCuts[row+1][col+1],numberCuts[row+1][col+2]-1
  local b=crop(numbers,l,row*512,r,(row+1)*512-1)
  b.file=numeralFile;b.kind='numeral';map[order:byte(i)]=b;numberMap[order:sub(i,i)]=b
 end
 -- Existing illustrated punctuation remains compatible; lowercase and both
 -- Polish alphabets above are new, not a system-font fallback.
 for cp,b in pairs(original)do if not map[cp]then map[cp]=b;image(b.file)end end
 map[0x2212]=map[45]
 local punc={['.']=.18,[',']=.30,[':']=.62,[';']=.76,['!']=1,['?']=1,['+']=.70,['-']=.15,['−']=.15,['(']=1.1,[')']=1.1,['[']=1.1,[']']=1.1,['°']=.35,['∞']=.65,['=']=.42,['×']=.65}
 local function geometry(cp,b,cap,baseline)
  local scale,dy
  if b.kind=='letter'then scale=cap/b.unit;dy=math.floor(baseline+(b.y-b.baseline)*scale+.5)
  else
   local c=utf8.char(cp);local height=cap*(punc[c]or 1);scale=height/b.h
   if c==','or c==';'then dy=math.floor(baseline-height*.68+.5)
   elseif c=='.'then dy=math.floor(baseline-height+.5)
   elseif c=='°'then dy=math.floor(baseline-cap+.5)
   elseif c=='+'or c=='-'or c=='−'or c=='∞'or c=='='or c=='×'or c==':'then dy=math.floor(baseline-cap*.48-height*.5+.5)
   else dy=math.floor(baseline-height+.5)end
  end
  return math.max(1,math.floor(b.w*scale+.5)),math.max(1,math.floor(b.h*scale+.5)),dy
 end
 local function pixel(d,b,x,y,dw,dh)
  local l,t=b.x+x*b.w/dw,b.y+y*b.h/dh
  local r,bt=b.x+(x+1)*b.w/dw,b.y+(y+1)*b.h/dh
  local rr,gg,bb,cover=0,0,0,0
  for sy=math.floor(t),math.ceil(bt)-1 do for sx=math.floor(l),math.ceil(r)-1 do
   local red,green,blue,a=d:getPixel(sx,sy)
   if a>.55 then local wt=(math.min(r,sx+1)-math.max(l,sx))*(math.min(bt,sy+1)-math.max(t,sy))
    rr=rr+red*wt;gg=gg+green*wt;bb=bb+blue*wt;cover=cover+wt
   end
  end end
  if cover/((r-l)*(bt-t))>.23 then
   -- Pigment normalization keeps old punctuation consistent with new ink.
   return rr/cover*.75+.94*.25,gg/cover*.75+.89*.25,bb/cover*.75+.77*.25,1
  end
  return 0,0,0,0
 end
 local codes=keys(map);local out='assets/fonts/painted-v16'
 local catalog={version=16,source='Generated pale ivory fresco capitals, lowercase and numerals, with preserved illustrated punctuation',
  sourceMap=out..'/source-map.lua',coverage=.23,sourceAlpha=.55,sizes={}}
 for _,size in ipairs(sizes)do
  local legacy=old.sizes[size];local cap=legacy.glyphs[72].h;local baseline=legacy.top+cap
  local cw,ch=math.ceil(cap*1.9)+12,legacy.height*2+16;local cols=16
  local atlas=love.image.newImageData(cw*cols,ch*math.ceil(#codes/cols))
  local meta={image=out..'/sigil-'..size..'.png',sourceMap=catalog.sourceMap,height=legacy.height,top=legacy.top,tracking=0,kern={},glyphs={},version=16}
  for i,cp in ipairs(codes)do
   local b=map[cp];local dw,dh,dy=geometry(cp,b,cap,baseline);local d=image(b.file)
   assert(dw<cw-4 and dh<ch-4,'Packing overflow '..cp)
   local ox,oy=(i-1)%cols*cw+4,math.floor((i-1)/cols)*ch+4
   local x0,y0,x1,y1=dw,dh,-1,-1
   for y=0,dh-1 do for x=0,dw-1 do local r,g,bl,a=pixel(d,b,x,y,dw,dh)
    if a>0 then atlas:setPixel(ox+x,oy+y,r,g,bl,a);x0=math.min(x0,x);y0=math.min(y0,y);x1=math.max(x1,x);y1=math.max(y1,y)end
   end end
   assert(x1>=x0,'Lost source glyph '..cp)
   local advance=dw+math.max(1,math.floor(cap*.055+.5))
   meta.glyphs[cp]={x=ox+x0,y=oy+y0,w=x1-x0+1,h=y1-y0+1,dx=x0,dy=dy+y0,advance=advance,sourceCp=cp,sampleW=dw,sampleH=dh,trimX=x0,trimY=y0}
  end
  local space=math.max(4,math.ceil(cap*.40))
  meta.glyphs[32]={advance=space};meta.glyphs[160]={advance=space}
  write(root..'/'..meta.image,atlas:encode('png'):getString());atlas:release();catalog.sizes[size]=meta
 end
 write(root..'/'..out..'/catalog.lua','return '..serial(catalog)..'\n')
 write(root..'/'..out..'/source-map.lua','-- Inspected original source crops; no substituted outlines.\nreturn '..serial(map)..'\n')
 write(root..'/'..out..'/numerals.lua','return '..serial({image=numeralFile,glyphs=numberMap})..'\n')
 -- Literal title images are assembled from the same illustrated capitals,
 -- preserving the alphabet's shapes, not drawing a different digital font.
 local headings={sigil='SIGIL',breach='BREACH',limbo='LIMBO',merchant='MERCHANT',circles='CIRCLES',settings='SETTINGS',new_run='NEW RUN',interrupted='INTERRUPTED'}
 local names={'sigil','breach','limbo','merchant','circles','settings','new_run','interrupted'}
 local atlas=love.image.newImageData(2048,1024);local entries={}
 for index,name in ipairs(names)do
  local ox=((index-1)%2)*1024+24;local oy=math.floor((index-1)/2)*256+42
  local px=ox;local minY,maxY=1024,0
  local rawWidth=0
  for _,cp in utf8.codes(headings[name])do rawWidth=rawWidth+(cp==32 and 61 or map[cp].w+10)end
  local scale=math.min(.76,950/rawWidth)
  for _,cp in utf8.codes(headings[name])do
   if cp==32 then px=px+math.floor(61*scale+.5) else
    local b=map[cp];local d=image(b.file)
    local dw,dh=math.floor(b.w*scale+.5),math.floor(b.h*scale+.5)
    local dy=math.floor((b.y-b.baseline+151)*scale+.5)
    for y=0,dh-1 do for x=0,dw-1 do local r,g,bl,a=pixel(d,b,x,y,dw,dh)
     if a>0 then atlas:setPixel(px+x,oy+dy+y,r,g,bl,a);minY=math.min(minY,oy+dy+y);maxY=math.max(maxY,oy+dy+y)end
    end end
    px=px+dw+7
   end
  end
  assert(px-ox<976,'Title exceeds cell: '..name)
  entries[name]={x=ox,y=minY,w=px-ox-7,h=maxY-minY+1,text=headings[name]}
 end
 local titleImage='assets/art/lettering-en-v16.png'
 write(root..'/'..titleImage,atlas:encode('png'):getString());atlas:release()
 write(root..'/'..out..'/titles.lua','return '..serial({image=titleImage,entries=entries})..'\n')
 for _,d in pairs(images)do d:release()end
 print('Baked '..#codes..' illustrated glyphs x '..#sizes..' sizes; 8 literal headings; 12 numeral crops.')
end
function love.load()
 local ok,err=xpcall(function()run(assert(os.getenv('SIGIL_FONT_SOURCE')))end,debug.traceback)
 if not ok then print(err)end;love.event.quit(ok and 0 or 1)
end
