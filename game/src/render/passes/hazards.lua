-- Pools, lines and lightning marks: telegraph colour, then the live ground.
local HazardArt = require('src.render.hazard_art')
local Ground = require('src.physics.ground')
local Pools = require('src.session.world')
local COLORS = require('src.render.effects').colors
local Pass = {}
function Pass.draw(r, g)
  for _, haz in ipairs(Pools.of(g, 'hazards')) do
    if haz.kind ~= 'lightning' then
      HazardArt.draw(r, g, haz)
    else
      local ground = Ground.of(g.world, haz)
      r:object(
        r.warning,
        haz.x,
        ground + 0.03,
        haz.z,
        0,
        haz.radius,
        haz.delay > 0 and COLORS.bone or COLORS.brimstone
      )
    end
  end
end
return Pass
