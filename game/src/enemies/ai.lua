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
local Selection = require('src.enemies.attack_selection')
local Hazards = require('src.enemies.hazards')
local Pools = require('src.session.world')
local Ground = require('src.physics.ground')
local Spatial = require('src.physics.spatial')
local Navigation = require('src.world.navigation')
local Bodies = require('src.combat.bodies')
local Target = require('src.enemies.target')
local ActionKinds = require('src.combat.action_kinds')
local Action = require('src.content.defs.action')
local AI = {}
-- Whom e fights now (enemies/target.lua): the knight by default; any body of
-- a hostile side when relations say so (plan v10 V2).
local target = Target.of
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
  e.lastLevel = e.level
  e.side = e.id % 2 == 0 and 1 or -1
  e.decision = 0
  e.recover = 0
  e.attackCount = 0
  e.walkSpeed = 0
  e.spawnAge = 1
  e.flinch = 0
end
-- level (optional): the surface the noise rose from, on a world with decks.
function AI.noise(g, x, z, r, level)
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.hp > 0 and len(e.x - x, e.z - z) < r then
      e.awake = true
      e.memory = 4
      e.lastX = x
      e.lastZ = z
      e.lastLevel = level
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
  local stage = Archetypes.phase(e)
  speed = speed * Rules.speedScale(e) * (e.tierSpeed or 1) * (stage and stage.speed or 1)
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
  local sx, sz = W.move(g.world, e, vx * dt, vz * dt, radius(e), nil, Rules.tall(g, e))
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
-- level (optional): the surface of the goal on a world with decks; the route
-- runs over the walk graph's nodes (cells, and decks above them).
local function route(g, e, tx, tz, dt, level)
  local w = g.world
  local tall = Rules.tall(g, e)
  if
    W.visible(w, e.x, e.z, tx, tz, nil, nil, e.level, level)
    and (not w.elevations or W.clear(w, e.x, e.z, tx, tz, radius(e), e.level, tall, level))
  then
    move(g, e, tx, tz, e.speed, dt)
    return
  end
  local class = W.class(radius(e), tall)
  e.pathTimer = (e.pathTimer or 0) - dt
  if e.pathTimer <= 0 or not e.path then
    e.path = W.flow(w, tx, tz, class, level)
    e.pathTimer = Walk.replan
  end
  -- The next node down the distance field from a node (nil at the goal).
  local function downhill(x, z, layer)
    local here = w.decks and W.level(w, x, z, layer)
    local best, bx, bz, bl = e.path[W.node(w, x, z, layer)] or 1e9, nil, nil, nil
    for _, o in ipairs(steps) do
      local nx, nz = x + o[1], z + o[2]
      local nl = 0
      if here then
        nl = W.step(w, nx, nz, here, class)
      end
      local d = nl and e.path[W.node(w, nx, nz, nl)]
      if d and d < best and not W.solid(w, nx, nz, radius(e)) then
        best = d
        bx, bz, bl = nx, nz, nl
      end
    end
    return bx, bz, bl
  end
  -- Walk toward the furthest cell of the route the body can reach in a
  -- straight line (0.25): no zigzag from cell centre to cell centre.
  local x, z = math.floor(e.x + 0.5), math.floor(e.z + 0.5)
  local layer = w.decks and W.layer(w, x, z, Ground.of(w, e) - (w.floor or 0)) or 0
  local bx, bz, bl = downhill(x, z, layer)
  if not bx then
    -- Beyond the exact field around the goal (plan v10 V3): cross region by
    -- region toward it (world/navigation.lua).
    if Navigation.beyond(e.x, e.z, tx, tz) then
      local wx, wz = Navigation.waypoint(w, e.x, e.z, tx, tz, class, e.level, level)
      if wx then
        move(g, e, wx, wz, e.speed, dt)
      end
    end
    return
  end
  local cx, cz, cl = bx, bz, bl
  for _ = 2, Walk.lookahead do
    cx, cz, cl = downhill(cx, cz, cl)
    if
      not cx
      or not W.clear(
        w,
        e.x,
        e.z,
        cx,
        cz,
        radius(e),
        e.level,
        tall,
        w.decks and W.level(w, cx, cz, cl) + (w.floor or 0)
      )
    then
      break
    end
    bx, bz = cx, cz
  end
  move(g, e, bx, bz, e.speed, dt)
end
-- Attack slots and spacing belong to the body attacked: the controlled
-- knight's pacing is g.nextAttack, any other body's g.attackPacing[id].
local function reserveAttack(g, e)
  local max = Rules.maxAttackers(e)
  local count = 0
  for _, other in ipairs(Pools.of(g, 'enemies')) do
    if
      other.hp > 0
      and (other.ai == 'windup' or other.ai == 'strike')
      and other.target == e.target
    then
      count = count + 1
    end
  end
  local victim = target(g, e)
  local controlled = victim == Bodies.controlled(g)
  local pacing = g.attackPacing
  local next = controlled and (g.nextAttack or 0) or (pacing and pacing[victim.id] or 0)
  if count >= max or next > g.elapsed then
    return false
  end
  local at = g.elapsed + Archetypes.defaults.tiers.spacing / Selection.pace(e)
  if controlled then
    g.nextAttack = at
  else
    g.attackPacing = pacing or {}
    g.attackPacing[victim.id] = at
  end
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
  e.evadeReady = spec.cooldown / (e.tierPace or 1)
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
AI.styles = Styles
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
-- On a world with decks, whether body e and body p stand on floors a step
-- cannot join (one on a deck, one under it): then e follows its routes, not
-- a straight approach (plan v10 V3).
function AI.apart(g, e, p)
  if not g.world.decks then
    return false
  end
  return math.abs(Ground.of(g.world, e) - Ground.of(g.world, p)) > (g.world.stepHeight or 0)
end
local function approach(g, e, d, dt)
  local name = arch(e).move.style
  local style = Styles[name]
  assert(type(style) == 'function', 'unknown movement style ' .. tostring(name))
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
    and (
      e.ai ~= 'strike'
      or (g.world.elevations and e.attackSpec and not Action.trait(e.attackSpec, 'airborne'))
    )
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
  else
    -- The shove is over: so is its owner's claim on a slam (plan v11 E3d).
    e.pushOwner = nil
  end
  return true
end

-- Senses: sight on a short clock, memory of the last sighting, facing. The
-- sight clock also renews whom it fights (never during a committed attack).
-- Returns the distance to that body (renewed when the choice changed).
local function perceive(g, e, d, dt)
  local p = target(g, e)
  e.sense = e.sense - dt
  if e.sense <= 0 then
    if e.ai ~= 'windup' and e.ai ~= 'strike' then
      local chosen = Target.choose(g, e)
      if chosen ~= p then
        p = chosen
        d = len(p.x - e.x, p.z - e.z)
      end
    end
    e.visible = Rules.sees(g, e, p)
    e.sense = Senses.interval + e.id % 3 * Senses.stagger
    if e.visible and d < Senses.alertRange then
      if not e.awake then
        Signal(g, 'Alerted', { enemy = e })
      end
      e.awake = true
      e.memory = Senses.memory
      e.lastX = p.x
      e.lastZ = p.z
      e.lastLevel = p.level
    end
  end
  if not e.visible then
    e.memory = math.max(0, e.memory - dt)
  end
  local target = atan2(e.lastX - e.x, e.lastZ - e.z)
  if e.ai == 'windup' or e.ai == 'strike' then
    target = atan2(e.aimX - e.x, e.aimZ - e.z)
  end
  local rate = arch(e).move.turn
  local committed = e.ai == 'windup' or e.ai == 'strike'
  if committed and (rate or (e.attackSpec and e.attackSpec.turn)) then
    -- The blow turns the body itself (enemies/actions.lua: track).
    rate = 0
  elseif not rate then
    e.facing = e.facing + angle(target - e.facing) * (1 - math.exp(-dt * Senses.turnRate))
  else
    local off = angle(target - e.facing)
    e.facing = e.facing + math.max(-rate * dt, math.min(rate * dt, off))
  end
  if e.awake and d < Senses.threatRange then
    g.threat = g.threat + (arch(e).threat or 1)
  end
  return d
end

-- Intent (0.24, State): one handler per state of the state machine
-- idle -> move -> windup -> strike -> recover, with hurt from the rules.
-- A state not listed here (idle, move, recover, hurt) is 'free': it recovers
-- or chooses what to do next. A new state is a new entry.
local States = {}
AI.states = States
-- The telegraph runs out: release the attack, or cancel it for real.
function States.windup(g, e, d, dt)
  local p = target(g, e)
  Attacks.track(g, e, Attacks.current(e), dt)
  e.windup = math.max(0, e.windup - dt)
  if e.windup > 0 then
    return
  end
  -- A held blow: the windup is over and the body stays, frozen in it.
  if (e.holdLeft or 0) > 0 then
    e.holdLeft = e.holdLeft - dt
    return
  end
  -- Geometry can invalidate a committed target (the predicted point hides
  -- behind a pillar). Before giving up, a body-delivered attack takes the
  -- player's present position if that is in sight; a marked ground strike
  -- never moves its telegraph. No shooting through a wall.
  local defaults = Archetypes.defaults
  local spec = Attacks.current(e)
  -- A turning blow goes where the body came to face, whatever stands there.
  if spec.turn then
    change(e, 'strike')
    Attacks.execute(g, e)
    return
  end
  if
    not Attacks.kindOf(spec).unseen
    and not Rules.sees(g, e, p, e.aimX, e.aimZ)
    and Rules.sees(g, e, p)
  then
    e.aimX, e.aimZ, e.aimLevel = p.x, p.z, p.level
    g.retargets = (g.retargets or 0) + 1
  end
  if Rules.sees(g, e, p, e.aimX, e.aimZ) then
    change(e, 'strike')
    Attacks.execute(g, e)
    return
  end
  -- A real cancel: a longer pause and a new flank, so a blocked body
  -- repositions instead of looping crouch-cancel-crouch.
  ActionKinds.abandon(e)
  change(e, 'recover')
  Selection.clear(e)
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
  if e.chain and Attacks.flow(g, e, d) then
    return
  end
  if e.recover > 0 then
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
  elseif not e.visible or AI.apart(g, e, target(g, e)) then
    route(g, e, e.lastX, e.lastZ, dt, e.lastLevel)
  else
    approach(g, e, d, dt)
  end
end

-- One pair, as the rules part it: true when they overlapped and moved.
local function part(g, a, b, dt, S)
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
    W.move(g.world, a, dx / d * ga, dz / d * ga, radius(a), nil, Rules.tall(g, a))
    W.move(g.world, b, -dx / d * gb, -dz / d * gb, radius(b), nil, Rules.tall(g, b))
    return true
  end
  return false
end
-- Scratch of the indexed pass (rebuilt by every call, never kept between).
local hash, order, near = Spatial.new(1), {}, {}
-- The neighbours of a that come after `after` in the pool, in pool order.
local function gather(a, reach, after)
  for i = #near, 1, -1 do
    near[i] = nil
  end
  hash:query(a.x, a.z, reach, near)
  local n = 0
  for i = 1, #near do
    local b = near[i]
    if order[b] > after then
      n = n + 1
      near[n] = b
    end
  end
  for i = #near, n + 1, -1 do
    near[i] = nil
  end
  -- Insertion sort by pool order: neighbour lists are short.
  for i = 2, n do
    local b, k = near[i], order[near[i]]
    local j = i - 1
    while j >= 1 and order[near[j]] > k do
      near[j + 1] = near[j]
      j = j - 1
    end
    near[j + 1] = b
  end
  return near
end
-- Living bodies never overlap: resolve full overlaps symmetrically,
-- including identical spawn coordinates. Every pair in pool order (each a,
-- then every later b), as it always was; a spatial index (plan v10 V3)
-- skips only pairs too far apart to touch. A body that moves farther than
-- the margin during its own pass gathers its neighbours again, so the
-- result equals the pass over every pair.
local function separate(g, dt)
  local S = Archetypes.defaults.separation
  local bodies = Pools.of(g, 'enemies')
  local reach = S.minimum
  for _, e in ipairs(bodies) do
    if e.hp > 0 then
      reach = math.max(reach, 2 * radius(e))
    end
  end
  local margin = S.margin
  if hash.size ~= reach + margin then
    hash = Spatial.new(reach + margin)
  else
    hash:clear()
  end
  for e in pairs(order) do
    order[e] = nil
  end
  for i, e in ipairs(bodies) do
    order[e] = i
    if e.hp > 0 then
      hash:insert(e, e.x, e.z)
    end
  end
  for i, a in ipairs(bodies) do
    if a.hp > 0 then
      local list = gather(a, reach + margin, i)
      local ax, az = a.x, a.z
      local k = 1
      while k <= #list do
        local b = list[k]
        if part(g, a, b, dt, S) then
          hash:move(a, a.x, a.z)
          hash:move(b, b.x, b.z)
          if len(a.x - ax, a.z - az) > margin then
            -- Its later neighbours, from where it stands now.
            list = gather(a, reach + margin, order[b])
            ax, az, k = a.x, a.z, 0
          end
        end
        k = k + 1
      end
    end
  end
end

-- Every demon, one after another, through its own pipeline: body, senses,
-- state. (Per demon, not per stage: the interleaving is part of the rules.)
function AI.demons(g, dt, previousPlayer)
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
      local p = target(g, e)
      local d = perceive(g, e, len(p.x - e.x, p.z - e.z), dt)
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
