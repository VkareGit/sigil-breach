-- Mechanic blocks (PLAN F3): what a kind of attack is made of. A kind
-- (enemies/*_kinds.lua) composes them, and a new kind made only of blocks
-- needs no change to the engine:
--   origin(g, e, angle, spec)    where a missile leaves the body (a caster
--                                for launch), nil when a wall is between
--   launch(g, spec, speed, from) a straight missile from that origin
--   lob(g, e, from, to, spec)    a missile thrown in an arc onto a point
--   deposit(g, e, x, z, level, delay, radius, life, zone)
--                                a mark on the ground owned by the body; the
--                                hazard system owns its warning and contact
--   series                       a release in turn: count blows, interval
--                                apart, along the strike clock
-- A ring, a ray and a room that strike are hazard kinds (enemies/hazards.lua):
-- the wave block is a hazard spawned by its kind.
local ActionKinds = require('src.combat.action_kinds')
local act = ActionKinds.act
local MathX = require('src.core.mathx')
local Ground = require('src.physics.ground')
local Hazards = require('src.enemies.hazards')
local Bodies = require('src.combat.bodies')
local Shape = require('src.combat.projectile_shape')
local Anchor = require('src.enemies.contact_anchor')
local Ballistics = require('src.combat.ballistics')
local Spawn = require('src.session.spawn')
local Contact = require('src.enemies.attack_contact')
local K = require('src.content.combat_defaults').attacks
local sin, cos = math.sin, math.cos
local len = MathX.len
local M = {}
-- A creature casts from its body at the mark it took, angle a.
function M.origin(g, e, a, spec)
  -- Launched and aimed at heights above the ground (physics/ground.lua).
  local ground = Ground.of(g.world, e)
  local y = ground + (e.leapY or 0) + spec.height
  local d = len(e.aimX - e.x, e.aimZ - e.z)
  if spec.originAnchor then
    local x, ay, z = Anchor.point(g, e, e.phase or 0, e.x, e.z, spec.originAnchor)
    if not x then
      return nil
    end
    local sy = ground + ay
    local dx, dy, dz = x - e.x, sy - y, z - e.z
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
    if
      distance > 0
      and Ballistics.world(
          g.world,
          e.x,
          y,
          e.z,
          dx / distance,
          dy / distance,
          dz / distance,
          distance
        )
        < distance
    then
      return nil
    end
    local run = math.max(K.aimClearance, len(e.aimX - x, e.aimZ - z))
    return {
      body = e,
      owner = e.id,
      side = Bodies.side(g, e),
      mx = x,
      my = sy,
      mz = z,
      dx = (e.aimX - x) / run,
      dz = (e.aimZ - z) / run,
      run = run,
      rise = Ground.height(g.world, e.aimX, e.aimZ, e.aimLevel)
        + (spec.aimHeight or K.aimHeight)
        - sy,
    }
  end
  return {
    body = e,
    owner = e.id,
    side = Bodies.side(g, e),
    mx = e.x + sin(a) * K.muzzle,
    my = y,
    mz = e.z + cos(a) * K.muzzle,
    dx = sin(a),
    dz = cos(a),
    rise = Ground.height(g.world, e.aimX, e.aimZ, e.aimLevel) + (spec.aimHeight or K.aimHeight) - y,
    run = math.max(1, d - K.muzzle),
  }
end
-- A missile leaves a caster's mouth along its aim. radius: its own collision
-- radius, also its painted size.
function M.launch(g, spec, speed, caster)
  if not caster then
    return false
  end
  Spawn.make(g, 'projectile', {
    x = caster.mx,
    y = caster.my,
    z = caster.mz,
    vx = caster.dx * speed,
    vz = caster.dz * speed,
    vy = caster.rise * speed / caster.run,
    life = K.boltLife,
    big = spec.big or false,
    color = spec.color,
    owner = caster.owner,
    side = caster.side,
    packet = spec.packet,
    radius = Shape.radius(spec),
  })
  return true
end
-- A missile thrown from a point (x, y, z) in an arc that lands on (tx, tz) of
-- the level: it flies at spec.speed under spec.gravity, its flight lasting at
-- least K.seedMinFlight; deposit, when given, is what it leaves where it lands.
function M.lob(g, e, x, y, z, tx, tz, level, spec, deposit)
  local dx, dz = tx - x, tz - z
  local length = math.sqrt(dx * dx + dz * dz)
  local time = math.max(K.seedMinFlight, length / spec.speed)
  local targetY = Ground.height(g.world, tx, tz, level) + spec.radius
  Spawn.make(g, 'projectile', {
    x = x,
    y = y,
    z = z,
    vx = dx / time,
    vz = dz / time,
    vy = (targetY - y) / time + spec.gravity * time * 0.5,
    gravity = spec.gravity,
    life = K.boltLife,
    radius = spec.radius,
    color = spec.color,
    packet = spec.packet,
    owner = e.id,
    side = Bodies.side(g, e),
    art = spec.art,
    deposit = deposit,
  })
end
-- A mark on the ground at (x, z) of the level, owned by the body and its side.
-- zone: kind, art, impactSound, packet, pulse, condition and volume of the mark.
function M.deposit(g, e, x, z, level, delay, radius, life, zone)
  zone.owner, zone.side, zone.level = e.id, Bodies.side(g, e), level
  Hazards.add(g, x, z, delay, radius, life, zone)
end
-- A release in turn (atk.count, atk.interval apart on the strike clock): each
-- one is given the target as it stands by then. The kind starts the series at
-- execution and steps it in its strike state.
M.series = {
  state = { released = 'blows of the series let go so far' },
}
function M.series.start(e)
  act(e).released = 0
end
-- each(g, e, atk, target) lets one blow go.
function M.series.step(g, e, atk, each)
  while act(e).released < atk.count and e.phase >= act(e).released * atk.interval do
    local t = Contact.victim(g, e)
    act(e).released = act(e).released + 1
    each(g, e, atk, t)
  end
end
function M.series.duration(_, atk)
  return (atk.count - 1) * atk.interval + atk.duration
end
return M
