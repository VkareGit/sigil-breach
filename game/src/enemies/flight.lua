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
function Flight.land(g, e, heavy, attack)
  e.landings = (e.landings or 0) + 1
  Signal(g, 'Landed', { enemy = e, heavy = heavy, attack = attack })
end
-- The controlled knight at fraction t of this step (previous: where it stood
-- when the step began); exactly its own points at the ends.
local function knightAt(g, previous, p, t)
  if t <= 0 then
    return previous
  elseif t >= 1 then
    return p
  end
  return Melee.playerAt(previous, p, t, nil, g.world)
end
-- Integrate a body in the air: world gravity, horizontal motion stopped by
-- walls, landing on its floor. One path on every map (PLAN E2): the step
-- ends at the floor's landing time, and a move off a ledge that raised the
-- floor under the body only makes that time a boundary between sub-steps.
-- Returns whether it landed and the time it used.
function Flight.step(g, e, dt, previous)
  if e.leapY == nil then
    e.leaping = false
    return
  end
  local gravity = Tuning.gravity
  local elapsed = 0
  -- Body contact sweeps every knight by sub-step (moveEnemy).
  local p = Bodies.controlled(g)
  previous = previous or p
  while elapsed < dt do
    local landing = Kinematics.fallTime(e.leapY, e.leapVY, gravity)
    local step = math.min(dt - elapsed, landing)
    local from, to = elapsed / dt, (elapsed + step) / dt
    local before = e.leapY
    local vx, vz = BodyContact.moveEnemy(
      g,
      e,
      (e.leapVX or 0) * step,
      (e.leapVZ or 0) * step,
      knightAt(g, previous, p, from),
      knightAt(g, previous, p, to),
      from,
      to
    )
    if step > 0 then
      e.leapVX, e.leapVZ = (vx or 0) / step, (vz or 0) / step
    end
    local y
    y, e.leapVY = Kinematics.flight(e.leapY, e.leapVY, gravity, step)
    if g.world.decks then
      -- A deck overhead stops the rise (plan v10 V3).
      y, e.leapVY = Rules.ceiling(g, e, y, e.leapVY)
    end
    elapsed = elapsed + step
    if y <= 0 or (step >= landing and e.leapY == before) then
      e.leapY, e.leapVY, e.leapVX, e.leapVZ, e.leaping = nil, 0, 0, 0, false
      return true, elapsed
    end
    e.leapY, e.leaping = y, true
  end
  return false, elapsed
end
return Flight
