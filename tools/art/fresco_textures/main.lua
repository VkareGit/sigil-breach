-- Paint the arena's surface atlas the way a fresco painter paints architecture:
-- one flat tone per stone, a lime-white edge on the lit (upper/left) side, a
-- sinopia line in the joint and the shadow side, a broad mottle at stone scale
-- and nothing finer. Readability through big calm planes, not stipple.
-- Output: assets/art/textures-v11.png, 2x2 tiles of 128 texels (the renderer
-- samples each tile on a 128-texel grid): (0,0) stone wall, (1,0) dark iron
-- door, (0,1) painted frieze, (1,1) floor slabs. Deterministic, no AI step.
local N=128
local function hash(x,y,s)local v=math.sin(x*127.1+y*311.7+(s or 0)*74.7)*43758.5453;return v-math.floor(v)end
local function vnoise(x,y,s)
 local ix,iy=math.floor(x),math.floor(y);local fx,fy=x-ix,y-iy;fx=fx*fx*(3-2*fx);fy=fy*fy*(3-2*fy)
 local a,b,c,d=hash(ix,iy,s),hash(ix+1,iy,s),hash(ix,iy+1,s),hash(ix+1,iy+1,s)
 return a+(b-a)*fx+(c-a)*fy+(a-b-c+d)*fx*fy
end
-- Periodic noise so every tile wraps seamlessly at 128 texels.
local function pnoise(x,y,period,s)
 local p=N/period;local ix,iy=math.floor(x/period),math.floor(y/period);local fx,fy=x/period-ix,y/period-iy
 fx=fx*fx*(3-2*fx);fy=fy*fy*(3-2*fy)
 local function h(i,j)return hash(i%p,j%p,s)end
 local a,b,c,d=h(ix,iy),h(ix+1,iy),h(ix,iy+1),h(ix+1,iy+1)
 return a+(b-a)*fx+(c-a)*fy+(a-b-c+d)*fx*fy
end
local function mix(a,b,t)return {a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t}end
local function mul(a,k)return {a[1]*k,a[2]*k,a[3]*k}end
local SINOPIA={.115,.068,.054};local LIME={.80,.77,.69};local SHADOW={.075,.058,.054}
-- Fresco pigments for stone, from the measured Inferno palette (slate and ochre greys).
local STONES={{.285,.288,.288},{.329,.290,.245},{.318,.330,.334},{.372,.335,.285},{.305,.293,.275},{.350,.318,.275}}
local FLOORS={{.205,.218,.226},{.265,.212,.168},{.235,.222,.205},{.215,.195,.172}}

-- Running-bond masonry: returns stone id and texel position inside its stone.
local function bond(x,y,rowH,widths,seed)
 local row=math.floor(y/rowH);local ly=y-row*rowH
 local offset=math.floor(hash(row,0,seed)*N)
 local xx=(x+offset)%N;local start=0;local i=0
 while true do i=i+1;local w=widths[(row+i)%#widths+1];if xx<start+w or start+w>=N then
  local w2=math.min(w,N-start);return row*16+i,xx-start,ly,w2,rowH end;start=start+w end
end
local function paintStone(x,y,palette,rowH,widths,seed,crackRate)
 local id,lx,ly,w,h=bond(x,y,rowH,widths,seed)
 local base=palette[math.floor(hash(id,7,seed)*#palette)+1]
 -- Gentle modelling: light from the upper left, one tone per stone.
 -- Brush: soft vertical strokes a few texels wide, low amplitude (paint, not grain).
 local brush=(pnoise(x,y*.25,4,seed+9)-.5)*.045
 local shade=1.06-.12*(ly/h)-.04*(lx/w)+(pnoise(x,y,32,seed)-.5)*.07+(hash(id,3,seed)-.5)*.08+brush
 local c=mul(base,shade)
 if ly<2 then c=mix(c,LIME,ly<1 and .38 or .20)end
 if lx<1 then c=mix(c,LIME,.22)end
 if ly>=h-2 then c=mix(c,SHADOW,.55)end
 if lx>=w-1 then c=mix(c,SHADOW,.40)end
 if ly==h-1 or lx==w-1 then c=SINOPIA end
 -- A rare single painted crack, drawn as one dark line, never as stipple.
 if hash(id,11,seed)<crackRate then
  local cx=math.floor(w*(.3+.4*hash(id,12,seed)));local slope=(hash(id,13,seed)-.5)*1.2
  local px=math.floor(cx+(ly-h*.2)*slope+.5)
  if ly>h*.2 and ly<h*.85 and lx==px then c=mix(c,SINOPIA,.85)end
 end
 return c
end
local function wall(x,y)return paintStone(x,y,STONES,32,{48,40,56,44,52},1,.30)end
local function floor(x,y)return paintStone(x,y,FLOORS,64,{64,48,56,72},2,.35)end
-- Painted frieze, as the bands framing fresco registers: sinopia ground,
-- red-ochre band with a lime-white zigzag, imitation marble in ochre greys.
local function frieze(x,y)
 local OCHRE={.47,.19,.11};local MARBLE={.43,.36,.27}
 if y<6 or (y>=58 and y<64) or y>=122 then return SINOPIA end
 if y<10 or (y>=54 and y<58) then return mix(LIME,SINOPIA,.45)end
 if y<54 then
  -- zigzag: triangles of lime white on red ochre, period 16 texels
  local t=(x%16)/16;local tri=math.abs(t-.5)*2;local yy=(y-10)/44
  local zig=math.abs(yy-tri)<.10
  local c=mul(OCHRE,1+(pnoise(x,y,32,5)-.5)*.10)
  if zig then c=mix(LIME,OCHRE,.55)end -- muted: a painted band, not a stripe pattern
  return c
 end
 -- imitation marble: broad soft veins, two tones only
 local v=math.sin((x*.09+y*.05)+pnoise(x,y,32,6)*5)
 local c=mul(MARBLE,.92+.10*pnoise(x,y,64,7))
 if math.abs(v)<.06 then c=mix(c,SINOPIA,.55)end
 return c
end
-- Iron door: dark umber leaves with painted pointed arches in dull ochre lines.
local function door(x,y)
 local GROUND={.105,.088,.080};local LINE={.40,.31,.20}
 local lx=x%64;local c=mul(GROUND,1+(pnoise(x,y,32,8)-.5)*.10)
 if lx<3 or lx>=61 or y<3 or y>=125 then return mix(GROUND,SHADOW,.5)end
 local cx=32;local dx=math.abs(lx-cx);local archTop=22;local springY=48
 local inside
 if y>=springY then inside=dx<20
 else local r=34;local d=math.sqrt((dx+14)^2+(y-springY)^2);inside=d<r and y>archTop end
 local edge
 if y>=springY then edge=math.abs(dx-20)<1 and y<110 else local d=math.sqrt((dx+14)^2+(y-springY)^2);edge=math.abs(d-34)<1 and y>archTop end
 if y==110 and dx<=20 then edge=true end
 if edge then return LINE end
 if inside then c=mul(c,.82)end
 -- rivets at the frame, painted as single lime dots
 if (lx==6 or lx==57) and y%16==8 then return mix(LIME,LINE,.5)end
 return c
end
function love.load()
 local ok,err=xpcall(function()
  local root=assert(os.getenv('SIGIL_FONT_SOURCE'),'Set SIGIL_FONT_SOURCE to game directory')
  local data=love.image.newImageData(2*N,2*N)
  local tiles={{0,0,wall},{1,0,door},{0,1,frieze},{1,1,floor}}
  for _,t in ipairs(tiles)do for y=0,N-1 do for x=0,N-1 do
   local c=t[3](x,y);data:setPixel(t[1]*N+x,t[2]*N+y,math.min(1,c[1]),math.min(1,c[2]),math.min(1,c[3]),1)
  end end end
  local f=assert(io.open(root..'/assets/art/textures-v11.png','wb'));f:write(data:encode('png'):getString());f:close()
  print('Painted assets/art/textures-v11.png '..(2*N)..'x'..(2*N))
 end,debug.traceback)
 if not ok then print(err)end;love.event.quit(ok and 0 or 1)
end
