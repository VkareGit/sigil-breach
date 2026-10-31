-- Surface illustrations carry the style. The compositor only handles gameplay
-- feedback and a restrained edge falloff; it never repaints every frame into
-- twenty colours or projects stationary cracks over the player's eyes.
return {
  sky = [[
extern Image horizon,zenith;
extern vec3 rightDir,upDir,forwardDir;
extern number aspect,projectionScale,time,gain,smoke;
const float TAU=6.2831853;
vec4 effect(vec4 c,Image tex,vec2 uv,vec2 px){
 vec2 ndc=vec2(uv.x*2.0-1.0,1.0-uv.y*2.0);
 vec3 d=normalize(forwardDir+rightDir*ndc.x*aspect/projectionScale+upDir*ndc.y/projectionScale);
 float u=fract(atan(d.x,d.z)/TAU+.5);
 float v=clamp(.79-d.y*.91,.008,.995);
 vec3 col=Texel(horizon,vec2(u,v)).rgb;
 // Quiet pigment fire; no bloom, camera-relative drift, or pulsing whole sky.
 float fire=smoothstep(.10,.22,col.r-col.b)*smoothstep(.23,.42,col.r);
 col*=gain+fire*.19+fire*sin(time*.7+u*23.0)*.012;
 col=mix(col,vec3(.10,.12,.15),smoothstep(.78,1.0,d.y));
 // A panorama stretched towards the zenith streaks: burning cloud takes over.
 vec2 q=d.xz/(max(d.y,0.0)+.55)*.8+vec2(time*.006,time*.002);
 col=mix(col,Texel(zenith,q).rgb*gain,smoke*smoothstep(.30,.62,d.y));
 return vec4(col,1.0)*c;
}
]],
  post = [[
extern number hurt,surge,low,kill,still;
extern vec2 size;
vec4 effect(vec4 c,Image tex,vec2 uv,vec2 pixel){
 vec3 rgb=Texel(tex,uv).rgb;
 vec2 q=uv-.5;float r2=dot(q,q);
 float l=dot(rgb,vec3(.30,.59,.11));
 // A perfect dodge stills the world into its underdrawing for a breath:
 // sinopia in the shadows, lime plaster in the lights.
 rgb=mix(rgb,mix(vec3(.30,.09,.05),vec3(.93,.86,.70),smoothstep(.04,.62,l)),still*.62);
 rgb=mix(rgb,vec3(l)*vec3(1.04,.99,.94),low*.44);
 rgb+=vec3(.40,.018,.01)*hurt*r2*1.8;
 // A dodge (a broken seal) gilds the frame: gold leaf toward its edges.
 rgb+=vec3(.075,.052,.018)*surge*(.3+r2*3.0);
 rgb+=vec3(.23,.012,.006)*low*r2;
 rgb=mix(rgb,rgb*vec3(1.08,.94,.90),kill);
 rgb*=1.0-r2*.17;
 // A tiny painted edge unites the scene with the fresco UI, never a grime mask.
 vec2 p=uv*size;
 float edge=min(min(p.x,size.x-p.x),p.y);
 if(edge<1.0)rgb=vec3(.22,.075,.047);
 return vec4(clamp(rgb,0.0,1.0),1.0)*c;
}
]],
}
