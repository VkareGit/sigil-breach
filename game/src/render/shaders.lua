local vertex = [[
extern vec3 camera,rightDir,upDir,forwardDir,objectPos;
extern number objectYaw,objectScale,aspect,projectionScale;
varying vec3 worldPos;
#ifdef VERTEX
vec4 projectVertex(vec4 vp) {
  float c=cos(objectYaw),s=sin(objectYaw);vec3 p=vp.xyz*objectScale;
  worldPos=vec3(p.x*c+p.z*s,p.y,-p.x*s+p.z*c)+objectPos;
  vec3 rel=worldPos-camera;float z=dot(rel,forwardDir);
  return vec4(dot(rel,rightDir)*projectionScale/aspect,-dot(rel,upDir)*projectionScale,1.002*z-.1001,z);
}
#endif
]]
-- Pigment belongs to surfaces. Distance separates overlapping painted planes;
-- it must not put a grey veil over the foreground or erase enemy gestures.
local atmosphere = [[
const vec3 SOOT=vec3(.10,.08,.07);
const vec3 ASH_HAZE=vec3(.13,.15,.18);
const vec3 EMBER_MIST=vec3(.24,.17,.12);
vec3 atmosphere(vec3 rgb,vec3 p,vec3 eye,float density){
 float d=length(p-eye);
 float mist=exp(-max(p.y,0.0)*2.4)*(1.0-exp(-d*.07));
 rgb=mix(rgb,EMBER_MIST,mist*.07);
 return mix(rgb,ASH_HAZE,(1.0-exp(-max(d-7.0,0.0)*density))*.42);
}
]]
local worldCode = vertex
  .. atmosphere
  .. [[
extern Image atlas;
// Optional map-authored plaster shares the fresco's source pigment. Floors,
// red trim and recesses retain their own materials; old maps opt out.
extern Image stoneAtlas;
extern vec4 stoneRect;
extern number useStonePaint;
extern number flash,objectAlpha;
extern vec3 flashColor,tint,lights[16],lightColors[16];
extern vec3 ambientLight;
// Each lit slot's tile covers tileSpan cells from its light's origin; the
// ground image carries the map's contact shade (g) and walls (b).
extern Image shadowAtlas,groundAtlas;
extern vec2 shadowTiles[16],lightOrigins[16];
extern number tileSpan,groundScale;
extern vec2 groundSpan,groundLow,groundHigh;
// Decks (plan v10 V3): per cell the underside (r) and top (g) of its deck,
// as shares of deckHeight m over deckDatum; a deck between a light and a
// surface keeps the light from it. A world without decks sends no deck.
extern Image deckAtlas;
extern vec2 deckSpan;
extern number deckHeight,deckDatum;
varying vec3 normal;
varying vec4 material;
varying vec3 materialPos;
#ifdef VERTEX
attribute vec3 VertexNormal;
vec4 position(mat4 tp,vec4 vp) {
  float c=cos(objectYaw),s=sin(objectYaw);
  normal=vec3(VertexNormal.x*c+VertexNormal.z*s,VertexNormal.y,-VertexNormal.x*s+VertexNormal.z*c);
  material=VertexColor;materialPos=vp.xyz;return projectVertex(vp);
}
#endif
#ifdef PIXEL
float shortRayVisibility(vec2 from,vec2 to){
 float visible=1.0;
 for(int k=1;k<12;k++){
  vec2 q=mix(from,to,float(k)/12.0);
  vec2 uv=clamp((q-.5)/groundSpan*groundScale,groundLow,groundHigh);
  visible*=1.0-smoothstep(.45,.8,Texel(groundAtlas,uv).b);
 }
 return visible;
}
vec4 effect(vec4 color,Image tex,vec2 uv,vec2 pixel) {
  vec3 n=normalize(normal);vec3 base=material.rgb*tint;
  if(material.a<0.0) {
    // Pixel-forged iron stays anchored to the moving plate, not the arena.
    vec2 q=floor(materialPos.xy*80.0);
    float grain=fract(sin(dot(q,vec2(12.9898,78.233)))*43758.5453);
    float seam=mod(q.y+80.0,10.0)<1.0?.47:1.0;
    float scratch=mod(q.x+q.y*3.0+240.0,23.0)<1.0?1.35:1.0;
    base*= (.68+grain*.72)*seam*scratch;
  } else if(material.a<.05) {
    bool floorTile=abs(n.y)>.7 && worldPos.y<.1;
    vec2 t=abs(n.y)>.7?worldPos.xz/4.0:(abs(n.x)>.7?vec2(worldPos.z,worldPos.y)/2.8:vec2(worldPos.x,worldPos.y)/2.8);
    vec2 tile=vec2(0.0);
    if(floorTile)tile=vec2(1.0,1.0);else if(material.r>material.b*1.2)tile=vec2(0.0,1.0);else if(material.r<.15)tile=vec2(1.0,0.0);
    // Preserve painted modelling, with UVs anchored to the actual wall.
    vec2 pixelUV=(floor(fract(t)*512.0)+.5)/512.0;
    base=Texel(atlas,(tile+pixelUV)*.5).rgb*tint;
    if(useStonePaint>.5 && !floorTile && tile.x<.5 && tile.y<.5){
      vec2 stoneUV=(floor(fract(t)*128.0)+.5)/128.0;
      base=Texel(stoneAtlas,stoneRect.xy+stoneUV*stoneRect.zw).rgb*tint;
    }
    if(floorTile)base=mix(base,vec3(dot(base,vec3(.30,.59,.11))),.14)*.87;
    if(abs(n.y)<.7){
      base*=mix(.72,1.0,smoothstep(0.0,1.4,worldPos.y));
    }
  }
  // Cool reflected sky retains navigable darks. Warm pools belong to actual
  // sources and stop at the arena's walls, instead of following the camera.
  vec2 surface=worldPos.xz+n.xz*.09;
  vec2 groundUV=clamp((surface-.5)/groundSpan*groundScale,groundLow,groundHigh);
  float ao=Texel(groundAtlas,groundUV).g;
  vec3 light=(ambientLight+vec3(.09)*max(0.0,dot(n,normalize(vec3(.35,1.0,-.25)))))*mix(1.0,ao,.8);
  vec4 deck=Texel(deckAtlas,(floor(worldPos.xz-n.xz*.09+.5)-.5)/deckSpan);
  float deckBottom=deckDatum+deck.r*deckHeight,deckTop=deckDatum+deck.g*deckHeight;
  for(int i=0;i<16;i++){
   vec3 delta=lights[i]-worldPos;float d2=dot(delta,delta);
   vec2 shadowUV=clamp((surface-lightOrigins[i])/tileSpan*.25,vec2(.5/512.0),vec2(127.5/512.0));
   float visible=shadowTiles[i].x<0.0?1.0:Texel(shadowAtlas,shadowTiles[i]+shadowUV).r;
   float radius2=shadowTiles[i].x<0.0?9.0:72.0;
   if(shadowTiles[i].x<0.0 && d2<9.0 && dot(lightColors[i],lightColors[i])>.001)
    visible=shortRayVisibility(lights[i].xz,worldPos.xz+n.xz*.09);
   if(deck.g>0.0&&((worldPos.y<deckBottom+.01&&lights[i].y>deckTop)||(worldPos.y>deckTop-.01&&lights[i].y<deckBottom)))
    visible=0.0;
   float falloff=max(0.0,1.0-d2/radius2)/(1.0+d2*.22);
   light+=lightColors[i]*.72*max(.12,dot(n,normalize(delta+vec3(.00001))))*falloff*visible;
  }
  float dc=length(worldPos-camera);light+=flashColor*flash*1.2/(1.0+dc*dc*.20);
  vec3 rgb=base*light+base*max(0.0,material.a)*1.5;
  return vec4(atmosphere(rgb,worldPos,camera,.040),objectAlpha);
}
#endif
]]
local spriteCode = vertex
  .. atmosphere
  .. [[
extern vec4 frameRect;
extern number pain,brightness,lean,mirror,effectAlpha,soft,silhouette,paint;
extern vec2 keyLight;
extern vec2 spriteStretch;
extern vec3 effectTint;
]]
  .. require('src.render.creature_pigment').shader
  .. [[
#ifdef VERTEX
vec4 position(mat4 tp,vec4 vp){vp.xy*=spriteStretch;vp.x+=vp.y*lean;return projectVertex(vp);}
#endif
#ifdef PIXEL
vec4 effect(vec4 c,Image tex,vec2 uv,vec2 pixel){
 vec2 spriteUV=vec2(mirror>.5?1.0-uv.x:uv.x,uv.y);vec2 localUV=(floor(spriteUV*320.0)+.5)/320.0;vec2 atlasUV=frameRect.xy+localUV*frameRect.zw;vec4 p=Texel(tex,atlasUV);
 vec2 stepUV=frameRect.zw/320.0;
 vec2 lo=frameRect.xy+stepUV*.5,hi=frameRect.xy+frameRect.zw-stepUV*.5;
 if(p.a<(soft>.5?.025:.30)) {
  if(silhouette>.5) {
   float edge=max(max(Texel(tex,clamp(atlasUV+vec2(stepUV.x,0.0),lo,hi)).a,Texel(tex,clamp(atlasUV-vec2(stepUV.x,0.0),lo,hi)).a),max(Texel(tex,clamp(atlasUV+vec2(0.0,stepUV.y),lo,hi)).a,Texel(tex,clamp(atlasUV-vec2(0.0,stepUV.y),lo,hi)).a));
   if(edge>.5)return vec4(.24,.11,.07,effectAlpha); // sinopia contour
  }
  discard;
 }
 // New sprites contain their own fresco colour and drawn contours.
 vec3 pigment=bodyPigment(tex,spriteUV,p);
 float l=dot(pigment,vec3(.30,.59,.11));
 vec3 base=mix(pigment,vec3(l),.025);
 // Pickups and other generic icons are repainted in the demons' pigments.
 if(paint>.5)base=p.rgb;
 // Chiaroscuro on the billboard: the side facing the nearest torch is lit,
 // the far side falls into shadow, the head sinks toward the dark above.
 // keyLight.x is the light's side in screen space (-1 left, +1 right),
 // keyLight.y its strength. uv.x runs right-to-left on screen here.
 float across=(.5-uv.x)*2.0; // mesh uv, independent of texture mirroring
 float shade=clamp(1.0+keyLight.x*across*keyLight.y*.36,.70,1.22);
 vec3 rgb=mix(base*brightness*shade*effectTint,vec3(1.0,.78,.61),pain*.22);
 rgb=atmosphere(rgb,worldPos,camera,silhouette>.5?.010:.048);
 return vec4(rgb,(soft>.5?p.a:1.0)*effectAlpha);
}
#endif
]]
local sealCode = vertex
  .. [[
extern vec3 pigment;
#ifdef VERTEX
vec4 position(mat4 tp,vec4 vp){return projectVertex(vp);}
#endif
#ifdef PIXEL
vec4 effect(vec4 c,Image tex,vec2 uv,vec2 pixel){
 // This camera-facing plane reverses its horizontal axis in view space.
 // Restore the manuscript orientation: historical seals must not be mirrored.
 vec4 p=Texel(tex,vec2(1.0-uv.x,uv.y));float ink=(1.0-min(p.r,min(p.g,p.b)))*p.a;
 if(ink<.18)discard;
 vec3 rgb=mix(pigment,vec3(.112,.074,.056),(1.0-exp(-length(worldPos-camera)*.03))*.92);
 return vec4(rgb,ink);
}
#endif
]]
-- A physical painted plane, lit at its world position. Unlike an effect or
-- billboard it has fixed world UVs, source alpha and no emissive contribution.
local textureCode = vertex
  .. atmosphere
  .. [[
extern vec4 frameRect;
extern vec3 light,tint;
extern number inkMask,objectAlpha,inkReveal;
#ifdef VERTEX
vec4 position(mat4 tp,vec4 vp){return projectVertex(vp);}
#endif
#ifdef PIXEL
vec4 effect(vec4 c,Image tex,vec2 uv,vec2 pixel){
 vec4 p=Texel(tex,frameRect.xy+uv*frameRect.zw);
 if(inkMask>.5){if(uv.y<1.0-inkReveal)discard;p.a*=1.0-min(p.r,min(p.g,p.b));p.rgb=vec3(1.0);}
 if(p.a<.02)discard;
 return vec4(atmosphere(p.rgb*tint*light,worldPos,camera,.040),p.a*objectAlpha);
}
#endif
]]
local tracerCode = vertex
  .. [[
varying vec4 traceColor;
#ifdef VERTEX
vec4 position(mat4 tp,vec4 vp){traceColor=VertexColor;return projectVertex(vp);}
#endif
#ifdef PIXEL
vec4 effect(vec4 c,Image tex,vec2 uv,vec2 pixel){return traceColor;}
#endif
]]

local particleCode = worldCode:gsub(
  'attribute vec3 VertexNormal;',
  'attribute vec3 VertexNormal;\nattribute vec3 InstanceOffset;\nattribute float InstanceScale;\nattribute vec3 InstanceTint;'
)
particleCode = particleCode:gsub(
  'material=VertexColor;materialPos=vp.xyz;',
  'material=VertexColor;material.rgb*=InstanceTint;vp.xyz=vp.xyz*InstanceScale+InstanceOffset;materialPos=vp.xyz;'
)
-- Replace one exact passage of a shader (plain text, found once).
local function swap(code, old, new)
  local i, j = code:find(old, 1, true)
  assert(i and not code:find(old, j + 1, true), 'shader passage not found once: ' .. old)
  return code:sub(1, i - 1) .. new .. code:sub(j + 1)
end
-- Instanced variants (plan v10 V3): what a single draw sends as uniforms
-- comes from per-instance attributes; the pixel code is the same text.
local placed = 'extern vec3 camera,rightDir,upDir,forwardDir;\n'
  .. 'extern number aspect,projectionScale;\n'
  .. 'vec3 objectPos;float objectYaw,objectScale;'
local function instanced(code)
  return swap(
    code,
    'extern vec3 camera,rightDir,upDir,forwardDir,objectPos;\n'
      .. 'extern number objectYaw,objectScale,aspect,projectionScale;',
    placed
  )
end
-- A world mesh stamped many times (the shadow pools under bodies): the
-- particle attributes and an alpha of its own per stamp.
local stampCode = swap(
  particleCode,
  'extern number flash,objectAlpha;',
  'extern number flash;\nvarying float objectAlpha;'
)
stampCode = swap(
  stampCode,
  'attribute float InstanceScale;',
  'attribute float InstanceScale;\nattribute float InstanceAlpha;'
)
stampCode = swap(
  stampCode,
  'material=VertexColor;material.rgb',
  'objectAlpha=InstanceAlpha;material=VertexColor;material.rgb'
)
-- Painted bodies: one draw per image (render/instances.lua, R:enemy).
local bodyCode = swap(
  instanced(spriteCode),
  'extern vec4 frameRect;\n'
    .. 'extern number pain,brightness,lean,mirror,effectAlpha,soft,silhouette,paint;\n'
    .. 'extern vec2 keyLight;\n'
    .. 'extern vec2 spriteStretch;',
  'varying vec4 frameRect;\n'
    .. 'varying float pain,brightness,mirror,silhouette;\n'
    .. 'varying vec2 keyLight;\n'
    .. 'extern number effectAlpha,soft,paint;\n'
    .. 'vec2 spriteStretch;float lean;\n'
    .. '#ifdef VERTEX\n'
    .. 'attribute vec4 BodyPlace,BodyShape,BodyFrame,BodyLook;\n'
    .. 'attribute vec2 BodyKey;\n'
    .. '#endif'
)
bodyCode = swap(
  bodyCode,
  'vec4 position(mat4 tp,vec4 vp){vp.xy*=spriteStretch;',
  'vec4 position(mat4 tp,vec4 vp){'
    .. 'objectPos=BodyPlace.xyz;objectYaw=BodyPlace.w;objectScale=BodyShape.x;'
    .. 'spriteStretch=BodyShape.yz;lean=BodyShape.w;frameRect=BodyFrame;'
    .. 'mirror=BodyLook.x;pain=BodyLook.y;brightness=BodyLook.z;silhouette=BodyLook.w;'
    .. 'keyLight=BodyKey;vp.xy*=spriteStretch;'
)
local surfaceCode = vertex
  .. atmosphere
  .. [[
varying vec4 markColor;
#ifdef VERTEX
vec4 position(mat4 tp,vec4 vp){markColor=VertexColor;return projectVertex(vp);}
#endif
#ifdef PIXEL
vec4 effect(vec4 c,Image tex,vec2 uv,vec2 pixel){
 // Deliberate pigment clusters at world resolution, alpha from painted art.
 vec4 p=Texel(tex,(floor(uv*256.0)+.5)/256.0);
 if(p.a<.08)discard;
 return vec4(atmosphere(p.rgb*markColor.rgb,worldPos,camera,.040),p.a*markColor.a);
}
#endif
]]
-- The first-person hands and weapon (0.26 G6): painted iron seen in the
-- same light and air as the scene. The torches' light at the knight
-- (light), the iron's own contrast and saturation brought toward the fresco,
-- a breath of the ember mist, and the part nearest the bottom of the frame
-- falling into the knight's own shadow. Alpha stays the painted outline.
local handsCode = [[
extern vec3 light;
extern vec3 mist;
extern number contrast,saturation,haze,shade,height,exposure;
extern vec2 pigmentStep;
extern number pigmentBlend;
vec4 effect(vec4 c,Image tex,vec2 uv,vec2 pixel){
 vec4 p=Texel(tex,uv);
 if(p.a<.02)discard;
 // Average source pigment only. Transparent gutters carry no colour; the
 // original alpha remains authoritative, so no outline grows or fades.
 vec4 a=Texel(tex,uv+vec2(pigmentStep.x,0.0));
 vec4 b=Texel(tex,uv-vec2(pigmentStep.x,0.0));
 vec4 d=Texel(tex,uv+vec2(0.0,pigmentStep.y));
 vec4 e=Texel(tex,uv-vec2(0.0,pigmentStep.y));
 vec3 pigment=(p.rgb*p.a*2.0+a.rgb*a.a+b.rgb*b.a+d.rgb*d.a+e.rgb*e.a)
              /(p.a*2.0+a.a+b.a+d.a+e.a);
 p.rgb=mix(p.rgb,pigment,pigmentBlend);
 float l=dot(p.rgb,vec3(.30,.59,.11));
 vec3 rgb=mix(vec3(l),p.rgb,saturation);
 rgb=max(vec3(0.0),(rgb-vec3(.38))*contrast+vec3(.38));
 rgb*=light*exposure;
 rgb=mix(rgb,mist,haze);
 rgb*=1.0-shade*smoothstep(.62,1.0,pixel.y/height);
 return vec4(rgb,p.a*c.a);
}
]]
local Fresco = require('src.render.fresco_scene_shaders')
return {
  hands = handsCode,
  particle = particleCode,
  stamp = stampCode,
  world = worldCode,
  sprite = spriteCode,
  body = bodyCode,
  instanced = instanced,
  swap = swap,
  seal = sealCode,
  texture = textureCode,
  post = Fresco.post,
  tracer = tracerCode,
  surface = surfaceCode,
  sky = Fresco.sky,
}
