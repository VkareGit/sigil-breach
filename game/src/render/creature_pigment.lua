-- Match supplemental animation paint to its approved atlas. This is colour
-- only: source alpha, contour sampling, UV registration and hit masks stay
-- unchanged. Profiles live beside the ability artwork, not in combat code.
local Pigment = {}
local CLEAR_GRID, CLEAR_TONE, CLEAR_LIFT = { 0, 0 }, { 1, 1, 0 }, { 0, 0, 0 }
local CLEAR_RED = { 0, 1, 0, 1 }
function Pigment.apply(shader, profile)
  shader:send('bodyPigmentGrid', profile and profile.grid or CLEAR_GRID)
  shader:send('bodyPigmentTone', profile and profile.tone or CLEAR_TONE)
  shader:send('bodyPigmentLift', profile and profile.lift or CLEAR_LIFT)
  shader:send('bodyPigmentRed', profile and profile.red or CLEAR_RED)
end
Pigment.shader = [[
extern vec2 bodyPigmentGrid;
extern vec3 bodyPigmentTone,bodyPigmentLift;
extern vec4 bodyPigmentRed;
// Alpha is read by the original silhouette rule; only interior RGB is grouped.
// Samples are alpha weighted so hidden brown gutter pixels cannot bleed in.
vec3 bodyPigment(Image tex,vec2 sourceUV,vec4 original){
 if(bodyPigmentGrid.x<1.0)return original.rgb;
 vec2 step=frameRect.zw/bodyPigmentGrid;
 vec2 low=frameRect.xy+step*.5,high=frameRect.xy+frameRect.zw-step*.5;
 vec2 at=frameRect.xy+(floor(sourceUV*bodyPigmentGrid)+.5)*step;
 vec4 a=Texel(tex,clamp(at,low,high));
 vec4 b=Texel(tex,clamp(at+vec2(step.x,0.0),low,high));
 vec4 d=Texel(tex,clamp(at-vec2(step.x,0.0),low,high));
 vec4 e=Texel(tex,clamp(at+vec2(0.0,step.y),low,high));
 vec4 f=Texel(tex,clamp(at-vec2(0.0,step.y),low,high));
 float weight=4.0*a.a+b.a+d.a+e.a+f.a;
 vec3 grouped=weight>.01?(4.0*a.rgb*a.a+b.rgb*b.a+d.rgb*d.a+e.rgb*e.a+f.rgb*f.a)/weight:original.rgb;
 vec3 paint=mix(original.rgb,grouped,bodyPigmentTone.z);
 float l=dot(paint,vec3(.30,.59,.11));
 paint=mix(vec3(l),paint,bodyPigmentTone.y);
 paint=clamp(paint*bodyPigmentTone.x+bodyPigmentLift,0.0,1.0);
 // The supplement's vermilion cloth is much redder than the approved umber.
 // Compress only excess red; ochre skin, pale bone and alpha are untouched.
 float red=(paint.r-paint.g)/max(paint.r,.001);
 float weightRed=smoothstep(bodyPigmentRed.x,bodyPigmentRed.y,red)*bodyPigmentRed.z;
 paint.r=mix(paint.r,min(paint.r,paint.g*bodyPigmentRed.w),weightRed);
 return paint;
}
]]
return Pigment
