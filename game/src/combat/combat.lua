local Capabilities = require('src.session.capabilities')
local Signal = require('src.session.signal')
local AI = require('src.enemies.ai')
local B = require('src.combat.ballistics')
local Reload = require('src.combat.reload')
local Damage = require('src.combat.damage')
local Weapons = require('src.content.weapons')
local Rules = require('src.combat.rules')
local Corpse = require('src.enemies.corpse')
local Materials = require('src.content.ballistic_surfaces')
local Deliveries = require('src.combat.weapon_delivery')
local Observation = require('src.combat.observation')
local Loadout = require('src.combat.loadout')
local Pools = require('src.session.world')
local Roles = require('src.core.roles')
local C = { trace = B.trace }
-- Body response comes from the shared rules (src/combat/rules.lua); the
-- corpse's response to the contact starts here; measurements and the visible
-- spray are listeners of BlowResolved.
-- number (optional): { value, kill, head } shown where a single blow landed
-- (a missile, a blast); a volley's numbers come with VolleyResolved.
function C.react(g, e, impact, strong, point, contact, health, extra, number)
  local result =
    Rules.react(g, e, impact, strong, point, health or (contact and contact.healthDamage), extra)
  Corpse.struck(g, e, impact, strong, point, contact)
  Signal(g, 'BlowResolved', {
    target = e,
    result = result,
    impact = impact,
    point = point,
    contact = contact,
    number = number,
  })
  return result
end
-- A trigger pull, step by step (0.24). Everything a pull does comes from the
-- weapon's fire data (content/weapons.lua); the steps below never ask which
-- weapon it is.

-- 1. May the trigger be pulled now? A closed or empty action reloads instead.
-- A knight off balance (staggered) cannot aim (0.25, D2); a pull may stop a
-- reload while rounds remain in the gun (combat/reload.lua: interrupt).
local function ready(g)
  if g.state ~= 'playing' or g.map or g.help or g.cooldown > 0 then
    return nil
  end
  if Rules.has(Roles.controlled(g), 'staggered') then
    return nil
  end
  local profile, state = Weapons.inHand(g)
  if not profile or not state then
    return nil
  end
  -- A broken extension fails before cancelling a reload or spending a round.
  Deliveries:get(profile.delivery.kind)
  assert(
    Reload.mechanisms[profile.mechanism],
    'weapon ' .. profile.id .. ': unknown reload mechanism ' .. profile.mechanism
  )
  if g.reload > 0 and not Reload.interrupt(g) then
    return nil
  end
  if not Capabilities.armed(g) then
    return nil
  end
  if not profile or not Weapons.validAmmo(g) then
    return nil
  end
  if (state.readyAt or 0) > g.elapsed + 1e-8 then
    return nil
  end
  if state.open or (state.mag or 0) <= 0 or not Weapons.canFire(g) then
    g:reloadGun()
    return nil
  end
  return profile
end

-- 2. The discharge: rounds spent, cadence, recoil, sound, flash and powder.
local function discharge(g, profile, command)
  local p, fire = Roles.controlled(g), profile.fire
  local state = Weapons.state(g)
  local rounds = math.min(fire.rounds, state.mag)
  state.mag = state.mag - rounds
  if fire.ejects then
    state.spent = (state.spent or 0) + rounds
  end
  AI.noise(g, p.x, p.z, fire.noise)
  g.shots = g.shots + 1
  g.shotSerial = g.shotSerial + 1
  g.cooldown = profile.cycle
  state.readyAt = g.elapsed + profile.cycle
  -- Recoil, flash, sound and powder: feedback/shot_feedback.lua.
  if g.bus then
    local event = { profile = profile, shotPower = rounds / fire.rounds, command = command }
    Signal(g, 'ShotFired', event)
  end
  return fire.pellets * rounds / fire.rounds
end

-- 3. The volley: every pellet (or round) is traced and its contacts are
-- accumulated per body before anything is applied, so the order of pellets
-- can never open a hole through a body killed by an earlier one.
local Volley = {}
Volley.__index = Volley
local function newVolley(g, profile, attack, pellets)
  return setmetatable({
    g = g,
    profile = profile,
    attack = attack,
    damages = {},
    spots = {},
    counts = {},
    impacts = {},
    details = {},
    pushes = {},
    directions = {},
    lowers = {},
    blocked = 0,
    report = {
      weapon = g.weapon,
      weaponName = profile.name,
      pellets = pellets,
      pelletsHit = 0,
      headHits = 0,
      targets = 0,
      kills = 0,
      damage = 0,
      healthDamage = 0,
      overkill = 0,
      impact = 0,
      maxDamage = 0,
      maxHealthDamage = 0,
      rays = {},
      contacts = {},
      hitTargets = {},
      strong = profile.fire.heavy,
      origin = { B.origin(g) },
    },
  }, Volley)
end
-- One contact of a ray (direction dx, dy, dz) with a body; retain < 1 after
-- penetration.
function Volley:contact(e, d, x, y, z, normal, part, retain, dx, dy, dz, surface)
  local report = self.report
  local material = surface and surface.material or Rules.body(e).struck or 'flesh'
  local damage, absorbed, impact, push =
    Damage.surface(self.attack, e, d, surface or { zone = part, material = material })
  damage, absorbed, impact, push =
    damage * retain, absorbed * retain, impact * retain, push * retain
  local receipt = {
    targetId = e.id,
    shapeId = surface and surface.shapeId or part,
    zone = part,
    material = material,
    damage = e.hp > 0 and part ~= false and damage or 0,
    distance = d,
    point = { x, y, z },
    normal = normal,
    kind = e.hp <= 0 and 'corpse' or 'body',
    retained = retain,
  }
  report.contacts[#report.contacts + 1] = receipt
  if e.hp <= 0 or part == false then
    return
  end
  self.pushes[e] = (self.pushes[e] or 0) + push
  local direction = self.directions[e] or { 0, 0 }
  direction[1], direction[2] = direction[1] + dx * push, direction[2] + dz * push
  self.directions[e] = direction
  if part == 'lower' then
    self.lowers[e] = (self.lowers[e] or 0) + impact
  end
  self.blocked = self.blocked + math.max(0, absorbed)
  self.impacts[e] = (self.impacts[e] or 0) + impact
  self.damages[e] = (self.damages[e] or 0) + damage
  self.counts[e] = (self.counts[e] or 0) + 1
  local detail = self.details[e]
    or {
      id = e.id,
      distanceMin = d,
      distanceMax = d,
      absorbed = 0,
      armorAbsorbed = 0,
      headHits = 0,
      dx = 0,
      dy = 0,
      dz = 0,
      normal = { 0, 0, 0 },
      material = material,
    }
  detail.distanceMin = math.min(detail.distanceMin, d)
  detail.distanceMax = math.max(detail.distanceMax, d)
  detail.absorbed = detail.absorbed + absorbed
  self.details[e] = detail
  detail.armorAbsorbed = detail.armorAbsorbed + Damage.armorLoss(self.attack, e, d, part) * retain
  if part == 'head' then
    detail.headHits = detail.headHits + 1
    report.headHits = report.headHits + 1
  end
  detail.dx, detail.dy, detail.dz = detail.dx + dx, detail.dy + dy, detail.dz + dz
  for axis = 1, 3 do
    detail.normal[axis] = detail.normal[axis] + normal[axis]
  end
  report.distanceMin = math.min(report.distanceMin or d, d)
  report.distanceMax = math.max(report.distanceMax or d, d)
  local pt = self.spots[e] or { 0, 0, 0 }
  pt[1], pt[2], pt[3] = pt[1] + x, pt[2] + y, pt[3] + z
  self.spots[e] = pt
  report.pelletsHit = report.pelletsHit + 1
  if retain < 1 then
    detail.pierced = true
    report.pierced = (report.pierced or 0) + 1
  end
end
-- Penetration (Call of Duty style): the round goes on through the body and
-- keeps retain = pierce.retain - armour * pierce.armorCost of its power per
-- body, the armour of the part it passed through (0.25: a bare skull costs
-- none; combat/damage.lua: rating); it stops below minRetain or after
-- pierce.bodies bodies. Returns the distance of the last body reached (where
-- the visible trail ends).
function Volley:pierce(first, d, dx, dy, dz, bodies, firstPart, firstSurface)
  local pierce = self.attack.pierce
  local chain = B.traceAll(self.g, dx, dy, dz, self.profile.range, bodies, self.origin)
  local retain, passed, prev, prevPart = 1, 0, first, firstPart
  local previousSurface = firstSurface
  for _, h in ipairs(chain) do
    if h.enemy ~= first and h.distance > d then
      if previousSurface and not Materials[previousSurface.material].penetrable then
        break
      end
      retain = retain
        * math.max(0, pierce.retain - Damage.rating(prev, prevPart) * pierce.armorCost)
      passed = passed + 1
      if retain < pierce.minRetain or passed > pierce.bodies then
        break
      end
      local vx, vz = h.x - h.enemy.x, h.z - h.enemy.z
      local l = math.max(0.001, math.sqrt(vx * vx + vz * vz))
      self:contact(
        h.enemy,
        h.distance,
        h.x,
        h.y,
        h.z,
        h.contact and h.contact.normal or { vx / l, 0, vz / l },
        h.part,
        retain,
        dx,
        dy,
        dz,
        h.contact
      )
      prev, prevPart = h.enemy, h.part
      previousSurface = h.contact
      d = h.distance
    end
  end
  return d
end
-- Trace pellet i of the volley: body contacts, or the surface it strikes.
function Volley:trace(i, pellets, spread, bodies)
  local g, fire, p, report = self.g, self.profile.fire, Roles.controlled(self.g), self.report
  local ox, oy = 0, 0
  if fire.pellets > 1 then
    ox, oy = B.pellet(i, g.shotSerial, pellets)
    ox, oy = ox * spread, oy * spread
  end
  local dx, dy, dz = B.spreadDirection(self.yaw or p.yaw, self.pitch or p.pitch, ox, oy)
  local e, d, x, y, z, kind, normal, part, surface =
    B.traceVector(g, dx, dy, dz, self.profile.range, bodies, self.origin)
  local ray = {
    x = x,
    y = y,
    z = z,
    distance = d,
    target = e and e.id or nil,
    kind = kind,
    part = part,
    shapeId = surface and surface.shapeId,
    material = surface and surface.material,
    corpse = e and e.hp <= 0 or false,
    ox = ox,
    oy = oy,
    dx = dx,
    dy = dy,
    dz = dz,
  }
  report.rays[#report.rays + 1] = ray
  ray.normal, ray.seed = normal, g.shotSerial * 31 + i
  if e then
    self:contact(e, d, x, y, z, normal, part, 1, dx, dy, dz, surface)
    if self.attack.pierce then
      d = self:pierce(e, d, dx, dy, dz, bodies, part, surface)
    end
  end
  -- Where the visible trail ends (after the last body pierced).
  ray.trail = d
end
-- 4. Apply the accumulated volley to every body it reached, in enemy order.
function Volley:apply()
  local g, report, results = self.g, self.report, {}
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    local damage = self.damages[e]
    if damage then
      local pt = self.spots[e]
      for j = 1, 3 do
        pt[j] = pt[j] / self.counts[e]
      end
      local healthBefore = e.hp
      g:damageEnemy(e, damage, 'weapon', self.attack)
      local actual = math.min(math.max(0, healthBefore), damage)
      report.healthDamage = report.healthDamage + actual
      report.overkill = report.overkill + math.max(0, damage - actual)
      report.impact = report.impact + self.impacts[e]
      report.push = (report.push or 0) + (self.pushes[e] or 0)
      report.maxHealthDamage = math.max(report.maxHealthDamage, actual)
      local detail = self.details[e]
      detail.pellets = self.counts[e]
      detail.damage = damage
      detail.healthDamage = actual
      detail.impact = self.impacts[e]
      detail.killed = e.hp <= 0
      report.hitTargets[#report.hitTargets + 1] = detail
      detail.seed = (report.shotSerial or g.shotSerial) * 31 + e.id
      detail.point = pt
      -- Counter-hits are decided by the rules from the body's own rush.
      local extra = {
        push = self.pushes[e],
        lower = self.lowers[e],
        direction = self.directions[e],
      }
      local result = C.react(g, e, self.impacts[e], report.strong, pt, detail, nil, extra) or {}
      detail.counter, detail.crippled = result.counter, result.crippled
      report.counters = (report.counters or 0) + (result.counter and 1 or 0)
      results[#results + 1] = result
      detail.staggered = result.staggered
      detail.wounded = result.wounded
      report.targets = report.targets + 1
      report.kills = report.kills + (e.hp <= 0 and 1 or 0)
      report.damage = report.damage + damage
      report.maxDamage = math.max(report.maxDamage, damage)
    end
  end
  report.blocked = self.blocked
  return results
end

local function resolveVolley(g, shot, bodies)
  local profile, pellets = shot.profile, shot.count
  local volley = newVolley(g, profile, shot.attack, pellets)
  volley.origin, volley.yaw, volley.pitch = shot.origin, shot.yaw, shot.pitch
  volley.report.origin = shot.origin
  local spread = shot.spread
  for i = 1, pellets do
    volley:trace(i, pellets, spread, bodies)
  end
  local results = volley:apply()
  if volley.report.targets > 0 then
    g.hits = g.hits + 1
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
Deliveries:register('hitscan', { prepare = B.prepare, fire = resolveVolley })

-- Finite rounds arrive later, possibly after a weapon swap. They retain their
-- original payload/slot/serial, and use the same material, armour, response and
-- presentation receipt as instantaneous rounds. The shared shot counts one hit
-- even if several projectiles from this discharge reach different bodies.
function C.projectile(g, b, e, part, surface)
  local shot = b.shot
  local volley = newVolley(g, shot.profile, shot.attack, 1)
  volley.report.weapon, volley.report.shotSerial = shot.slot, shot.serial
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
    1,
    b.vx / length,
    b.vy / length,
    b.vz / length,
    surface
  )
  local results = volley:apply()
  if volley.report.targets > 0 and not shot.hit then
    g.hits, shot.hit = g.hits + 1, true
  end
  Signal(
    g,
    'VolleyResolved',
    { report = volley.report, results = results, attack = shot.attack, profile = shot.profile }
  )
end

function C.shoot(g, command)
  local observation = command and command.observation
  if observation and not Observation.valid(g, observation) then
    return false
  end
  local profile = ready(g)
  if not profile then
    return false
  end
  -- Validate the executor before spending ammunition. Freeze hitscan bodies
  -- before noise can wake/turn them; finite rounds sample at actual contact.
  local delivery = Deliveries:get(profile.delivery.kind)
  local observed = observation and profile.delivery.kind == 'hitscan'
  local prepared = observed and Observation.prepare(g, observation)
    or (delivery.prepare and delivery.prepare(g, profile))
  local attack, spread = Loadout.attack(g, g.weapon), Loadout.spread(g)
  local pellets = discharge(g, profile, command)
  local shot = {
    profile = profile,
    attack = attack,
    spread = spread,
    count = pellets,
    serial = g.shotSerial,
    slot = g.weapon,
    origin = observed and Observation.copy(observation.origin) or { B.origin(g) },
    yaw = command and command.yaw or Roles.controlled(g).yaw,
    pitch = command and command.pitch or Roles.controlled(g).pitch,
    hit = false,
  }
  delivery.fire(g, shot, prepared)
  if profile.fire.autoReload and (Weapons.state(g).reserve or 0) > 0 then
    Reload.start(g, true)
  end
  return true
end
return C
