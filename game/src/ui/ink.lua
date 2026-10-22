-- The interface is another painted part of the chapel: lime writing grounds,
-- carbon / sinopia ink, and image-authored ornaments. No generated glyph shapes
-- or runtime fonts: this shader only chooses the pigment of existing PNG ink.
local F = {}
local lg = love.graphics
local inkShader
function F.ink(lightGround)
  if not inkShader then
    inkShader = lg.newShader([[
  extern number lightGround;
  vec4 effect(vec4 c,Image tex,vec2 uv,vec2 px){
   vec4 p=Texel(tex,uv);if(p.a<.01)discard;
   float l=dot(p.rgb,vec3(.30,.59,.11));vec3 rgb=p.rgb*c.rgb;
   if(lightGround>.5){
    vec3 pigment=vec3(.115,.082,.060);
    bool red=c.r>c.g*1.5&&c.r>c.b*1.5;
    bool blue=c.b>c.r*1.12&&c.g>c.r*1.1;
    bool gold=c.r>c.b*1.5&&!red;
    if(red)pigment=vec3(.40,.085,.050);
    else if(blue)pigment=vec3(.105,.215,.230);
    else if(gold)pigment=vec3(.29,.145,.065);
    // Quiet variation belongs inside a stroke, never a halo around small type.
    rgb=pigment*(.88+.12*l);
    // Illustrated source letters have a broad dark drop rim for the former
    // black UI. On lime that rim must become transparent, not a solid blob
    // joining adjacent Gothic stems and closing their counters.
    p.a*=smoothstep(.12,.65,l);
   }
   return vec4(rgb,p.a*c.a);
  }
 ]])
  end
  inkShader:send('lightGround', lightGround == false and 0 or 1)
  return inkShader
end
return F
