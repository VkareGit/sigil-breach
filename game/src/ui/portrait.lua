local Characters = require('src.content.characters')
local Context = require('src.session.context')
-- A mortal soldier behind a closed visor. Six authored changes of bearing
-- retain the portrait's reactions without inventing supernatural eyes.
-- The bust sits inside the painted arch, including the helmet's crown.
local PortraitLook = require('src.content.hud_look').portrait
local P = { bounds = PortraitLook.bounds, path = PortraitLook.path }
local Resources = require('src.render.resources')
function P.init(checkpoint)
  if P.image then
    return P
  end
  P.resources = Resources.new('UI knight portrait')
  P.image = P.resources:image(P.path, { filter = 'linear' })
  P.quads = {}
  local w, h = P.image:getDimensions()
  for i = 0, 5 do
    P.quads[i + 1] = P.resources:own(
      love.graphics.newQuad(i % 3 * w / 3, math.floor(i / 3) * h / 2, w / 3, h / 2, w, h)
    )
  end
  -- The shader's arch is drawn in the same frame pixels as the bounds.
  P.shader = P.resources:own(love.graphics.newShader([[
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
 ]]))
  if checkpoint then
    checkpoint('knight portrait')
  end
end
function P.release()
  if P.resources then
    P.resources:release()
  end
  P.resources, P.image, P.quads, P.shader = nil, nil, nil, nil
end
function P.frame(g)
  if Characters.low(Context.actor(g)) then
    return 5
  end
  if g.view.hurt > PortraitLook.hurt then
    return 4
  end
  if g.view.shotAge < PortraitLook.shot then
    return 6
  end
  local glance = math.floor(g.time * PortraitLook.glance) % 7
  return glance == PortraitLook.right and 2 or (glance == PortraitLook.left and 3 or 1)
end
function P.draw(g, x, y, size)
  local q = P.quads[P.frame(g)]
  local qx, qy, w, h = q:getViewport()
  local iw, ih = P.image:getDimensions()
  -- The old face filled the frame up to its hairline. A helmet needs space
  -- above its dome; keep its silhouette below the arch without shrinking HUD.
  x = x + size * PortraitLook.inset.x
  y = y + size * PortraitLook.inset.y
  size = size * PortraitLook.inset.size
  local previous = love.graphics.getShader()
  P.shader:send('frameRect', { qx / iw, qy / ih, w / iw, h / ih })
  P.shader:send('placement', { x, y, size })
  love.graphics.setShader(P.shader)
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(P.image, q, x, y, 0, size / w, size / h)
  love.graphics.setShader(previous)
end
return P
