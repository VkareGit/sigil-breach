-- Painted floor silhouettes follow the same pose/feet as the body.
-- This is a bounded 2.5D projection, not a full volumetric shadow map.
local Geometry = require('src.enemies.geometry')
local Ground = require('src.physics.ground')
local Pools = require('src.session.world')
local Grid = require('src.physics.grid')
local S = {}
local code = [[
extern vec3 camera,rightDir,upDir,forwardDir,objectPos;
extern number aspect,projectionScale,objectYaw,objectScale,lean,mirror,opacity,worldSize,groundHeight;
extern vec2 spriteStretch,away,shadowTile;
extern vec4 frameRect;
extern Image shadowAtlas;
varying vec3 ground;
#ifdef VERTEX
vec4 position(mat4 tp,vec4 vp){
 vp.xy*=spriteStretch;vp.x+=vp.y*lean;
 float c=cos(objectYaw),s=sin(objectYaw);
 float height=max(0.0,vp.y*objectScale+objectPos.y);
 ground=vec3(objectPos.x+vp.x*objectScale*c+away.x*height,groundHeight+.022,objectPos.z-vp.x*objectScale*s+away.y*height);
 vec3 rel=ground-camera;float z=dot(rel,forwardDir);
 return vec4(dot(rel,rightDir)*projectionScale/aspect,-dot(rel,upDir)*projectionScale,1.002*z-.1001,z);
}
#endif
#ifdef PIXEL
vec4 effect(vec4 c,Image tex,vec2 uv,vec2 px){
 vec2 p=frameRect.xy+vec2(mirror>.5?1.0-uv.x:uv.x,uv.y)*frameRect.zw;
 vec2 d=frameRect.zw/240.0;
 vec2 lo=frameRect.xy+d,hi=frameRect.xy+frameRect.zw-d;
 float a=Texel(tex,clamp(p,lo,hi)).a*.5;
 a+=Texel(tex,clamp(p+vec2(d.x,0),lo,hi)).a*.125;
 a+=Texel(tex,clamp(p-vec2(d.x,0),lo,hi)).a*.125;
 a+=Texel(tex,clamp(p+vec2(0,d.y),lo,hi)).a*.125;
 a+=Texel(tex,clamp(p-vec2(0,d.y),lo,hi)).a*.125;
 vec2 q=clamp((ground.xz-.5)/worldSize*.25,vec2(.5/512.0),vec2(127.5/512.0));
 vec4 visibility=Texel(shadowAtlas,shadowTile+q);
 a*=visibility.r*(1.0-smoothstep(.45,.8,visibility.b));
 a*=mix(.45,1.0,uv.y)*opacity;
 if(a<.005)discard;
 return vec4(.025,.020,.026,a);
}
#endif
]]
function S.new()
  return love.graphics.newShader(code)
end
function S.draw(r, g)
  local lg = love.graphics
  local s = r.castShadowShader
  r:cameraUniforms(s)
  s:send('shadowAtlas', r.lighting.visibility.image)
  s:send('worldSize', Grid.span(g.world))
  lg.setShader(s)
  lg.setDepthMode('less', false)
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.hp > 0 then
      local ground = Ground.height(g.world, e.x, e.z)
      local _, _, _, lx, lz, index, strength = r.lighting:sample(e.x, ground + 0.8, e.z)
      local length = math.sqrt(lx * lx + lz * lz)
      if index > 0 and strength > 0.025 and length > 0.001 then
        local frame, hover, lean, sx, sy, size, width, height, baseY, atlas = Geometry.pose(g, e)
        local image = (r.frameImages[atlas] and r.frameImages[atlas][frame]) or r.animations[atlas]
        r.sprite:setTexture(image)
        s:send('frameRect', r.frames[atlas][frame].rect)
        s:send('spriteStretch', r:vec2(sx, sy))
        s:send('objectScale', size)
        s:send('lean', lean)
        s:send('objectPos', r:vec3(e.x, baseY, e.z))
        s:send('groundHeight', ground)
        s:send('objectYaw', math.atan2(g.player.x - e.x, g.player.z - e.z))
        s:send('mirror', (r.frameMirrors[atlas] and r.frameMirrors[atlas][frame]) or 0)
        s:send('away', r:vec2(-lx / length * 0.95, -lz / length * 0.95))
        s:send('shadowTile', r.lighting.tiles[index])
        s:send('opacity', math.min(0.32, strength * 1.1))
        lg.draw(r.sprite)
      end
    end
  end
  lg.setDepthMode('less', true)
  lg.setShader(r.shader)
end
return S
