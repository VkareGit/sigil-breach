-- Under every living demon: shadows, the windup ring, the portal it climbs
-- out of and the landing point of a leap.
local Archetypes = require('src.content.enemies')
local Ground = require('src.physics.ground')
local Pools = require('src.session.world')
local Shadows = require('src.render.shadows')
local COLORS = require('src.render.effects').colors
local Context = require('src.session.context')
local Characters = require('src.content.characters')
local Pass = {}
function Pass.draw(r, g)
  local lg = love.graphics
  lg.setDepthMode('less', true)
  Shadows.draw(r, g)
  -- The pools under the bodies, all in one draw (in the bodies' order).
  local stamps = r.shadowStamps
  stamps:clear()
  lg.setDepthMode('less', false)
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.hp > 0 then
      local size = Archetypes.look(e).shadow
      local ground = Ground.of(g.world, e)
      if stamps.count + 2 > stamps.capacity then
        stamps:draw(r, g)
        stamps:clear()
      end
      stamps:add(e.x, ground + 0.015, e.z, size * 1.35, nil, 0.24)
      stamps:add(e.x, ground + 0.016, e.z, size * 0.95, nil, 0.38)
    end
  end
  stamps:draw(r, g)
  lg.setDepthMode('less', true)
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.hp > 0 then
      local look = Archetypes.look(e)
      local ground = Ground.of(g.world, e)
      if e.ai == 'windup' then
        local progress = 1 - e.windup / (e.windupDuration or 1)
        r:object(
          r.warning,
          e.x,
          ground + 0.025,
          e.z,
          0,
          0.42 + progress * 0.35,
          look.warning or COLORS.ember
        )
      end
      -- A leap marks its landing point from the crouch to the landing: the
      -- player always sees where the arc ends (dodgeable, never a surprise).
      -- The ring is the real reach: landing radius plus the knight's body.
      local spec = e.attackSpec
      if spec and spec.kind == 'leap' and (e.ai == 'windup' or e.leaping) and e.aimX then
        local reachLand = spec.landRadius + Characters.of(Context.actor(g)).body.radius
        r:object(
          r.warning,
          e.aimX,
          Ground.height(g.world, e.aimX, e.aimZ, e.aimLevel) + 0.03,
          e.aimZ,
          0,
          reachLand * 1.04,
          COLORS.ember,
          0.85
        )
      end
    end
  end
end
return Pass
