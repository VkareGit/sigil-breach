-- How a creature closes on what it fights while it waits for a blow. The archetype names its
-- style (move.style); a new style is a new entry here.
local Archetypes = require('src.content.enemies')
local MathX = require('src.core.mathx')
local W = require('src.world.arena')
local Rules = require('src.combat.rules')
local Signal = require('src.session.signal')
local Target = require('src.enemies.target')
local Walking = require('src.enemies.walking')
local target = Target.of
local sin, cos, atan2 = math.sin, math.cos, math.atan2
local len = MathX.len
local angle = MathX.wrapAngle
local radius = Rules.radius
local move = Walking.move
local Senses = Archetypes.defaults.senses
local function arch(e)
  return Rules.archetype(e)
end
-- Movement styles: 'flank' closes in and circles at claw range; 'keep' holds
-- an ideal distance and strafes, switching side from time to time.
-- Evasion (archetype data move.evade, unlocked by tier): when the player's
-- aim rests on the body, a short sidestep away from the aim line.
local function evade(g, e, d, dt)
  local spec = (arch(e).move or {}).evade
  if not spec then
    return false
  end
  e.evadeReady = math.max(0, (e.evadeReady or 0) - dt)
  if (e.evadeTime or 0) > 0 then
    e.evadeTime = e.evadeTime - dt
    local step = spec.speed * dt
    local ox, oz = e.x, e.z
    W.move(g.world, e, e.evadeX * step, e.evadeZ * step, radius(e), nil, Rules.tall(g, e))
    e.walk = e.walk + len(e.x - ox, e.z - oz)
    return true
  end
  -- It sidesteps the aim of the body it fights; a body that does not aim
  -- (a creature) gives it nothing to read.
  local p = target(g, e)
  if e.evadeReady > 0 or not e.visible or d > Senses.evadeRange or not p.yaw then
    return false
  end
  local toward = atan2(e.x - p.x, e.z - p.z)
  local off = angle(toward - p.yaw)
  if math.abs(off) > spec.cone then
    return false
  end
  -- Step to the side the aim is already furthest from.
  local side = off >= 0 and 1 or -1
  e.evadeX, e.evadeZ = cos(toward) * side, -sin(toward) * side
  e.evadeTime = spec.time
  e.evadeSide = side
  e.evadeReady = spec.cooldown
  Signal(g, 'Evaded', { enemy = e })
  e.evades = (e.evades or 0) + 1
  g.evadeCount = (g.evadeCount or 0) + 1
  return true
end
-- Movement styles (0.24, Strategy): how a body closes on the player while it
-- waits for an attack. The archetype names its style (move.style); a new
-- style is a new entry here. Session composition validates the names before
-- a world is built; an explicit unknown name is never a request for 'keep'.
local Styles = {}
-- 'flank' closes in and circles at claw range.
function Styles.flank(g, e, d, dt)
  local p = target(g, e)
  local a = atan2(e.x - p.x, e.z - p.z)
  local F = Archetypes.defaults.flank
  if d > F.far then
    move(g, e, p.x + cos(a) * e.side * F.lateral, p.z - sin(a) * e.side * F.lateral, e.speed, dt)
  elseif d <= F.near then
    -- Too close and waiting for an attack slot: step aside around the player
    -- instead of standing frozen against them.
    local side = a + e.side * F.swing
    local tx, tz = p.x + sin(side) * F.step, p.z + cos(side) * F.step
    if not W.solid(g.world, tx, tz, radius(e)) then
      move(g, e, tx, tz, e.speed * F.slow, dt)
    end
  else
    local offset = e.side * F.orbit
    local tx, tz = p.x + sin(a + offset) * F.ring, p.z + cos(a + offset) * F.ring
    if W.solid(g.world, tx, tz, radius(e)) then
      tx, tz = p.x, p.z
    end
    move(g, e, tx, tz, e.speed, dt)
  end
end
-- 'keep' holds an ideal distance and strafes, switching side from time to time.
function Styles.keep(g, e, d, dt)
  local p = target(g, e)
  local K = Archetypes.defaults.keep
  e.decision = e.decision - dt
  if e.decision <= 0 then
    e.side = -e.side
    e.decision = K.hold + (e.id % 3) * K.holdStep
  end
  local dx, dz = (p.x - e.x) / math.max(K.minDistance, d), (p.z - e.z) / math.max(K.minDistance, d)
  local stage = Archetypes.phase(e)
  local ideal = stage and stage.ideal or arch(e).move.ideal
  local radial = d < ideal - K.slack and -1 or (d > ideal + K.slack and 1 or 0)
  local tx, tz =
    e.x + dx * radial + dz * e.side * K.strafe, e.z + dz * radial - dx * e.side * K.strafe
  move(g, e, tx, tz, e.speed * (radial == 0 and K.holdSpeed or 1), dt)
end
-- 'duel' fights one body at a time: between its blows it walks around, comes in,
-- gives ground or stands and watches, each for a moment, never the same dance.
function Styles.duel(g, e, d, dt)
  local p = target(g, e)
  local spec = arch(e).move
  local D = spec.duel
  e.duelLeft = (e.duelLeft or 0) - dt
  if e.duelLeft <= 0 then
    local rng = g.rng.sim
    local roll = rng:random() * (D.circle + D.close + D.back + D.wait)
    e.duelMove = roll < D.circle and 'circle'
      or (
        roll < D.circle + D.close and 'close'
        or (roll < D.circle + D.close + D.back and 'back' or 'wait')
      )
    e.duelLeft = D.hold + rng:random() * D.spread
    e.side = rng:random() < 0.5 and 1 or -1
  end
  local K = Archetypes.defaults.duel
  local dx, dz = (p.x - e.x) / math.max(K.nearest, d), (p.z - e.z) / math.max(K.nearest, d)
  local stage = Archetypes.phase(e)
  local ideal = stage and stage.ideal or spec.ideal
  if d > ideal + D.far then
    move(g, e, p.x, p.z, e.speed, dt)
  elseif e.duelMove == 'close' then
    move(g, e, p.x, p.z, e.speed * K.closing, dt)
  elseif e.duelMove == 'back' then
    move(g, e, e.x - dx * K.step, e.z - dz * K.step, e.speed * K.giving, dt)
  elseif e.duelMove == 'circle' then
    local radial = (d - ideal) * K.pull
    move(
      g,
      e,
      e.x + dz * e.side * K.step + dx * radial,
      e.z - dx * e.side * K.step + dz * radial,
      e.speed * K.circling,
      dt
    )
  end
end
-- The sidestep is asked for before a style moves the body.
return { styles = Styles, evade = evade }
