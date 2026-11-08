-- Owned deposits reserve capacity in flight and remain ordinary finite pools.
local Pools = require('src.session.world')
local Spawn = require('src.session.spawn')
local Ground = require('src.physics.ground')
local Arena = require('src.world.arena')
local Collision = require('src.physics.collision')
local K = require('src.content.combat_defaults').hazards
local AttackDefaults = require('src.content.combat_defaults').attacks
local Bodies = require('src.combat.bodies')
local Garden = {}
function Garden.count(g, owner, group)
  local count = 0
  for _, h in ipairs(Pools.of(g, 'hazards')) do
    if h.owner == owner and h.garden == group and h.life > 0 then
      count = count + 1
    end
  end
  for _, b in ipairs(Pools.of(g, 'projectiles')) do
    if b.owner == owner and b.deposit and b.deposit.group == group and b.life > 0 then
      count = count + 1
    end
  end
  return count
end
function Garden.land(g, b, normal)
  local d = b.deposit
  if not d or not normal or normal[2] <= 0 then
    return
  end
  if Garden.count(g, b.owner, d.group) >= d.limit then
    return
  end
  local level = Ground.height(g.world, b.x, b.z, b.y)
  if Collision.solid(g.world, b.x, b.z, K.clearance, level, 0, level + d.volume.top) then
    return
  end
  Spawn.make(g, 'hazard', {
    kind = 'pool',
    garden = d.group,
    art = d.art,
    x = b.x,
    z = b.z,
    level = level,
    owner = b.owner,
    side = b.side,
    radius = d.radius,
    life = d.life,
    delay = d.delay,
    maxDelay = d.delay,
    volume = d.volume,
    packet = d.packet,
    condition = d.condition,
    pulse = 0,
    interval = d.pulse,
  })
end
function Garden.eligible(g, e, a, h)
  return h.owner == e.id
    and h.side == Bodies.side(g, e)
    and h.garden == a.group
    and not h.harvest
    and h.delay <= -a.mature
    and h.life > a.windup + AttackDefaults.unseenWindup + a.life
    and h.kind == 'pool'
    and (h.x - e.x) ^ 2 + (h.z - e.z) ^ 2 <= a.range ^ 2
    and math.abs(Ground.of(g.world, h) - Ground.of(g.world, e)) < 1e-6
    and Arena.visible(g.world, e.x, e.z, h.x, h.z)
end
function Garden.available(g, e, a)
  if not g then
    return false
  end
  for _, h in ipairs(Pools.of(g, 'hazards')) do
    if Garden.eligible(g, e, a, h) then
      return true
    end
  end
  return false
end
function Garden.watch(g, h)
  if not h.harvest then
    return
  end
  local e = Pools.get(g, h.owner)
  if
    not e
    or e.hp <= 0
    or e.ai ~= 'windup'
    or not (e.act and e.act.harvestMarks)
    or e.attackKind ~= h.harvest.attack
  then
    h.harvest = nil
  end
end
return Garden
