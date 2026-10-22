-- A mortal soldier behind a closed visor. Six authored changes of bearing
-- retain the portrait's reactions without inventing supernatural eyes.
-- The bust sits inside the painted arch, including the helmet's crown.
local P =
  { bounds = { x = 570, y = 602, w = 140, h = 105 }, path = 'assets/art/nosiciel-iron-v16.png' }
function P.init()
  P.image = love.graphics.newImage(P.path)
  P.image:setFilter('linear', 'linear')
  P.quads = {}
  local w, h = P.image:getDimensions()
  for i = 0, 5 do
    P.quads[i + 1] =
      love.graphics.newQuad(i % 3 * w / 3, math.floor(i / 3) * h / 2, w / 3, h / 2, w, h)
  end
  P.shader = love.graphics.newShader([[
 extern vec4 frameRect;
 extern vec3 placement;
 vec4 effect(vec4 color,Image tex,vec2 uv,vec2 screen){
  vec2 q=(uv-frameRect.xy)/frameRect.zw;
  vec2 pos=placement.xy+q*placement.z;
  float side=abs(pos.x-640.0);
  float roof=602.0+22.0*pow(clamp(side/70.0,0.0,1.0),2.0);
  // The pigment thins into the underlying lime, so the square atlas cell
  // cannot leave a pasted rectangular edge inside the authored arch.
  float arch=smoothstep(roof,roof+4.0,pos.y)*(1.0-smoothstep(62.0,70.0,side));
  arch*=1.0-smoothstep(699.0,707.0,pos.y);
  vec4 p=Texel(tex,uv);
  return vec4(p.rgb,p.a*arch)*color;
 }
 ]])
end
function P.frame(g)
  if g.player.hp < 30 then
    return 5
  end
  if g.view.hurt > 0.25 then
    return 4
  end
  if g.view.shotAge < 0.16 then
    return 6
  end
  local glance = math.floor(g.time * 0.65) % 7
  return glance == 3 and 2 or (glance == 5 and 3 or 1)
end
function P.draw(g, x, y, size)
  local q = P.quads[P.frame(g)]
  local qx, qy, w, h = q:getViewport()
  local iw, ih = P.image:getDimensions()
  -- The old face filled the frame up to its hairline. A helmet needs space
  -- above its dome; keep its silhouette below the arch without shrinking HUD.
  x = x + size * 0.045
  y = y + size * 0.08
  size = size * 0.91
  local previous = love.graphics.getShader()
  P.shader:send('frameRect', { qx / iw, qy / ih, w / iw, h / ih })
  P.shader:send('placement', { x, y, size })
  love.graphics.setShader(P.shader)
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(P.image, q, x, y, 0, size / w, size / h)
  love.graphics.setShader(previous)
end
return P
