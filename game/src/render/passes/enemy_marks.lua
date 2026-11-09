-- Under every living demon: shadows, the windup ring, the portal it climbs
-- out of and the landing point of a leap.
local EnemyMarks = require('src.content.art.frame_look').enemyMarks
local Action = require('src.content.defs.action')
local Archetypes = require('src.content.enemies')
local Ground = require('src.physics.ground')
local Pools = require('src.session.world')
local Rules = require('src.combat.rules')
local Shadows = require('src.render.shadows')
local COUNTER_RING = 7
local HazardArt = require('src.render.hazard_art')
local landing = {}
local Context = require('src.session.context')
local Characters = require('src.content.characters')
local Pass = {}
-- The widest a mark spreads from a body (m).
local REACH = 5
function Pass.draw(r, g)
  local lg = love.graphics
  lg.setDepthMode('less', true)
  Shadows.draw(r, g)
  -- The pools under the bodies, all in one draw (in the bodies' order).
  local stamps = r.shadowStamps
  stamps:clear()
  lg.setDepthMode('less', false)
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.hp > 0 and not r:behind(e.x, 0, e.z, REACH) then
      local size = Archetypes.look(e).shadow
      local ground = Ground.of(g.world, e)
      if stamps.count + 2 > stamps.capacity then
        stamps:draw(r, g)
        stamps:clear()
      end
      local M = EnemyMarks
      stamps:add(e.x, ground + M.outerLift, e.z, size * M.outer, nil, M.outerAlpha)
      stamps:add(e.x, ground + M.innerLift, e.z, size * M.inner, nil, M.innerAlpha)
    end
  end
  stamps:draw(r, g)
  lg.setDepthMode('less', true)
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.hp > 0 and not r:behind(e.x, 0, e.z, REACH) then
      -- The moment a shot can turn the blow aside, in this body's painted language.
      local look = Archetypes.look(e)
      local open = e.attackSpec and e.attackSpec.parry
      if e.ai == 'windup' and open and e.windup + (e.holdLeft or 0) <= open then
        HazardArt.circle(r, g, e, look.counterMark, Rules.radius(e) * COUNTER_RING, 1)
      end
      if e.ai == 'windup' and (not e.attackSpec or e.attackSpec.warning ~= false) then
        local progress = 1 - e.windup / (e.windupDuration or 1)
        local step = math.min(2, math.floor(progress * 3))
        local radius = EnemyMarks.windup + step * EnemyMarks.windupStep
        HazardArt.circle(r, g, e, look.windupMark, radius, 1)
      end
      -- A leap marks its landing point from the crouch to the landing: the
      -- player always sees where the arc ends (dodgeable, never a surprise).
      -- The ring is the real reach: landing radius plus the knight's body.
      local spec = e.attackSpec
      if
        look.landingMark ~= false
        and spec
        and Action.trait(spec, 'lands')
        and (e.ai == 'windup' or e.leaping)
        and e.aimX
      then
        local reachLand = spec.landRadius + Characters.of(Context.actor(g)).body.radius
        landing.x, landing.z, landing.level = e.aimX, e.aimZ, e.aimLevel
        HazardArt.circle(r, g, landing, 'circle', reachLand * EnemyMarks.landing, 1)
      end
    end
  end
end
return Pass
