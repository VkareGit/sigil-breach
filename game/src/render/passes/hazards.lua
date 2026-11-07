-- Pools, lines and lightning marks: telegraph colour, then the live ground.
local RenderFX = require('src.render.effects')
local HazardKinds = require('src.render.hazard_kinds')
local Pools = require('src.session.world')
local Pass = {}
function Pass.draw(r, g)
  for _, h in ipairs(Pools.of(g, 'hazards')) do
    HazardKinds.of(h).ground(r, g, h, RenderFX)
  end
end
return Pass
