-- How each kind of marked ground looks (content/hazards.lua):
--   ground(r, g, h, effects)  drawn on the floor
--   air(r, g, h, effects)     its spell above it, if any (render/effects.lua)
local Definitions = require('src.content.hazards')
local Ground = require('src.physics.ground')
local HazardArt = require('src.render.hazard_art')
local Registry = require('src.core.registry')
local Kinds = Registry:new('hazard art', function(entry, id)
  Definitions:get(id)
  assert(type(entry.ground) == 'function', 'hazard art ' .. id .. ' needs ground')
end)
Kinds:register('pool', { ground = HazardArt.draw })
Kinds:register('lightning', {
  ground = function(r, g, h, effects)
    r:object(
      r.warning,
      h.x,
      Ground.of(g.world, h) + 0.03,
      h.z,
      0,
      h.radius,
      h.delay > 0 and effects.colors.bone or effects.colors.brimstone
    )
  end,
  air = function(r, g, h, effects)
    local preparing = h.delay > 0
    local progress = preparing and (1 - h.delay / math.max(0.01, h.maxDelay or 1))
      or (1 - (h.life or 0) / 0.22)
    if preparing then
      effects.spell(
        r,
        g,
        2,
        progress,
        h.x,
        Ground.of(g.world, h) + 0.045,
        h.z,
        h.radius * 2,
        0.68,
        true
      )
    else
      -- A short narrow strike leaves the enemy silhouette visible. The ground ring
      -- is still the exact authoritative damage radius, not this ornamental width.
      effects.spell(r, g, 3, progress, h.x, Ground.of(g.world, h) + 1.5, h.z, 2.8, 0.9, false)
    end
  end,
})
function Kinds.of(h)
  return Kinds:get(h.kind or Definitions.default)
end
return Kinds
