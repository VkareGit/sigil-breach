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
local Separation = require('src.enemies.separation')
local Walking = require('src.enemies.walking')
local Bodies = require('src.combat.bodies')
local Target = require('src.enemies.target')
local ActionKinds = require('src.combat.action_kinds')
local Action = require('src.content.defs.action')
local Answers = require('src.enemies.answers')
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
local Archetypes = require('src.content.enemies')
local Walk = Archetypes.defaults.walk
local Senses = Archetypes.defaults.senses
-- level (optional): the surface the noise rose from, on a world with decks.
function AI.noise(g, x, z, r, level)
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    -- A body at its post hears only what is near it: one shot is not the whole chapel.
    local heard = e.alertRange and math.min(r, e.alertRange) or r
    if e.hp > 0 and len(e.x - x, e.z - z) < heard then
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
local move, route = Walking.move, Walking.route
-- Attack slots and spacing belong to the body attacked: the controlled
-- knight's pacing is g.nextAttack, any other body's g.attackPacing[id]. An answer (urgent)
-- skips the spacing but not the cap, so a reload is not met by the whole pack at once.
-- Whether every slot at the body e fights is taken.
local function crowded(g, e)
  local max = Rules.maxAttackers(e)
  local count = 0
  for _, other in ipairs(Pools.of(g, 'enemies')) do
    if
      other ~= e
      and other.hp > 0
      -- The connecting beat is still the same commitment. Releasing its
      -- slot here lets a newcomer enter before the next blow resumes.
      and (other.ai == 'windup' or other.ai == 'strike' or (other.ai == 'recover' and other.chain ~= nil))
      and other.target == e.target
    then
      count = count + 1
    end
  end
  return count >= max
end
local function reserveAttack(g, e, urgent)
  local victim = target(g, e)
  local controlled = victim == Bodies.controlled(g)
  local pacing = g.attackPacing
  local next = controlled and (g.nextAttack or 0) or (pacing and pacing[victim.id] or 0)
  if crowded(g, e) or (next > g.elapsed and not urgent) then
    return false
  end
  local at = g.elapsed + Archetypes.defaults.attackSpacing / Selection.pace(e)
  if controlled then
    g.nextAttack = at
  else
    g.attackPacing = pacing or {}
    g.attackPacing[victim.id] = at
  end
  return true
end
local Moves = require('src.enemies.styles')
local Styles, evade = Moves.styles, Moves.evade
AI.styles = Styles
-- On a world with decks, whether body e and body p stand on floors a step
-- cannot join (one on a deck, one under it): then e follows its routes, not
-- a straight approach (plan v10 V3).
function AI.apart(g, e, p)
  if not g.world.decks then
    return false
  end
  return math.abs(Ground.of(g.world, e) - Ground.of(g.world, p)) > (g.world.stepHeight or 0)
end
local function approach(g, e, d, dt, waiting)
  local name = arch(e).move.style
  local style = Styles[name]
  assert(type(style) == 'function', 'unknown movement style ' .. tostring(name))
  style(g, e, d, dt, waiting)
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
    if e.hitPause > 0 then
      e.hitPause = math.max(0, e.hitPause - dt)
      return false
    end
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
    e.spent = math.max(0, (e.spent or 0) - dt)
    if e.evadeReady then
      e.evadeReady = math.max(0, e.evadeReady - dt)
    end
  end
  if math.abs(e.pushX) + math.abs(e.pushZ) > Walk.minPush then
    Body.push(g, e, dt, Rules.body(e).drag or defaults.drag)
  else
    -- The shove is over: so is its owner's claim on a slam (plan v11 E3d).
    e.pushOwner = nil
  end
  return true
end

-- The knight is looking at it: a body in plain sight does not stand and wait for him.
local function watched(e, p, d)
  return p.yaw ~= nil
    and d < Senses.seenRange
    and math.abs(angle(atan2(e.x - p.x, e.z - p.z) - p.yaw)) < Senses.seenCone
end
-- The alarm (owner, D4): a body that notices the knight wakes every sleeping body of its part
-- of the hall (the map's zones) that sees it within alarmRange, and those pass it on for
-- alarmHops steps in all. Those near come at him at once, those behind included; another part
-- wakes when he enters it and is seen there. Before that, posts stand guard or walk patrols.
local function alarm(g, first, p)
  local raised, hops, at = { first }, { 0 }, 1
  local part = W.zone(g.world, first.x, first.z)
  while raised[at] do
    local caller, hop = raised[at], hops[at]
    at = at + 1
    Bodies.eachCreature(g, function(other)
      if
        hop < Senses.alarmHops
        and not other.awake
        and not other.dummy
        and other.hp > 0
        and len(other.x - caller.x, other.z - caller.z) < Senses.alarmRange
        and W.zone(g.world, other.x, other.z) == part
        and Rules.sees(g, other, caller)
      then
        Signal(g, 'Alerted', { enemy = other })
        other.awake, other.memory = true, Senses.memory
        other.lastX, other.lastZ, other.lastLevel = p.x, p.z, p.level
        local index = #raised + 1
        raised[index], hops[index] = other, hop + 1
      end
    end)
  end
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
    if e.visible and (d < (e.alertRange or Senses.alertRange) or watched(e, p, d)) then
      local woke = not e.awake
      if woke then
        Signal(g, 'Alerted', { enemy = e })
      end
      e.awake = true
      e.memory = Senses.memory
      e.lastX = p.x
      e.lastZ = p.z
      e.lastLevel = p.level
      if woke then
        alarm(g, e, p)
      end
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
  e.closeFor = d < Senses.closeRange and (e.closeFor or 0) + dt or 0
  e.frontOn = math.abs(angle(atan2(p.x - e.x, p.z - e.z) - e.facing)) < Senses.frontCone
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
  e.attack = defaults.cancelPause
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
  -- In the beat of a string the body may meet what the knight just did (a dodge) before it
  -- goes on; the string ends there (0.43, audit F04: the flow used to clear it first).
  if e.chain then
    local answer = e.visible and Answers.pick(g, e, target(g, e), d)
    if answer and reserveAttack(g, e, true) then
      e.chain, e.chainFrom = nil, nil
      Attacks.begin(g, e, d, answer)
      return
    end
    if Attacks.flow(g, e, d) then
      return
    end
  end
  if e.recover > 0 then
    return
  end
  -- Too far from its post it gives up the chase.
  if e.leash and len(e.x - e.home.x, e.z - e.home.z) > e.leash then
    e.memory, e.visible = 0, false
  end
  if not (e.awake and (e.memory > 0 or e.visible)) then
    e.ai = 'idle'
    e.awake = false
    -- A body with a post goes back to it; a patrol walks on.
    local post = e.patrol and e.patrol[e.patrolAt or 1] or e.home
    if post and len(e.x - post.x, e.z - post.z) > Walk.home then
      e.ai = 'move'
      route(g, e, post.x, post.z, dt)
    elseif e.patrol then
      e.patrolAt = (e.patrolAt or 1) % #e.patrol + 1
    end
    return
  end
  e.ai = 'move'
  -- Finish a committed sidestep before reserving another action.
  if (e.evadeTime or 0) > 0 and evade(g, e, d, dt) then
    return
  end
  local victim = target(g, e)
  -- The rest of a recovery it walks, but strikes with nothing, answers included.
  local ready = (e.spent or 0) <= 0
  local answer = ready and e.visible and Answers.pick(g, e, victim, d)
  local chosen = answer
    or (
      ready
      and e.visible
      and e.attack <= 0
      and Attacks.choose(e, d, g.elapsed, g.rng and g.rng.sim, g)
    )
  if chosen and reserveAttack(g, e, answer ~= nil) then
    Attacks.begin(g, e, d, chosen)
  elseif evade(g, e, d, dt) then
    -- sidestepping out of the player's aim
  elseif not e.visible or AI.apart(g, e, target(g, e)) then
    -- Where it last saw him, or stuck on the way, and nothing there: it hears where he is
    -- near enough and goes on, else it gives up (0.42: it no longer stands there for seconds).
    local lost = len(e.x - e.lastX, e.z - e.lastZ) < Walk.home * 2
      or (e.blocked or 0) > Walk.stuckTime
    if not e.visible and lost then
      if d < Senses.hearRange then
        e.lastX, e.lastZ, e.lastLevel = victim.x, victim.z, victim.level
      else
        e.memory = 0
      end
    end
    route(g, e, e.lastX, e.lastZ, dt, e.lastLevel)
  else
    -- Every slot taken: the body waits its turn out of reach (owner: one that stands at
    -- his side and does not strike reads as stuck).
    approach(g, e, d, dt, crowded(g, e))
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
AI.separate = Separation.run
-- The whole demon step (tests and tools call this; the session runs the same
-- three systems from src/systems in this order).
function AI.update(g, dt, previousPlayer)
  if type(dt) ~= 'number' or dt ~= dt or dt <= 0 or dt == math.huge then
    return
  end
  AI.demons(g, dt, previousPlayer)
  Separation.run(g, dt)
  Hazards.update(g, dt, previousPlayer)
end
return AI
