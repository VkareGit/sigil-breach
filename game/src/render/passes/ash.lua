-- Deterministic ash stays in world space and respects depth; no screen-space
-- snow. Grey ash falls; every twelfth mote is a live cinder rising from the pit.
local ASH = { 0.30, 0.25, 0.22 }
local EMBER = { 1.25, 0.52, 0.16 } -- dull cinder: fire accent, not a bright speck
-- The motes (the renderer's ash batch holds this many).
local Pass = { count = 96 }
function Pass.draw(r, g, time)
  r.ashBatch:clear()
  for i = 1, Pass.count do
    local x = 2.5 + (i * 7.31) % 26
    local z = 2.5 + (i * 3.71) % 26
    if i % 12 == 0 then
      local y = (i * 0.53 + time * 0.55) % 4.6
      r.ashBatch:add(x + math.sin(time * 1.7 + i) * 0.30, y, z, 0.10 + (i % 3) * 0.04, EMBER)
    else
      local y = 4.3 - (i * 0.37 + time * 0.16) % 4.3
      r.ashBatch:add(x + math.sin(time * 0.5 + i) * 0.22, y, z, 0.12 + (i % 3) * 0.06, ASH)
    end
  end
  r.ashBatch:draw(r, g)
end
return Pass
