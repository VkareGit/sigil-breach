-- Pack the six HUD expressions into the portrait atlas layout used by
-- src/ui/portrait.lua: 3 columns x 2 rows of 512 px cells, order
-- 1 idle, 2 glance left, 3 glance right / 4 hurt, 5 critical, 6 firing.
-- Downscaling is area-averaged (box filter) so the painted contour stays crisp.
local sources={
 'work/gen/codex/portrait-frontal-3.png','work/gen/codex/expr-2-glance-left.png','work/gen/codex/expr-3-glance-right.png',
 'work/gen/codex/expr-4-hurt.png','work/gen/codex/expr-5-critical.png','work/gen/codex/expr-6-firing.png'}
local CELL=512
-- The HUD arch shows roughly rows 18%..86% of a cell. Crop the source to a
-- centred 80% window starting 8% from the top, so the face fills the arch
-- (eyes ~39%, chin ~80% of the cell) the way Doom's face fills its box.
local CROP_X,CROP_Y,CROP_S=.10,.08,.80
local function read(path)local f=assert(io.open(path,'rb'),path);local v=f:read('*a');f:close();return v end
function love.load(args)
 local ok,err=xpcall(function()
  local root=assert(args[1],'project root')
  local out=args[2] or (root..'/game/assets/art/nosiciel-v11.png')
  local atlas=love.image.newImageData(CELL*3,CELL*2)
  for i,rel in ipairs(sources)do
   local src=love.image.newImageData(love.filesystem.newFileData(read(root..'/'..rel),'src.png'))
   local sw,sh=src:getDimensions();local ox,oy=((i-1)%3)*CELL,math.floor((i-1)/3)*CELL
   for y=0,CELL-1 do for x=0,CELL-1 do
    local cw,ch=sw*CROP_S,sh*CROP_S;local cx,cy=sw*CROP_X,sh*CROP_Y
    local x0,x1=cx+x*cw/CELL,cx+(x+1)*cw/CELL;local y0,y1=cy+y*ch/CELL,cy+(y+1)*ch/CELL
    local r,g,b,n=0,0,0,0
    for sy=math.floor(y0),math.ceil(y1)-1 do for sx=math.floor(x0),math.ceil(x1)-1 do
     local pr,pg,pb=src:getPixel(math.min(sw-1,sx),math.min(sh-1,sy));r=r+pr;g=g+pg;b=b+pb;n=n+1
    end end
    atlas:setPixel(ox+x,oy+y,r/n,g/n,b/n,1)
   end end
   src:release()
  end
  local f=assert(io.open(out,'wb'));f:write(atlas:encode('png'):getString());f:close()
  print('wrote '..out)
 end,debug.traceback)
 if not ok then print(err)end;love.event.quit(ok and 0 or 1)
end
