-- Prepare a generated sprite sheet for the game:
--  1. key out the flat magenta (#FF00FF) background to true alpha, with a
--     despill so the inked edge does not keep a pink fringe;
--  2. optionally resize to exact target dimensions (area average);
--  3. report the empty row gutters inside each grid column, so loaders with
--     measured row bands (weapon.lua) can be updated to the new sheet.
-- Usage: lovec sheet_prep <in.png> <out.png> <cols> <rows> [width height]
local function read(path)local f=assert(io.open(path,'rb'),path);local v=f:read('*a');f:close();return v end
local function magentaness(r,g,b)
 -- 1 for pure magenta, 0 for anything without a strong magenta cast.
 local m=math.min(r,b)-g
 return math.max(0,math.min(1,(m-.18)/.35))
end
local function key(src)
 local w,h=src:getDimensions();local out=love.image.newImageData(w,h)
 for y=0,h-1 do for x=0,w-1 do
  local r,g,b=src:getPixel(x,y);local k=magentaness(r,g,b)
  if k>=.98 then out:setPixel(x,y,0,0,0,0)
  else
   local a=1-k
   -- Despill: remove the magenta that was mixed into this edge pixel.
   if k>0 then local s=math.min(r,b)-g;local cut=s*k
    r=math.max(0,(r-cut)/a);b=math.max(0,(b-cut)/a);g=g/a
    r,g,b=math.min(1,r),math.min(1,g),math.min(1,b)end
   out:setPixel(x,y,r,g,b,a)
  end
 end end
 return out
end
local function resize(src,tw,th)
 local sw,sh=src:getDimensions();if sw==tw and sh==th then return src end
 local out=love.image.newImageData(tw,th)
 for y=0,th-1 do for x=0,tw-1 do
  local x0,x1,y0,y1=x*sw/tw,(x+1)*sw/tw,y*sh/th,(y+1)*sh/th
  local r,g,b,a,n=0,0,0,0,0
  for sy=math.floor(y0),math.ceil(y1)-1 do for sx=math.floor(x0),math.ceil(x1)-1 do
   local pr,pg,pb,pa=src:getPixel(math.min(sw-1,sx),math.min(sh-1,sy));r=r+pr*pa;g=g+pg*pa;b=b+pb*pa;a=a+pa;n=n+1
  end end
  if a>0 then out:setPixel(x,y,r/a,g/a,b/a,a/n)else out:setPixel(x,y,0,0,0,0)end
 end end
 return out
end
local function gutters(img,cols,rows)
 local w,h=img:getDimensions();local lines={}
 for c=0,cols-1 do
  local l,r=math.ceil(c*w/cols),math.ceil((c+1)*w/cols)-1;local cuts={0}
  for k=1,rows-1 do
   local guess=math.floor(k*h/rows);local best,dist
   for y=math.max(0,guess-math.floor(h/rows*.45)),math.min(h-1,guess+math.floor(h/rows*.45))do
    local clear=true;for x=l,r do local _,_,_,a=img:getPixel(x,y);if a>.06 then clear=false;break end end
    if clear then local d=math.abs(y-guess);if not dist or d<dist then best,dist=y,d end end
   end
   cuts[#cuts+1]=best or -1
  end
  cuts[#cuts+1]=h;lines[#lines+1]='column '..c..' cuts {'..table.concat(cuts,',')..'}'
  -- Also report whether any opaque pixel touches the column borders.
  local touch=0;for y=0,h-1 do for _,x in ipairs({l,r})do local _,_,_,a=img:getPixel(x,y);if a>.5 then touch=touch+1 end end end
  lines[#lines]=lines[#lines]..' border-touch '..touch
 end
 return lines
end
-- Give every connected shape to the grid cell holding its centroid, then erase
-- the parts of it that cross into a neighbouring cell's row band. Generated
-- sheets sometimes let a smoke puff overlap the next row's bolt tip; without
-- this, a row cut through both would show a sliver of the neighbour.
local function isolate(img,cols,rows,bands)
 local w,h=img:getDimensions();local label={};local comps={}
 local function opaque(x,y)local _,_,_,a=img:getPixel(x,y);return a>.5 end
 for y=0,h-1 do for x=0,w-1 do local i=y*w+x
  if not label[i] and opaque(x,y)then
   local id=#comps+1;local stack={i};label[i]=id;local sx,sy,n,pix=0,0,0,{}
   while #stack>0 do local j=table.remove(stack);local px,py=j%w,math.floor(j/w)
    sx,sy,n=sx+px,sy+py,n+1;pix[#pix+1]=j
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do local qx,qy=px+d[1],py+d[2]
     if qx>=0 and qx<w and qy>=0 and qy<h then local q=qy*w+qx
      if not label[q] and opaque(qx,qy)then label[q]=id;stack[#stack+1]=q end end end
   end
   comps[id]={cx=sx/n,cy=sy/n,pix=pix}
  end
 end end
 local removed=0
 for _,c in ipairs(comps)do
  local col=math.min(cols-1,math.floor(c.cx/(w/cols)));local cuts=bands[col+1]
  local row=rows-1;for r=1,rows do if c.cy<cuts[r+1]then row=r-1;break end end
  local top,bottom=cuts[row+1],cuts[row+2]
  for _,j in ipairs(c.pix)do local py=math.floor(j/w)
   if py<top or py>=bottom then img:setPixel(j%w,py,0,0,0,0);removed=removed+1 end end
 end
 return removed
end
local function parseCuts(line)local t={};for v in line:match('{(.-)}'):gmatch('-?%d+')do t[#t+1]=tonumber(v)end;return t end
function love.load(args)
 local ok,err=xpcall(function()
  local inp,outp,cols,rows=args[1],args[2],tonumber(args[3]),tonumber(args[4])
  local src=love.image.newImageData(love.filesystem.newFileData(read(inp),'in.png'))
  local img=key(src)
  if args[5] then img=resize(img,tonumber(args[5]),tonumber(args[6]))end
  -- Hard alpha: the game samples nearest and draws these sprites opaque, so a
  -- half-transparent edge pixel would show its keyed fringe colour at full
  -- strength. Below half coverage is cut; the rest becomes fully opaque.
  img:mapPixel(function(_,_,r,g,b,a)if a<.5 then return 0,0,0,0 end;return r,g,b,1 end)
  -- Row bands per column: measured gutters, or the equal-grid line where a
  -- column has no clear gutter; then trim shapes to their own band.
  local bands={};local h=img:getHeight()
  for c,line in ipairs(gutters(img,cols,rows))do local cuts=parseCuts(line)
   for k=2,#cuts-1 do if cuts[k]<0 then cuts[k]=math.floor((k-1)*h/rows)end end;bands[c]=cuts end
  local removed=isolate(img,cols,rows,bands)
  local f=assert(io.open(outp,'wb'));f:write(img:encode('png'):getString());f:close()
  print('wrote '..outp..' '..img:getWidth()..'x'..img:getHeight()..' (trimmed '..removed..' px across bands)')
  for _,l in ipairs(gutters(img,cols,rows))do print(l)end
 end,debug.traceback)
 if not ok then print(err)end;love.event.quit(ok and 0 or 1)
end
