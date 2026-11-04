local Sigils = require('src.combat.sigils')
-- A volley: rounds traced as rays, their contacts summed per body, then
-- applied once. Public to every delivery of a weapon (combat/weapon_delivery.lua):
-- a new way of hitting traces or contacts through this and reports like a shot.
local Entities = require('src.session.entities')
local B = require('src.combat.ballistics')
local Bodies = require('src.combat.bodies')
local Damage = require('src.combat.damage')
local Hit = require('src.combat.hit')
local Materials = require('src.content.ballistic_surfaces')
local Pools = require('src.session.world')
local Roles = require('src.core.roles')
local Rules = require('src.combat.rules')
local Weapons = require('src.content.weapons')
local K = require('src.content.combat_defaults').volley
local Volley = {}
Volley.__index = Volley
-- Every pellet (or round) is traced and its contacts are
-- accumulated per body before anything is applied, so the order of pellets
-- can never open a hole through a body killed by an earlier one.
function Volley.new(g, profile, attack, pellets, shooter)
  return setmetatable({
    g = g,
    shooter = shooter,
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
      weapon = Weapons.slot(g, shooter),
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
      origin = { B.origin(g, shooter) },
      actor = shooter and shooter.id,
      byControlled = shooter == nil or shooter == Roles.controlled(g),
    },
  }, Volley)
end
-- One contact of a ray (direction dx, dy, dz) with a body; retain < 1 after
-- penetration.
function Volley:contact(e, d, x, y, z, normal, part, retain, dx, dy, dz, surface)
  local report = self.report
  local material = surface and surface.material or Rules.body(e).struck or 'flesh'
  local attack = Sigils.contact(self.attack, e, part)
  local damage, absorbed, impact, push =
    Hit.measure(attack, e, d, nil, surface or { zone = part, material = material })
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
  detail.armorAbsorbed = detail.armorAbsorbed + Damage.armorLoss(attack, e, d, part) * retain
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
      local l = math.max(K.nearest, math.sqrt(vx * vx + vz * vz))
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
  local fire, p = self.profile.fire, self.shooter
  local ox, oy = 0, 0
  if fire.pellets > 1 then
    ox, oy = B.pellet(i, self.sequence, pellets)
    ox, oy = ox * spread, oy * spread
  end
  local dx, dy, dz = B.spreadDirection(self.yaw or p.yaw, self.pitch or p.pitch, ox, oy)
  return self:ray(i, dx, dy, dz, ox, oy, bodies)
end
-- One ray along (dx, dy, dz) from the volley's origin; ox, oy: its place in the
-- cone. A delivery of its own casts these directly.
function Volley:ray(i, dx, dy, dz, ox, oy, bodies)
  local g, report = self.g, self.report
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
  local origin = self.origin or report.origin
  local thing, at = Entities.ray(g, origin[1], origin[2], origin[3], dx, dy, dz, d)
  if thing then
    local dealt = Hit.measure(self.attack, thing, at)
    self.things = self.things or {}
    self.things[thing] = (self.things[thing] or 0) + dealt
    ray.trail, d, e = at, at, nil
    return
  end
  ray.normal, ray.seed = normal, self.sequence * K.seedStride + i
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
      local owner = self.shooter and self.shooter.id
      Hit.wound(g, e, damage, 'weapon', self.attack, owner, self.profile.id)
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
      detail.seed = self.sequence * K.seedStride + e.id
      detail.point = pt
      -- Counter-hits are decided by the rules from the body's own rush.
      local extra = {
        push = self.pushes[e],
        lower = self.lowers[e],
        direction = self.directions[e],
        origin = self.reactionOrigin or self.shooter,
      }
      local result = Hit.answer(g, e, self.impacts[e], report.strong, pt, detail, nil, extra) or {}
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
  Sigils.resolved(self.shooter, self.attack, report)
  report.blocked = self.blocked
  if self.things then
    for _, thing in ipairs(Pools.of(g, 'entities')) do
      if self.things[thing] then
        Entities.hurt(g, thing, self.things[thing], self.shooter and self.shooter.id)
      end
    end
  end
  return results
end
return Volley
