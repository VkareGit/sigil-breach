-- Detach an explicitly annotated decorative effect without editing its painting.
-- Source-UV clipping leaves every body pixel, contour sample and hit mask intact.
local Anatomy = require('src.content.art.anatomy_regions')
local EnemyArt = require('src.content.enemy_art')
local Cutout = {}
local cache = {}
function Cutout.of(atlas)
  if cache[atlas] then
    return cache[atlas]
  end
  local result = {}
  local anatomy = Anatomy.layouts[atlas]
  for index, frame in ipairs(EnemyArt.layouts[atlas].frames) do
    for _, part in ipairs(anatomy and anatomy.frames[index].parts or {}) do
      if part.detached then
        assert(
          part.hittable == false and part.material == 'effect',
          'only decorative paint may detach'
        )
        assert(not result[frame.sourcePath], 'one detached polygon per source image')
        local points, rect = {}, frame.rect
        assert(#part.polygon <= 16, 'detached paint polygon exceeds shader capacity')
        for i = 1, #part.polygon, 2 do
          points[#points + 1] =
            { rect[1] + part.polygon[i] * rect[3], rect[2] + part.polygon[i + 1] * rect[4] }
        end
        result[frame.sourcePath] = points
      end
    end
  end
  cache[atlas] = result
  return result
end
function Cutout.apply(shader, points)
  shader:send('paintCutoutCount', points and #points or 0)
  if points then
    shader:send('paintCutoutPoints', unpack(points))
  end
end
Cutout.shader = [[
extern int paintCutoutCount;
extern vec2 paintCutoutPoints[8];
bool removedPaint(vec2 at){
 bool inside=false;
 for(int i=0;i<8;i++){
  if(i>=paintCutoutCount)break;
  int j=i==0?paintCutoutCount-1:i-1;
  vec2 a=paintCutoutPoints[i],b=paintCutoutPoints[j];
  if((a.y>at.y)!=(b.y>at.y)){
   if(at.x<(b.x-a.x)*(at.y-a.y)/(b.y-a.y)+a.x)inside=!inside;
  }
 }
 return inside;
}
]]
return Cutout
