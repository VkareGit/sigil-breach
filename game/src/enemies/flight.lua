-- A body in the air (plan v10 V6: enemies/actions.lua split by
-- responsibility): a leap, or one knocked out of it, flies under world
-- gravity, its horizontal motion stopped by walls, until it lands.
local Signal = require('src.session.signal')
local Melee = require('src.combat.melee')
local BodyContact = require('src.combat.body_contact')
local Rules = require('src.combat.rules')
local Tuning = require('src.content.tuning')
local Kinematics = require('src.physics.kinematics')
local Bodies = require('src.combat.bodies')
local Flight = {}
-- A body meets the floor after a leap: low dust, a thud, a short tremor
-- felt only near the landing (presentation; the strike is resolved by the
-- attack kind).
function Flight.land(g, e, heavy)
  e.landings = (e.landings or 0) + 1
  Signal(g, 'Landed', { enemy = e, heavy = heavy })
end
-- Integrate a body in the air: world gravity, horizontal motion stopped by
-- walls, landing at y = 0. Returns whether it landed and the time it used.
function Flight.step(g, e, dt, previous)
  if e.leapY == nil then
    e.leaping = false
    return
  end
  local gravity = Tuning.gravity
  if g.world.elevations then
    local elapsed = 0
    -- Body contact sweeps the controlled knight by sub-step (moveEnemy).
    local p = Bodies.controlled(g)
    previous = previous or p
    while elapsed < dt do
      local landing = Kinematics.fallTime(e.leapY, e.leapVY, gravity)
      local step = math.min(dt - elapsed, landing)
      local from = Melee.playerAt(previous, p, elapsed / dt, nil, g.world)
      local current = Melee.playerAt(previous, p, (elapsed + step) / dt, nil, g.world)
      local vx, vz =
        BodyContact.moveEnemy(g, e, (e.leapVX or 0) * step, (e.leapVZ or 0) * step, from, current)
      if step > 0 then
        e.leapVX, e.leapVZ = (vx or 0) / step, (vz or 0) / step
      end
      local y = e.leapY + e.leapVY * step - 0.5 * gravity * step * step
      e.leapVY = e.leapVY - gravity * step
      if g.world.decks then
        -- A deck overhead stops the rise (plan v10 V3).
        y, e.leapVY = Rules.ceiling(g, e, y, e.leapVY)
      end
      elapsed = elapsed + step
      if y <= 0 then
        e.leapY, e.leapVY, e.leapVX, e.leapVZ, e.leaping = nil, 0, 0, 0, false
        return true, elapsed
      end
      e.leapY, e.leaping = y, true
      -- A former floor's landing time is only an integration boundary.
      -- Leaving its ledge rebased leapY; consume the remaining time over
      -- the new support instead of slowing the whole trajectory by a tick.
    end
    return false, elapsed
  end
  local landing = (e.leapVY + math.sqrt(e.leapVY * e.leapVY + 2 * gravity * e.leapY)) / gravity
  local step = math.min(dt, landing)
  local p = Bodies.controlled(g)
  local current = step < dt and Melee.playerAt(previous or p, p, step / dt) or p
  local vx, vz =
    BodyContact.moveEnemy(g, e, (e.leapVX or 0) * step, (e.leapVZ or 0) * step, previous, current)
  if step > 0 then
    e.leapVX, e.leapVZ = (vx or 0) / step, (vz or 0) / step
  end
  local y = e.leapY + e.leapVY * step - 0.5 * gravity * step * step
  e.leapVY = e.leapVY - gravity * step
  if (not g.world.elevations and dt >= landing) or y <= 0 then
    e.leapY, e.leapVY, e.leapVX, e.leapVZ, e.leaping = nil, 0, 0, 0, false
    return true, step
  end
  e.leapY, e.leaping = y, true
  return false, step
end
return Flight
