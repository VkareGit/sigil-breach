-- Enemy intent, movement and animation share one explicit state machine.
-- Everything a creature can do is read from its archetype (src/content/enemies.lua):
-- movement style, attack list, timings and damage packets. Adding a demon
-- means adding data; this file only knows attack KINDS, never demon names.
local Signal = require('src.session.signal')
local MathX = require('src.core.mathx')
local W = require('src.world.arena')
local Rules = require('src.combat.rules')
local Body = require('src.enemies.body')
local Attacks = require('src.enemies.actions')
local Hazards = require('src.enemies.hazards')
local Pools = require('src.session.world')
local AI = {}
local sin, cos, sqrt, atan2 = math.sin, math.cos, math.sqrt, math.atan2
local len = MathX.len
local angle = MathX.wrapAngle
local function arch(e)
  return Rules.archetype(e)
end
-- Keep the environmental footprint invariant across walking, impulses,
-- crowd separation and attacks; changing it at charge start causes a pop.
local radius = Rules.radius
AI.radius = radius
function AI.init(e)
  e.ai = 'idle'
  e.phase = 0
  e.poise = 0
  e.staggerLock = 0
  e.hitPause = 0
  e.facing = math.pi
  e.sense = 0
  e.memory = 0
  e.lastX = e.x
  e.lastZ = e.z
  e.side = e.id % 2 == 0 and 1 or -1
  e.decision = 0
  e.recover = 0
  e.attackCount = 0
  e.walkSpeed = 0
  e.spawnAge = 1
  e.flinch = 0
end
function AI.noise(g, x, z, r)
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.hp > 0 and len(e.x - x, e.z - z) < r then
      e.awake = true
      e.memory = 4
      e.lastX = x
      e.lastZ = z
    end
  end
end
-- Bosses keep their guard: a stagger never cancels their committed attack.
AI.interrupt = Rules.interrupt
AI.hazard = Hazards.add
local function change(e, state)
  e.ai = state
  e.phase = 0
end
-- Walking is physical (0.21): the body accelerates toward its walking
-- velocity at accel / sqrt(mass), so heavy demons start and turn later and
-- a knocked body regains its stride. Arrival slows within braking distance.
local Archetypes = require('src.content.enemies')
local Walk = Archetypes.defaults.walk
local Senses = Archetypes.defaults.senses
local function move(g, e, tx, tz, speed, dt)
  local dx, dz = tx - e.x, tz - e.z
  local d = len(dx, dz)
  if d < Walk.arrive then
    return
  end
  dx, dz = dx / d, dz / d
  local defaults = Archetypes.defaults
  local accel = ((arch(e).move or {}).accel or defaults.accel) / math.sqrt(Rules.body(e).mass or 1)
  speed = speed * Rules.speedScale(e) * (e.tierSpeed or 1)
  speed = math.min(speed, math.sqrt(2 * accel * defaults.brake * d))
  -- A body that stopped walking (attack, stagger, idle) starts again at rest.
  local now = g.elapsed or 0
  local vx, vz = e.walkVX or 0, e.walkVZ or 0
  if not e.walkAt or now - e.walkAt > dt * Walk.resume then
    vx, vz = 0, 0
  end
  e.walkAt = now
  local ax, az = dx * speed - vx, dz * speed - vz
  local al = len(ax, az)
  local rate = accel * ((vx * dx + vz * dz) < 0 and defaults.brake or 1)
  if al > 0 then
    local step = math.min(al, rate * dt)
    vx, vz = vx + ax / al * step, vz + az / al * step
  end
  local ox, oz = e.x, e.z
  local sx, sz = W.move(g.world, e, vx * dt, vz * dt, radius(e))
  e.walkVX, e.walkVZ = (sx or 0) / dt, (sz or 0) / dt
  local moved = len(e.x - ox, e.z - oz)
  e.walk = e.walk + moved
  e.walkSpeed = moved / math.max(dt, 0.001)
  if moved < speed * dt * Walk.stuckShare then
    e.blocked = (e.blocked or 0) + dt
  else
    e.blocked = 0
  end
  if (e.blocked or 0) > Walk.stuckTime then
    e.side = -e.side
    e.decision = Walk.sideHold
    e.blocked = 0
  end
end
-- The four neighbouring cells a route may step to, in the order they are tried.
local steps = { { 0, -1 }, { 0, 1 }, { 1, 0 }, { -1, 0 } }
local function route(g, e, tx, tz, dt)
  if
    W.visible(g.world, e.x, e.z, tx, tz)
    and (not g.world.elevations or W.clear(g.world, e.x, e.z, tx, tz, radius(e)))
  then
    move(g, e, tx, tz, e.speed, dt)
    return
  end
  e.pathTimer = (e.pathTimer or 0) - dt
  if e.pathTimer <= 0 or not e.path then
    e.path = W.flow(g.world, tx, tz)
    e.pathTimer = Walk.replan
  end
  -- The next cell down the distance field from a cell (nil at the goal).
  local function downhill(x, z)
    local best, bx, bz = e.path[z * g.world.size + x] or 1e9, nil, nil
    for _, o in ipairs(steps) do
      local nx, nz = x + o[1], z + o[2]
      local d = e.path[nz * g.world.size + nx]
      if d and d < best and not W.solid(g.world, nx, nz, radius(e)) then
        best = d
        bx, bz = nx, nz
      end
    end
    return bx, bz
  end
  -- Walk toward the furthest cell of the route the body can reach in a
  -- straight line (0.25): no zigzag from cell centre to cell centre.
  local x, z = math.floor(e.x + 0.5), math.floor(e.z + 0.5)
  local bx, bz = downhill(x, z)
  if not bx then
    return
  end
  local cx, cz = bx, bz
  for _ = 2, Walk.lookahead do
    cx, cz = downhill(cx, cz)
    if not cx or not W.clear(g.world, e.x, e.z, cx, cz, radius(e)) then
      break
    end
    bx, bz = cx, cz
  end
  move(g, e, bx, bz, e.speed, dt)
end
local function reserveAttack(g, e)
  local max = Rules.maxAttackers(e)
  local count = 0
  for _, other in ipairs(Pools.of(g, 'enemies')) do
    if other.hp > 0 and (other.ai == 'windup' or other.ai == 'strike') then
      count = count + 1
    end
  end
  if count >= max or (g.nextAttack or 0) > g.elapsed then
    return false
  end
  g.nextAttack = g.elapsed + Archetypes.defaults.tiers.spacing / (e.tierPace or 1)
  return true
end
-- Movement styles: 'flank' closes in and circles at claw range; 'keep' holds
-- an ideal distance and strafes, switching side from time to time.
-- Evasion (archetype data move.evade, unlocked by tier): when the player's
-- aim rests on the body, a short sidestep away from the aim line.
local function evade(g, e, d, dt)
  local spec = (arch(e).move or {}).evade
  if not spec or (e.tier or 1) < spec.fromTier then
    return false
  end
  e.evadeReady = math.max(0, (e.evadeReady or 0) - dt)
  if (e.evadeTime or 0) > 0 then
    e.evadeTime = e.evadeTime - dt
    local step = spec.speed * dt
    local ox, oz = e.x, e.z
    W.move(g.world, e, e.evadeX * step, e.evadeZ * step, radius(e))
    e.walk = e.walk + len(e.x - ox, e.z - oz)
    return true
  end
  local p = g.player
  if e.evadeReady > 0 or not e.visible or d > Senses.evadeRange then
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
  e.evadeReady = spec.cooldown / (e.tierPace or 1)
  Signal(g, 'Evaded', { enemy = e })
  e.evades = (e.evades or 0) + 1
  g.evadeCount = (g.evadeCount or 0) + 1
  return true
end
-- Movement styles (0.24, Strategy): how a body closes on the player while it
-- waits for an attack. The archetype names its style (move.style); a new
-- style is a new entry here. tests/cases/content_schema.lua checks the names.
local Styles = {}
AI.styles = Styles
-- 'flank' closes in and circles at claw range.
function Styles.flank(g, e, d, dt)
  local p = g.player
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
  local p = g.player
  local K = Archetypes.defaults.keep
  e.decision = e.decision - dt
  if e.decision <= 0 then
    e.side = -e.side
    e.decision = K.hold + (e.id % 3) * K.holdStep
  end
  local dx, dz = (p.x - e.x) / math.max(K.minDistance, d), (p.z - e.z) / math.max(K.minDistance, d)
  local ideal = arch(e).move.ideal
  local radial = d < ideal - K.slack and -1 or (d > ideal + K.slack and 1 or 0)
  local tx, tz =
    e.x + dx * radial + dz * e.side * K.strafe, e.z + dz * radial - dx * e.side * K.strafe
  move(g, e, tx, tz, e.speed * (radial == 0 and K.holdSpeed or 1), dt)
end
local function approach(g, e, d, dt)
  local style = Styles[arch(e).move.style] or Styles.keep
  style(g, e, d, dt)
end

-- The body itself, whatever its intent: timers, conditions, guard recovery,
-- flight, fall, and the shove it is carrying.
local function tickBody(g, e, dt, paused)
  local defaults = Archetypes.defaults
  if not paused then
    e.phase = (e.phase or 0) + dt
  end
  e.spawnAge = (e.spawnAge or 1) + dt
  e.hit = math.max(0, e.hit - dt)
  e.walkSpeed = 0
  e.flinch = math.max(0, (e.flinch or 0) - dt * defaults.flinch.decay)
  e.woundFlash = math.max(0, (e.woundFlash or 0) - dt)
  e.breakFlash = math.max(0, (e.breakFlash or 0) - dt)
  Rules.tick(e, dt)
  Body.recover(e, dt)
  -- A body in the air keeps flying whatever its state: a leap shot out of
  -- the sky falls and lands knocked down (the painted fall).
  if
    e.hp > 0
    and e.leapY ~= nil
    and (e.ai ~= 'strike' or (g.world.elevations and e.attackSpec and e.attackSpec.kind ~= 'leap'))
  then
    if Attacks.flight(g, e, dt) then
      Attacks.land(g, e, true)
      if e.ai == 'hurt' then
        Rules.knockDown(e)
      end
    end
  end
  if e.hp <= 0 then
    e.leapY = nil
    e.pendingHazard = nil
    Body.fall(g, e, dt)
    e.deathTime = e.deathTime + dt
    return false
  end
  e.stun = math.max(0, e.stun - dt)
  if e.stun == 0 then
    e.knockedDown, e.heavyStagger = nil, nil
  end
  Rules.recover(e, dt, Rules.body(e))
  e.staggerLock = math.max(0, (e.staggerLock or 0) - dt)
  e.hitPause = math.max(0, (e.hitPause or 0) - dt)
  e.attack = e.attack - dt
  if not paused then
    e.recover = math.max(0, (e.recover or 0) - dt)
  end
  if math.abs(e.pushX) + math.abs(e.pushZ) > Walk.minPush then
    Body.push(g, e, dt, Rules.body(e).drag or defaults.drag)
  end
  return true
end

-- Senses: sight on a short clock, memory of the last sighting, facing.
local function perceive(g, e, d, dt)
  local p = g.player
  e.sense = e.sense - dt
  if e.sense <= 0 then
    e.visible = Rules.seesKnight(g, e)
    e.sense = Senses.interval + e.id % 3 * Senses.stagger
    if e.visible and d < Senses.alertRange then
      if not e.awake then
        Signal(g, 'Alerted', { enemy = e })
      end
      e.awake = true
      e.memory = Senses.memory
      e.lastX = p.x
      e.lastZ = p.z
    end
  end
  if not e.visible then
    e.memory = math.max(0, e.memory - dt)
  end
  local target = atan2(e.lastX - e.x, e.lastZ - e.z)
  if e.ai == 'windup' or e.ai == 'strike' then
    target = atan2(e.aimX - e.x, e.aimZ - e.z)
  end
  e.facing = e.facing + angle(target - e.facing) * (1 - math.exp(-dt * Senses.turnRate))
  if e.awake and d < Senses.threatRange then
    g.threat = g.threat + (arch(e).threat or 1)
  end
end

-- Intent (0.24, State): one handler per state of the state machine
-- idle -> move -> windup -> strike -> recover, with hurt from the rules.
-- A state not listed here (idle, move, recover, hurt) is 'free': it recovers
-- or chooses what to do next. A new state is a new entry.
local States = {}
AI.states = States
-- The telegraph runs out: release the attack, or cancel it for real.
function States.windup(g, e, d, dt)
  local p = g.player
  e.windup = math.max(0, e.windup - dt)
  if e.windup > 0 then
    return
  end
  -- Geometry can invalidate a committed target (the predicted point hides
  -- behind a pillar). Before giving up, a body-delivered attack takes the
  -- player's present position if that is in sight; a marked ground strike
  -- never moves its telegraph. No shooting through a wall.
  local defaults = Archetypes.defaults
  local spec = Attacks.current(e)
  if
    not Attacks.kindOf(spec).unseen
    and not Rules.seesKnight(g, e, e.aimX, e.aimZ)
    and Rules.seesKnight(g, e)
  then
    e.aimX, e.aimZ = p.x, p.z
    g.retargets = (g.retargets or 0) + 1
  end
  if Rules.seesKnight(g, e, e.aimX, e.aimZ) then
    change(e, 'strike')
    Attacks.execute(g, e)
    return
  end
  -- A real cancel: a longer pause and a new flank, so a blocked body
  -- repositions instead of looping crouch-cancel-crouch.
  if e.pendingHazard then
    e.pendingHazard.cancelled = true
    e.pendingHazard = nil
  end
  change(e, 'recover')
  e.recover = defaults.interruptRecover
  e.attack = defaults.cancelPause / (e.tierPace or 1)
  e.side = -e.side
  e.decision = Walk.sideHold
  g.cancelledAttacks = (g.cancelledAttacks or 0) + 1
  Signal(g, 'AttackCancelled', { enemy = e })
end
function States.strike(g, e, _, dt, previousPlayer)
  Attacks.strike(g, e, dt, previousPlayer)
end
-- Free: recovering, or choosing between an attack, a sidestep and moving.
local function free(g, e, d, dt)
  if e.recover > 0 then
    if e.ai ~= 'hurt' then
      e.ai = 'recover'
    end
    return
  end
  if not (e.awake and (e.memory > 0 or e.visible)) then
    e.ai = 'idle'
    e.awake = false
    return
  end
  e.ai = 'move'
  local chosen = e.visible and e.attack <= 0 and Attacks.choose(e, d, g.elapsed)
  if chosen and reserveAttack(g, e) then
    Attacks.begin(g, e, d, chosen)
  elseif evade(g, e, d, dt) then
    -- sidestepping out of the player's aim
  elseif not e.visible then
    route(g, e, e.lastX, e.lastZ, dt)
  else
    approach(g, e, d, dt)
  end
end

-- Living bodies never overlap: resolve full overlaps symmetrically,
-- including identical spawn coordinates.
local function separate(g, dt)
  local S = Archetypes.defaults.separation
  local bodies = Pools.of(g, 'enemies')
  for i, a in ipairs(bodies) do
    if a.hp > 0 then
      for j = i + 1, #bodies do
        local b = bodies[j]
        local dx, dz = a.x - b.x, a.z - b.z
        local d = len(dx, dz)
        local minimum = math.max(S.minimum, radius(a) + radius(b))
        -- Footprints first: heights are compared only for bodies that touch.
        if b.hp > 0 and d < minimum and Rules.bodiesOverlap(g, a, b) then
          local overlap = minimum - d
          if d < 0.001 then
            dx, dz, d = 1, 0, 1
          end
          -- The parting is shared by the masses (0.25): the lighter body
          -- gives way more; equal bodies part equally.
          local amount = math.min(S.step, dt * S.rate, overlap * S.share)
          local ma, mb = Rules.body(a).mass or 1, Rules.body(b).mass or 1
          local ga, gb = 2 * amount * mb / (ma + mb), 2 * amount * ma / (ma + mb)
          W.move(g.world, a, dx / d * ga, dz / d * ga, radius(a))
          W.move(g.world, b, -dx / d * gb, -dz / d * gb, radius(b))
        end
      end
    end
  end
end

-- Every demon, one after another, through its own pipeline: body, senses,
-- state. (Per demon, not per stage: the interleaving is part of the rules.)
function AI.demons(g, dt, previousPlayer)
  local p = g.player
  g.threat = 0
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    -- A training dummy (proving-ground station) keeps its physics but never
    -- decides, walks or attacks; stun, hit-stop, a perfect-dodge freeze and
    -- the climb out of a portal pause the intent too.
    local paused = e.hp > 0
      and (
        e.dummy
        or e.stun > 0
        or e.hitPause > 0
        or g.impactSlow > 0
        or e.spawnAge < Archetypes.defaults.spawnPause
      )
    if tickBody(g, e, dt, paused) then
      local d = len(p.x - e.x, p.z - e.z)
      perceive(g, e, d, dt)
      if not paused then
        local handler = States[e.ai] or free
        handler(g, e, d, dt, previousPlayer)
      end
    end
  end
end
AI.separate = separate
-- The whole demon step (tests and tools call this; the session runs the same
-- three systems from src/systems in this order).
function AI.update(g, dt, previousPlayer)
  if type(dt) ~= 'number' or dt ~= dt or dt <= 0 or dt == math.huge then
    return
  end
  AI.demons(g, dt, previousPlayer)
  separate(g, dt)
  Hazards.update(g, dt, previousPlayer)
end
return AI
