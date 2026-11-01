-- The knight among the demons as bodies (plan v5 G3). Two laws, the same for
-- every body:
--   * Own motion (walking, a dodge, a lunge) never pushes another living
--     body: whoever moved into the other this step stops at the contact and
--     slides along it. The knight moves first, so he yields to the demons
--     where they stand; then the demons move and yield to him.
--   * Momentum (a shove from a blow) passes through the contact by the masses
--     (physics/body_physics.lua: P.contact), as one demon thrown into another
--     (combat/rules/contact.lua: the domino). A struck demon's guard takes
--     the hit of the knight's armoured body.
-- Corpses do not block. A leap clears a knight only above his actual head;
-- low airborne bodies remain solid and cannot reappear inside him at landing.
local MathX = require('src.core.mathx')
local W = require('src.world.arena')
local Physics = require('src.physics.body_physics')
local Ground = require('src.physics.ground')
local Rules = require('src.combat.rules')
local Archetypes = require('src.content.enemies')
local Pools = require('src.session.world')
local Bodies = require('src.combat.bodies')
local Roles = require('src.core.roles')
local Contact = {}
local len = MathX.len
local defaults = Archetypes.defaults
local motionEpsilon = 1e-6
local function standing(g, e, p)
  if g.world.elevations then
    return e.hp > 0 and Rules.bodiesOverlap(g, e, p)
  end
  local ey = Ground.of(g.world, e) + (e.leapY or 0)
  local py = Ground.of(g.world, p) + (p.jump or 0)
  return e.hp > 0 and ey < py + Rules.playerBody(p).height - (p.crouch or 0)
end
-- Earliest moving-circle contact, including a complete crossing in one step.
-- The normal points out of the stationary obstacle; tangent motion survives.
function Contact.sweep(x, z, dx, dz, ox, oz, radius)
  local rx, rz = x - ox, z - oz
  local a, b = dx * dx + dz * dz, rx * dx + rz * dz
  if a <= motionEpsilon * motionEpsilon or b >= 0 then
    return nil
  end
  local c = rx * rx + rz * rz - radius * radius
  local discriminant = b * b - a * c
  if discriminant < 0 then
    return nil
  end
  local t = math.max(0, (-b - math.sqrt(discriminant)) / a)
  if t > 1 then
    return nil
  end
  local nx, nz = rx + dx * t, rz + dz * t
  local length = len(nx, nz)
  if length <= 1e-9 then
    return t, -dx / math.sqrt(a), -dz / math.sqrt(a)
  end
  return t, nx / length, nz / length
end
-- oldLevel: the surface the body stood on at (oldX, oldZ) (a world with decks).
local function clippedMove(g, body, oldX, oldZ, dx, dz, radius, t, nx, nz, offset, oldLevel)
  local world = g.world
  local remainX, remainZ = dx * (1 - t), dz * (1 - t)
  local into = math.min(0, remainX * nx + remainZ * nz)
  body.x, body.z = oldX, oldZ
  if world.elevations then
    local key = body.jump ~= nil and 'jump' or 'leapY'
    body[key] = offset
  end
  if world.decks then
    body.level = oldLevel
  end
  local height = Rules.tall(g, body)
  W.move(world, body, dx * t, dz * t, radius, nil, height)
  W.move(world, body, remainX - into * nx, remainZ - into * nz, radius, nil, height)
  return body.x - oldX, body.z - oldZ
end
-- The earliest contact of a demon's own move with knight p (previous: where
-- p stood when the move began).
local function knightContact(g, e, oldX, oldZ, dx, dz, r, p, previous)
  if not standing(g, e, p) then
    return nil
  end
  return Contact.sweep(
    oldX,
    oldZ,
    dx - (p.x - previous.x),
    dz - (p.z - previous.z),
    previous.x,
    previous.z,
    r + Rules.playerBody(p).radius
  )
end
-- Own attack movement obeys the same footprint as ordinary locomotion. It
-- stops at the earliest knight it meets: the controlled one swept between
-- previous and current (sub-step positions), every other knight between
-- its step snapshot and where it stands.
function Contact.moveEnemy(g, e, dx, dz, previous, current)
  local oldX, oldZ, r, oldLevel = e.x, e.z, Rules.radius(e), e.level
  local air, verticalVelocity = e.leapY, e.leapVY
  W.move(g.world, e, dx, dz, r, nil, Rules.tall(g, e))
  dx, dz = e.x - oldX, e.z - oldZ
  local controlled = Bodies.controlled(g)
  local p = current or controlled
  local t, nx, nz = knightContact(g, e, oldX, oldZ, dx, dz, r, p, previous or p)
  for _, knight in ipairs(Bodies.knights(g)) do
    if knight ~= controlled and knight.hp > 0 then
      local kt, kx, kz =
        knightContact(g, e, oldX, oldZ, dx, dz, r, knight, Bodies.previous(g, knight))
      if kt and (not t or kt < t) then
        t, nx, nz = kt, kx, kz
      end
    end
  end
  if t then
    if g.world.elevations then
      e.leapVY = verticalVelocity
    end
    return clippedMove(g, e, oldX, oldZ, dx, dz, r, t, nx, nz, air, oldLevel)
  end
  return dx, dz
end
-- How far the two bodies overlap and the unit normal from the demon to the
-- knight (nil when apart).
local function overlap(p, e, radius)
  local dx, dz = p.x - e.x, p.z - e.z
  local d = len(dx, dz)
  local depth = radius + Rules.radius(e) - d
  if depth <= 0 then
    return nil
  end
  if d < defaults.sameSpot then
    -- Coincident: part along the knight's facing (deterministic).
    return depth, -math.sin(p.yaw), -math.cos(p.yaw)
  end
  return depth, dx / d, dz / d
end
-- A shove carried into the contact passes by the masses (and only then).
local function exchange(g, p, e, nx, nz)
  local knight = Rules.playerBody(p)
  local vx, vz, ox, oz, received, closing = Physics.contact(
    p.pushX or 0,
    p.pushZ or 0,
    e.pushX or 0,
    e.pushZ or 0,
    knight.mass,
    Rules.body(e).mass or 1,
    -nx,
    -nz
  )
  if closing < defaults.collideSpeed then
    return
  end
  p.pushX, p.pushZ, e.pushX, e.pushZ = vx, vz, ox, oz
  e.flinch = math.max(e.flinch or 0, defaults.collideFlinch)
  Rules.guard(e, received * defaults.collidePoise)
  g.collisions = (g.collisions or 0) + 1
end
-- After a knight moved (actor; default the controlled one): he stops at
-- every living demon he walked into.
function Contact.knight(g, actor)
  local controlled = Roles.controlled(g)
  local p = actor or controlled
  local radius = Rules.playerBody(p).radius
  local frame = g.frame
  local previous = frame
    and (p == controlled and frame.previousPlayer or (frame.previousKnights or {})[p.id])
  local lift = frame and (p == controlled and frame.supportLift or (frame.supportLifts or {})[p.id])
    or 0
  if previous then
    local dx, dz = p.x - previous.x, p.z - previous.z
    local first, normalX, normalZ, obstacle
    for _, e in ipairs(Pools.of(g, 'enemies')) do
      if standing(g, e, p) then
        local t, nx, nz =
          Contact.sweep(previous.x, previous.z, dx, dz, e.x, e.z, radius + Rules.radius(e))
        if t and (not first or t < first) then
          first, normalX, normalZ, obstacle = t, nx, nz, e
        end
      end
    end
    if first then
      exchange(g, p, obstacle, normalX, normalZ)
      -- Undo only support rebasing/auto-step height, not this tick's vertical
      -- integration. Otherwise rejecting a horizontal ledge crossing adds
      -- the drop height a second time when rewinding its position.
      local air = p.jump
      if g.world.elevations then
        air =
          math.max(0, Ground.of(g.world, p) + p.jump - Ground.of(g.world, previous) - (lift or 0))
        if air == 0 and p.jumpV < 0 then
          p.jumpV = 0
        end
      end
      clippedMove(
        g,
        p,
        previous.x,
        previous.z,
        dx,
        dz,
        radius,
        first,
        normalX,
        normalZ,
        air,
        previous.level
      )
      local into = math.min(0, (p.vx or 0) * normalX + (p.vz or 0) * normalZ)
      p.vx, p.vz = (p.vx or 0) - into * normalX, (p.vz or 0) - into * normalZ
    end
  end
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if standing(g, e, p) then
      local depth, nx, nz = overlap(p, e, radius)
      if depth then
        exchange(g, p, e, nx, nz)
        W.move(g.world, p, nx * depth, nz * depth, radius, nil, Rules.tall(g, p))
        -- His own velocity no longer drives into the demon.
        local into = (p.vx or 0) * nx + (p.vz or 0) * nz
        if into < 0 then
          p.vx, p.vz = p.vx - into * nx, p.vz - into * nz
        end
      end
    end
  end
end
-- After the demons moved: every living demon that walked into a knight
-- steps back out of him; a shoved one hands him its momentum. Knights in
-- pool order (the controlled one is the first).
function Contact.demons(g)
  for _, p in ipairs(Bodies.knights(g)) do
    local radius = Rules.playerBody(p).radius
    if p.hp > 0 or p == Bodies.controlled(g) then
      for _, e in ipairs(Pools.of(g, 'enemies')) do
        if standing(g, e, p) then
          local depth, nx, nz = overlap(p, e, radius)
          if depth then
            exchange(g, p, e, nx, nz)
            W.move(g.world, e, -nx * depth, -nz * depth, Rules.radius(e), nil, Rules.tall(g, e))
          end
        end
      end
    end
  end
end
return Contact
