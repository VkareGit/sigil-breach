-- Pools, lines and lightning marks: telegraph colour, then the live ground.
local Effects = require('src.render.effects')
local Kinds = require('src.render.hazard_kinds')
local Pools = require('src.session.world')
local Pass = {}
function Pass.draw(r, g)
  for _, h in ipairs(Pools.of(g, 'hazards')) do
    Kinds.of(h).ground(r, g, h, Effects)
  end
end
return Pass
