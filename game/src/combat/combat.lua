local Capabilities = require('src.session.capabilities')
local Signal = require('src.session.signal')
local AI = require('src.enemies.ai')
local B = require('src.combat.ballistics')
local Reload = require('src.combat.reload')
local Weapons = require('src.content.weapons')
local Rules = require('src.combat.rules')
local Deliveries = require('src.combat.weapon_delivery')
local Observation = require('src.combat.observation')
local Loadout = require('src.combat.loadout')
local Pools = require('src.session.world')
local Roles = require('src.core.roles')
local Bodies = require('src.combat.bodies')
local Hit = require('src.combat.hit')
local Volley = require('src.combat.volley')
local Attributes = require('src.combat.attributes')
local C = { trace = B.trace }
-- The controlled actor's shots and the shots that reached a body.
function C.counters(g)
  local a = Roles.controlled(g)
  return a.shots, a.hits
end
-- The body's answer to a blow (combat/hit.lua).
C.react = Hit.answer
-- A trigger pull, step by step (0.24). Everything a pull does comes from the
-- weapon's fire data (content/weapons.lua); the steps below never ask which
-- weapon it is.

-- 1. May the trigger be pulled now? A closed or empty action reloads instead.
-- A knight off balance (staggered) cannot aim (0.25, D2); a pull may stop a
-- reload while rounds remain in the gun (combat/reload.lua: interrupt).
-- a: the shooting actor (a knight; plan v11 E3b).
local function ready(g, a)
  if g.state ~= 'playing' or g.map or g.help or a.cooldown > 0 or a.hp <= 0 then
    return nil
  end
  if Attributes.forbids(a, 'fire') then
    return nil
  end
  local profile, state = Weapons.inHand(g, nil, a)
  if not profile or not state then
    return nil
  end
  -- A broken extension fails before cancelling a reload or spending a round.
  Deliveries:get(profile.delivery.kind)
  assert(
    Reload.mechanisms[profile.mechanism],
    'weapon ' .. profile.id .. ': unknown reload mechanism ' .. profile.mechanism
  )
  if Reload.left(g, a) > 0 and not Reload.interrupt(g, a) then
    return nil
  end
  if not Capabilities.armed(g) then
    return nil
  end
  if not profile or not Weapons.validAmmo(g, nil, a) then
    return nil
  end
  if (state.readyAt or 0) > g.elapsed + 1e-8 then
    return nil
  end
  if state.open or (state.mag or 0) <= 0 or not Weapons.canFire(g, a) then
    g:reloadGun(a.id)
    return nil
  end
  return profile
end

-- 2. The discharge: rounds spent, cadence, recoil, sound, flash and powder.
local function discharge(g, profile, command, p)
  local fire = profile.fire
  local state = Weapons.state(g, nil, p)
  local rounds = math.min(fire.rounds, state.mag)
  state.mag = state.mag - rounds
  if fire.ejects then
    state.spent = (state.spent or 0) + rounds
  end
  AI.noise(g, p.x, p.z, fire.noise)
  -- The world's shot id (journal, observations) and the actor's own shot
  -- sequence (its pellet pattern and contact seeds; plan v11 E3).
  p.shots = p.shots + 1
  g.shotSerial = g.shotSerial + 1
  p.shotSequence = p.shotSequence + 1
  p.cooldown = profile.cycle
  state.readyAt = g.elapsed + profile.cycle
  -- Recoil, flash, sound and powder: feedback/shot_feedback.lua.
  if g.bus then
    local event = {
      profile = profile,
      shotPower = rounds / fire.rounds,
      command = command,
      actor = p.id,
      -- Whether the controlled knight fired: until plan v11 E5 gives every
      -- viewer its context, only his shots are presented.
      byControlled = p == Roles.controlled(g),
    }
    Signal(g, 'ShotFired', event)
  end
  return fire.pellets * rounds / fire.rounds
end

local function resolveVolley(g, shot, bodies)
  local profile, pellets = shot.profile, shot.count
  local volley = Volley.new(g, profile, shot.attack, pellets, shot.shooter)
  volley.origin, volley.yaw, volley.pitch = shot.origin, shot.yaw, shot.pitch
  volley.sequence = shot.sequence
  volley.report.origin = shot.origin
  local spread = shot.spread
  for i = 1, pellets do
    volley:trace(i, pellets, spread, bodies)
  end
  local results = volley:apply()
  if volley.report.targets > 0 then
    shot.shooter.hits = shot.shooter.hits + 1
  end
  -- Marks, trails, numbers, hitmarker, named rules: feedback/shot_feedback.lua.
  if g.bus then
    g.bus:emit('VolleyResolved', {
      report = volley.report,
      results = results,
      attack = volley.attack,
      profile = profile,
    })
  end
end
-- Hitscan bodies are seen from the shooter's eye (plan v11 E4).
Deliveries:register('hitscan', {
  observes = true,
  prepare = function(g, _, shooter)
    return B.prepare(g, shooter)
  end,
  fire = resolveVolley,
})

-- Finite rounds arrive later, possibly after a weapon swap. They retain their
-- original payload/slot/serial, and use the same material, armour, response and
-- presentation receipt as instantaneous rounds. The shared shot counts one hit
-- even if several projectiles from this discharge reach different bodies.
function C.projectile(g, b, e, part, surface, observer)
  local shot = b.shot
  local volley = Volley.new(g, shot.profile, shot.attack, 1, shot.shooter)
  -- Use the same basis that prepared the contacted painted surface. A dead
  -- or departed shooter leaves the muzzle origin, not his later position.
  volley.reactionOrigin = assert(observer, 'projectile contact requires its observer')
  volley.report.weapon, volley.report.shotSerial = shot.slot, shot.serial
  volley.sequence = shot.sequence
  volley.report.origin = shot.origin
  local length = math.max(1e-8, math.sqrt(b.vx * b.vx + b.vy * b.vy + b.vz * b.vz))
  local normal = surface and surface.normal or { -b.vx / length, -b.vy / length, -b.vz / length }
  volley:contact(
    e,
    b.travelled or 0,
    b.x,
    b.y,
    b.z,
    normal,
    part,
    b.retain or 1,
    b.vx / length,
    b.vy / length,
    b.vz / length,
    surface
  )
  local results = volley:apply()
  if volley.report.targets > 0 and not shot.hit then
    shot.shooter.hits, shot.hit = shot.shooter.hits + 1, true
  end
  Signal(
    g,
    'VolleyResolved',
    { report = volley.report, results = results, attack = shot.attack, profile = shot.profile }
  )
end

-- who: the shooting actor (its id, or nil for the controlled knight).
function C.shoot(g, command, who)
  local a = Bodies.actor(g, who)
  if not a then
    return false
  end
  local observation = command and command.observation
  if observation and not Observation.valid(g, observation, a) then
    return false
  end
  local profile = ready(g, a)
  if not profile then
    return false
  end
  -- Validate the executor before spending ammunition. Freeze hitscan bodies
  -- before noise can wake/turn them; finite rounds sample at actual contact.
  local delivery = Deliveries:get(profile.delivery.kind)
  local observed = observation and delivery.observes
  local prepared = observed and Observation.prepare(g, observation, a)
    or (delivery.prepare and delivery.prepare(g, profile, a))
  if observed then
    -- The journal keeps the bodies of an observation a shot used.
    Signal(g, 'ObservationUsed', { observation = observation })
  end
  local slot = Weapons.slot(g, a)
  local attack, spread = Loadout.attack(g, slot, a), Loadout.spread(g, a)
  local pellets = discharge(g, profile, command, a)
  local shot = {
    profile = profile,
    attack = attack,
    spread = spread,
    count = pellets,
    serial = g.shotSerial,
    -- Its shooter and the shooter's own shot sequence (plan v11 E3).
    shooter = a,
    sequence = a.shotSequence,
    slot = slot,
    origin = observed and Observation.copy(observation.origin) or { B.origin(g, a) },
    yaw = command and command.yaw or a.yaw,
    pitch = command and command.pitch or a.pitch,
    hit = false,
  }
  delivery.fire(g, shot, prepared)
  if profile.fire.autoReload and (Weapons.state(g, nil, a).reserve or 0) > 0 then
    Reload.start(g, true, a)
  end
  return true
end
return C
