-- Painted floor silhouettes follow the same pose/feet as the body.
-- This is a bounded 2.5D projection, not a full volumetric shadow map.
local Roles = require('src.core.roles')
local Geometry = require('src.enemies.geometry')
local Ground = require('src.physics.ground')
local Pools = require('src.session.world')
local S = {}
local code = [[
// One shadow per body, all bodies of an image in one instanced draw (plan
// v10 V3): the body's placement, light and frame come per instance.
extern vec3 camera,rightDir,upDir,forwardDir;
extern number aspect,projectionScale,tileSpan;
extern Image shadowAtlas;
vec3 objectPos;float objectYaw,objectScale,lean,groundHeight;vec2 spriteStretch,away;
varying float mirror,opacity;
varying vec2 shadowTile,shadowOrigin;
varying vec4 frameRect;
varying vec3 ground;
#ifdef VERTEX
attribute vec4 CastPlace,CastShape,CastFrame,CastLight,CastTile;
attribute float CastMirror;
vec4 position(mat4 tp,vec4 vp){
 objectPos=CastPlace.xyz;objectYaw=CastPlace.w;objectScale=CastShape.x;
 spriteStretch=CastShape.yz;lean=CastShape.w;frameRect=CastFrame;
 away=CastLight.xy;groundHeight=CastLight.z;opacity=CastLight.w;
 shadowTile=CastTile.xy;shadowOrigin=CastTile.zw;mirror=CastMirror;
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
 vec2 q=clamp((ground.xz-shadowOrigin)/tileSpan*.25,vec2(.5/512.0),vec2(127.5/512.0));
 vec4 visibility=Texel(shadowAtlas,shadowTile+q);
 a*=visibility.r*(1.0-smoothstep(.45,.8,visibility.b));
 a*=mix(.45,1.0,uv.y)*opacity;
 if(a<.005)discard;
 return vec4(.025,.020,.026,a);
}
#endif
]]
S.format = {
  { 'CastPlace', 'float', 4 },
  { 'CastShape', 'float', 4 },
  { 'CastFrame', 'float', 4 },
  { 'CastLight', 'float', 4 },
  { 'CastTile', 'float', 4 },
  { 'CastMirror', 'float', 1 },
}
function S.new()
  return love.graphics.newShader(code)
end
function S.draw(r, g)
  local lg = love.graphics
  local s = r.castShadowShader
  r:cameraUniforms(s)
  s:send('shadowAtlas', r.lighting.visibility.image)
  s:send('tileSpan', r.lighting.tileSpan)
  lg.setShader(s)
  lg.setDepthMode('less', false)
  local batch = r.castShadows
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.hp > 0 then
      local ground = Ground.of(g.world, e)
      local _, _, _, lx, lz, index, strength = r.lighting:sample(e.x, ground + 0.8, e.z)
      local length = math.sqrt(lx * lx + lz * lz)
      if index > 0 and strength > 0.025 and length > 0.001 then
        local frame, _, lean, sx, sy, size, _, _, baseY, atlas =
          Geometry.pose(g, e, Roles.viewer(g))
        local image = (r.frameImages[atlas] and r.frameImages[atlas][frame]) or r.animations[atlas]
        local rect, tile, origin =
          r.frames[atlas][frame].rect, r.lighting.tiles[index], r.lighting.origins[index]
        local v = batch:add(image)
        v[1], v[2], v[3], v[4] = e.x, baseY, e.z, math.atan2(g.player.x - e.x, g.player.z - e.z)
        v[5], v[6], v[7], v[8] = size, sx, sy, lean
        v[9], v[10], v[11], v[12] = rect[1], rect[2], rect[3], rect[4]
        v[13], v[14] = -lx / length * 0.95, -lz / length * 0.95
        v[15], v[16] = ground, math.min(0.32, strength * 1.1)
        v[17], v[18], v[19], v[20] = tile[1], tile[2], origin[1], origin[2]
        v[21] = (r.frameMirrors[atlas] and r.frameMirrors[atlas][frame]) or 0
      end
    end
  end
  batch:draw()
  lg.setDepthMode('less', true)
  lg.setShader(r.shader)
end
return S
