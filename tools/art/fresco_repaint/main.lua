-- Repaint the illustrated v08 lettering as fresco lettering (Bolognini Chapel).
-- The SHAPE of every glyph is kept exactly: alpha is copied unchanged, so all
-- crops, component selectors, baselines and coverage tests stay valid. Only the
-- paint changes: the bevelled bone relief becomes flat lime white laid with a
-- brush, the black contour becomes sinopia, the red inlay becomes red ochre.
-- No font outlines, no new letterforms, no AI step.
local jobs={
 {'assets/art/alphabet-upper-v08.png','assets/art/alphabet-upper-v11.png'},
 {'assets/art/alphabet-lower-v08.png','assets/art/alphabet-lower-v11.png'},
 {'assets/art/alphabet-punctuation-v08.png','assets/art/alphabet-punctuation-v11.png'},
 {'assets/art/numerals-v08.png','assets/art/numerals-v11.png'},
 {'assets/art/lettering-v08.png','assets/art/lettering-v11.png'},
}
local function read(path)local f=assert(io.open(path,'rb'));local v=f:read('*a');f:close();return v end
local function write(path,v)local f=assert(io.open(path,'wb'));f:write(v);f:close()end
local function hash(x,y)local s=math.sin(x*127.1+y*311.7)*43758.5453;return s-math.floor(s)end
local function vnoise(x,y)
 local ix,iy=math.floor(x),math.floor(y);local fx,fy=x-ix,y-iy;fx=fx*fx*(3-2*fx);fy=fy*fy*(3-2*fy)
 local a,b=hash(ix,iy),hash(ix+1,iy);local c,d=hash(ix,iy+1),hash(ix+1,iy+1)
 return (a+(b-a)*fx)+((c+(d-c)*fx)-(a+(b-a)*fx))*fy
end
local function smooth(e0,e1,x)local t=math.max(0,math.min(1,(x-e0)/(e1-e0)));return t*t*(3-2*t)end
local function mix(a,b,t)return a+(b-a)*t end
local SINOPIA={.165,.072,.050};local LIME={.875,.842,.752};local OCHRE_DARK={.47,.165,.10};local OCHRE_LIGHT={.70,.31,.17}
local function paint(x,y,r,g,b,a)
 if a<=.01 then return r,g,b,a end
 local l=.30*r+.59*g+.11*b;local mx=math.max(r,g,b);local mn=math.min(r,g,b)
 local sat=mx>0 and (mx-mn)/mx or 0;local redness=mx>0 and (r-math.max(g,b))/mx or 0
 -- Brush: vertical strokes a few pixels wide, low amplitude, broad scale.
 local brush=(vnoise(x/3.5,y/16)-.5)*.07+(vnoise(x/22,y/22)-.5)*.05
 local cr,cg,cb
 if redness>.30 and sat>.35 and l>.10 then
  local t=smooth(.12,.45,l);cr,cg,cb=mix(OCHRE_DARK[1],OCHRE_LIGHT[1],t),mix(OCHRE_DARK[2],OCHRE_LIGHT[2],t),mix(OCHRE_DARK[3],OCHRE_LIGHT[3],t)
  local k=1+brush;cr,cg,cb=cr*k,cg*k,cb*k
 else
  -- Flatten the relief: keep only a little of the source value as painted form.
  local v=(.90+.12*smooth(.30,.85,l))*(1+brush)
  local br,bg,bb=LIME[1]*v,LIME[2]*v,LIME[3]*v
  local t=smooth(.18,.34,l)
  cr,cg,cb=mix(SINOPIA[1],br,t),mix(SINOPIA[2],bg,t),mix(SINOPIA[3],bb,t)
 end
 -- Faint halo pixels (below the import threshold) stay as a dark sinopia stain.
 if a<.55 then cr,cg,cb=SINOPIA[1],SINOPIA[2],SINOPIA[3] end
 return math.min(1,cr),math.min(1,cg),math.min(1,cb),a
end
function love.load()
 local ok,err=xpcall(function()
  local root=assert(os.getenv('SIGIL_FONT_SOURCE'),'Set SIGIL_FONT_SOURCE to game directory')
  for _,job in ipairs(jobs)do
   local data=love.image.newImageData(love.filesystem.newFileData(read(root..'/'..job[1]),'src.png'))
   data:mapPixel(paint)
   write(root..'/'..job[2],data:encode('png'):getString());print('repainted '..job[1]..' -> '..job[2]);data:release()
  end
 end,debug.traceback)
 if not ok then print(err)end;love.event.quit(ok and 0 or 1)
end
