-- Deterministic ash stays in world space and respects depth; no screen-space
-- snow (content/art/ash_look.lua).
local AshLook = require('src.content.art.ash_look')
local ASH, EMBER = AshLook.ash, AshLook.ember
-- The motes (the renderer's ash batch holds this many).
local Pass = { count = AshLook.count }
function Pass.draw(r, g, time)
  r.ashBatch:clear()
  local A, C, F = AshLook, AshLook.cinder, AshLook.fall
  for i = 1, Pass.count do
    local x = A.start + (i * A.stepX) % A.span
    local z = A.start + (i * A.stepZ) % A.span
    if i % A.cinderEvery == 0 then
      local y = (i * C.phase + time * C.rate) % C.top
      local sway = math.sin(time * C.swayRate + i) * C.sway
      r.ashBatch:add(x + sway, y, z, C.size + (i % 3) * C.grow, EMBER)
    else
      local y = F.top - (i * F.phase + time * F.rate) % F.top
      local sway = math.sin(time * F.swayRate + i) * F.sway
      r.ashBatch:add(x + sway, y, z, F.size + (i % 3) * F.grow, ASH)
    end
  end
  r.ashBatch:draw(r, g)
end
return Pass
