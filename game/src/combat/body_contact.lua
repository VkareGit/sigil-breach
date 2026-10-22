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
local Rules = require('src.combat.rules')
local Archetypes = require('src.content.enemies')
local Contact = {}
local len = MathX.len
local defaults = Archetypes.defaults
local motionEpsilon = 1e-6
local function standing(e, p)
  return e.hp > 0 and (e.leapY or 0) < (p.jump or 0) + Rules.playerBody().height - (p.crouch or 0)
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
local function clippedMove(world, body, oldX, oldZ, dx, dz, radius, t, nx, nz)
  local remainX, remainZ = dx * (1 - t), dz * (1 - t)
  local into = math.min(0, remainX * nx + remainZ * nz)
  body.x, body.z = oldX, oldZ
  W.move(world, body, dx * t, dz * t, radius)
  W.move(world, body, remainX - into * nx, remainZ - into * nz, radius)
  return body.x - oldX, body.z - oldZ
end
-- Own attack movement obeys the same footprint as ordinary locomotion.
function Contact.moveEnemy(g, e, dx, dz, previous, current)
  local oldX, oldZ, r = e.x, e.z, Rules.radius(e)
  W.move(g.world, e, dx, dz, r)
  dx, dz = e.x - oldX, e.z - oldZ
  local p = current or g.player
  previous = previous or p
  if standing(e, p) then
    local t, nx, nz = Contact.sweep(
      oldX,
      oldZ,
      dx - (p.x - previous.x),
      dz - (p.z - previous.z),
      previous.x,
      previous.z,
      r + Rules.playerBody().radius
    )
    if t then
      return clippedMove(g.world, e, oldX, oldZ, dx, dz, r, t, nx, nz)
    end
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
  local knight = Rules.playerBody()
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
-- After the knight moved: he stops at every living demon he walked into.
function Contact.knight(g)
  local p = g.player
  local radius = Rules.playerBody().radius
  local previous = g.frame and g.frame.previousPlayer
  if previous then
    local dx, dz = p.x - previous.x, p.z - previous.z
    local first, normalX, normalZ, obstacle
    for _, e in ipairs(g.enemies) do
      if standing(e, p) then
        local t, nx, nz =
          Contact.sweep(previous.x, previous.z, dx, dz, e.x, e.z, radius + Rules.radius(e))
        if t and (not first or t < first) then
          first, normalX, normalZ, obstacle = t, nx, nz, e
        end
      end
    end
    if first then
      exchange(g, p, obstacle, normalX, normalZ)
      clippedMove(g.world, p, previous.x, previous.z, dx, dz, radius, first, normalX, normalZ)
      local into = math.min(0, (p.vx or 0) * normalX + (p.vz or 0) * normalZ)
      p.vx, p.vz = (p.vx or 0) - into * normalX, (p.vz or 0) - into * normalZ
    end
  end
  for _, e in ipairs(g.enemies) do
    if standing(e, p) then
      local depth, nx, nz = overlap(p, e, radius)
      if depth then
        exchange(g, p, e, nx, nz)
        W.move(g.world, p, nx * depth, nz * depth, radius)
        -- His own velocity no longer drives into the demon.
        local into = (p.vx or 0) * nx + (p.vz or 0) * nz
        if into < 0 then
          p.vx, p.vz = p.vx - into * nx, p.vz - into * nz
        end
      end
    end
  end
end
-- After the demons moved: every living demon that walked into the knight
-- steps back out of him; a shoved one hands him its momentum.
function Contact.demons(g)
  local p = g.player
  local radius = Rules.playerBody().radius
  for _, e in ipairs(g.enemies) do
    if standing(e, p) then
      local depth, nx, nz = overlap(p, e, radius)
      if depth then
        exchange(g, p, e, nx, nz)
        W.move(g.world, e, -nx * depth, -nz * depth, Rules.radius(e))
      end
    end
  end
end
return Contact
