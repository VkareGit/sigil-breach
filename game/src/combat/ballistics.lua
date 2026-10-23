local T = require('src.content.tuning')
local Geometry = require('src.enemies.geometry')
local Ground = require('src.physics.ground')
local Surface = require('src.enemies.surface')
local Corpse = require('src.enemies.corpse')
local B = {}
local abs, sqrt = math.abs, math.sqrt
local eye = require('src.content.knight').body.eye
-- The eye in world height: the ground under the knight, his eye, his jump.
function B.origin(g)
  local p = g.player
  return p.x, Ground.height(g.world) + eye + p.jump - (p.crouch or 0), p.z
end
function B.direction(yaw, pitch)
  local cp = math.cos(pitch)
  return math.sin(yaw) * cp, math.sin(pitch), math.cos(yaw) * cp
end
function B.spreadDirection(yaw, pitch, horizontal, vertical)
  local fx, fy, fz = B.direction(yaw, pitch)
  local rx, rz = math.cos(yaw), -math.sin(yaw)
  local ux, uy, uz =
    -math.sin(yaw) * math.sin(pitch), math.cos(pitch), -math.cos(yaw) * math.sin(pitch)
  local h, v = math.tan(horizontal or 0), math.tan(vertical or 0)
  local x, y, z = fx + rx * h + ux * v, fy + uy * v, fz + rz * h + uz * v
  local length = sqrt(x * x + y * y + z * z)
  return x / length, y / length, z / length
end
-- Two barrels, ten independent rays each. A denser core gives a deliberate
-- centre aim a reliable result at medium range; outer pairs still cover
-- adjacent bodies. The cone remains angular, symmetric and deterministic.
-- Damage is unchanged: each ray still resolves its own surface and distance.
local halfPattern = require('src.content.ballistic_pattern')
function B.pellet(index, serial, count)
  -- Preserve the approved one/two-barrel patterns exactly. Other counts use
  -- mirrored golden-angle pairs in a bounded disc, with a centred odd pellet.
  -- This has no fixed pattern-array limit and no random side bias.
  if count ~= 10 and count ~= 20 then
    if count % 2 == 1 and index == count then
      return 0, 0
    end
    local pairs = math.floor(count / 2)
    local pair = math.floor((index - 1) / 2) + 1
    local side = index % 2 == 1 and -1 or 1
    local radius = math.sqrt((pair - 0.5) / math.max(1, pairs))
    local angle = pair * math.pi * (3 - math.sqrt(5))
    local flip = (serial or 0) % 2 == 0 and 1 or -1
    return side * math.cos(angle) * radius * T.pelletSpread,
      side * math.sin(angle) * radius * T.pelletVerticalSpread * flip
  end
  local pair = math.floor((index - 1) / 2) + 1
  local side = index % 2 == 1 and -1 or 1
  if count == 10 then
    pair = pair * 2
  end
  local v = halfPattern[pair]
  local flip = (serial or 0) % 2 == 0 and 1 or -1
  return side * v[1] * T.pelletSpread, side * v[2] * T.pelletVerticalSpread * flip
end
-- Round pillars (tile 2) stop shots as the painted cylinder, not as their
-- square cell: a ray through an empty cell corner passes. Radius of the
-- shaft at shooting height (mesh cone .48 at the base to .36 at the top).
local Collision = require('src.physics.collision')
B.pillarRadius = Collision.pillarRadius
local heights = Collision.heights
local ray = {}
local function pillar(oy, dy, x, z, entry, exit)
  local ox, oz, dx, dz = ray.ox - x, ray.oz - z, ray.dx, ray.dz
  local r2 = B.pillarRadius ^ 2
  -- A descending ray may land on the capital (flat top at 4.8 m).
  local function cap()
    if dy >= 0 then
      return
    end
    local t = (heights.pillar - oy) / dy
    if t < entry - 1e-9 or t > exit + 1e-9 then
      return
    end
    local hx, hz = ox + dx * t, oz + dz * t
    if hx * hx + hz * hz <= r2 then
      return math.max(t, entry), 0, 1, 0
    end
  end
  local a = dx * dx + dz * dz
  if a < 1e-12 then
    return cap()
  end
  local b = ox * dx + oz * dz
  local c = ox * ox + oz * oz - r2
  local disc = b * b - a * c
  if disc < 0 then
    return
  end
  local t = (-b - sqrt(disc)) / a
  if c <= 0 then
    t = entry
  end
  if t < entry - 1e-9 or t > exit + 1e-9 then
    return cap()
  end
  if oy + dy * t > heights.pillar then
    return cap()
  end
  local hx, hz = ox + dx * t, oz + dz * t
  local l = math.max(1e-6, sqrt(hx * hx + hz * hz))
  return math.max(t, entry), hx / l, 0, hz / l
end
local function cell(w, oy, dy, x, z, entry, exit, nx, nz)
  local tile = w.map[z] and w.map[z][x]
  if tile == 2 then
    return pillar(oy, dy, x, z, entry, exit)
  end
  if not tile or tile > 0 then
    local height = Collision.top(tile)
    if oy + dy * entry <= height then
      return entry, nx, 0, nz
    end
    if dy < 0 then
      local top = (height - oy) / dy
      if top >= entry and top <= exit then
        return top, 0, 1, 0
      end
    end
  end
end
-- A ray from a point in world height: the floor, walls and pillars rise from
-- the ground (physics/ground.lua), so heights below are taken from it.
function B.world(w, ox, oy, oz, dx, dy, dz, range)
  oy = oy - Ground.height(w)
  local hit, normal, kind = range, { 0, 0, 0 }, 'range'
  ray.ox, ray.oz, ray.dx, ray.dz = ox, oz, dx, dz
  if dy < -0.000001 then
    local floor = (T.floorSurface - oy) / dy
    if floor >= 0 and floor < hit then
      hit = floor
      normal = { 0, 1, 0 }
      kind = 'floor'
    end
  end
  local cx, cz = math.floor(ox + 0.5), math.floor(oz + 0.5)
  local sx, sz = dx >= 0 and 1 or -1, dz >= 0 and 1 or -1
  local deltaX, deltaZ =
    abs(dx) > 1e-8 and 1 / abs(dx) or math.huge, abs(dz) > 1e-8 and 1 / abs(dz) or math.huge
  local nextX = abs(dx) > 1e-8 and (cx + sx * 0.5 - ox) / dx or math.huge
  local nextZ = abs(dz) > 1e-8 and (cz + sz * 0.5 - oz) / dz or math.huge
  -- Intersect the occupied vertical interval of a cell. The DDA visits closed
  -- cells: a ray through a shared corner must not choose a transparent side
  -- according to whether X or Z happened to be stepped first.
  local edgeX = dx == 0 and ox == cx - 0.5
  local edgeZ = dz == 0 and oz == cz - 0.5
  local entry, nx, nz = 0, 0, 0
  -- Number of crossed grid planes, not an unrelated fixed distance limit.
  local steps = math.ceil(abs(dx) * hit) + math.ceil(abs(dz) * hit) + 3
  for _ = 1, steps do
    if entry > hit then
      break
    end
    local exit = math.min(nextX, nextZ, hit)
    local d, ax, ay, az = cell(w, oy, dy, cx, cz, entry, exit, nx, nz)
    -- A ray running exactly along a grid face also touches its other cell.
    if edgeX then
      local t, bx, by, bz = cell(w, oy, dy, cx - 1, cz, entry, exit, 1, 0)
      if t and (not d or t < d) then
        d, ax, ay, az = t, bx, by, bz
      end
    end
    if edgeZ then
      local t, bx, by, bz = cell(w, oy, dy, cx, cz - 1, entry, exit, 0, 1)
      if t and (not d or t < d) then
        d, ax, ay, az = t, bx, by, bz
      end
    end
    if edgeX and edgeZ then
      local t, bx, by, bz = cell(w, oy, dy, cx - 1, cz - 1, entry, exit, 0, 0)
      if t and (not d or t < d) then
        d, ax, ay, az = t, bx, by, bz
      end
    end
    if d then
      return d, { ax, ay, az }, 'wall'
    end
    if nextX > hit and nextZ > hit then
      break
    end
    if abs(nextX - nextZ) <= 1e-10 then
      entry = math.min(nextX, nextZ)
      local tx = cell(w, oy, dy, cx + sx, cz, entry, entry, -sx, 0)
      local tz = cell(w, oy, dy, cx, cz + sz, entry, entry, 0, -sz)
      if tx or tz then
        local scale = tx and tz and 1 / sqrt(2) or 1
        return entry, { tx and -sx * scale or 0, 0, tz and -sz * scale or 0 }, 'wall'
      end
      nextX, nextZ = nextX + deltaX, nextZ + deltaZ
      cx, cz = cx + sx, cz + sz
      nx, nz = -sx / sqrt(2), -sz / sqrt(2)
    elseif nextX < nextZ then
      entry = nextX
      nextX = nextX + deltaX
      cx = cx + sx
      nx, nz = -sx, 0
    else
      entry = nextZ
      nextZ = nextZ + deltaZ
      cz = cz + sz
      nx, nz = 0, -sz
    end
  end
  return hit, normal, kind
end
function B.cylinderShape(e, ox, oy, oz, dx, dy, dz, limit, radius, bottom, top)
  local ex, ez = ox - e.x, oz - e.z
  local a = dx * dx + dz * dz
  local lo, hi = 0, limit
  if a == 0 then
    if ex * ex + ez * ez > radius * radius then
      return
    end
  else
    local b = ex * dx + ez * dz
    local c = ex * ex + ez * ez - radius * radius
    local disc = b * b - a * c
    if disc < 0 then
      return
    end
    local root = sqrt(disc)
    lo = math.max(lo, (-b - root) / a)
    hi = math.min(hi, (-b + root) / a)
  end
  if dy == 0 then
    if oy < bottom or oy > top then
      return
    end
  else
    local aY, bY = (bottom - oy) / dy, (top - oy) / dy
    lo = math.max(lo, math.min(aY, bY))
    hi = math.min(hi, math.max(aY, bY))
  end
  -- An overlapping body is a contact at t=0. Artificially moving it .001
  -- along the ray changes event order and depends on the sweep's units.
  if lo <= hi and hi >= 0 then
    return lo
  end
end
-- What a ray (or a finite missile of radius) meets on one body: its painted
-- surface, or its explicit volumes when its appearance chose them
-- (enemies/geometry.lua: uses). surface / volumes: prepared for this body.
function B.body(g, e, ox, oy, oz, dx, dy, dz, limit, volumes, surface, radius)
  if not Geometry.uses(e) then
    local p = surface or Surface.prepare(g, e)
    return Surface.ray(p, ox, oy, oz, dx, dy, dz, limit, radius)
  end
  local nearest, part
  local contact
  volumes = volumes or Geometry.volumes(g, e)
  for _, v in ipairs(volumes) do
    local d =
      B.cylinderShape(v, ox, oy, oz, dx, dy, dz, nearest or limit, v.radius, v.bottom, v.top)
    if d and (not nearest or d < nearest) then
      nearest, part = d, v.zone
      local x, z = ox + dx * d - v.x, oz + dz * d - v.z
      local length = math.max(1e-8, sqrt(x * x + z * z))
      contact = {
        shapeId = v.id,
        zone = v.zone,
        material = v.material,
        normal = { x / length, 0, z / length },
      }
    end
  end
  return nearest, part, contact
end
-- A body in the way of a shot or missile: alive, or killed and still falling
-- (enemies/corpse.lua: shields — the one rule; the dead take no damage).
function B.blocks(e)
  return e.hp > 0 or Corpse.shields(e)
end
function B.prepare(g)
  local bodies = g._shotBodies or {}
  g._shotBodies = bodies
  local count = 0
  for _, e in ipairs(g.enemies) do
    if B.blocks(e) then
      count = count + 1
      local entry = bodies[count] or {}
      entry.enemy = e
      -- Only the representation the body uses is prepared.
      if Geometry.uses(e) then
        entry.volumes, entry.surface = Geometry.volumes(g, e), nil
      else
        entry.volumes, entry.surface = nil, Surface.prepare(g, e, entry.surface or entry.spare)
        entry.spare = entry.surface
      end
      bodies[count] = entry
    end
  end
  for i = #bodies, count + 1, -1 do
    bodies[i] = nil
  end
  return bodies
end
function B.traceVector(g, dx, dy, dz, range, bodies, origin)
  local ox, oy, oz = B.origin(g)
  if origin then
    ox, oy, oz = unpack(origin)
  end
  local distance, normal, kind = B.world(g.world, ox, oy, oz, dx, dy, dz, range)
  local target, part, contact
  for _, entry in ipairs(bodies or g.enemies) do
    local e = bodies and entry.enemy or entry
    if (bodies and entry.observed) or B.blocks(e) then
      local d, segment, receipt = B.body(
        g,
        e,
        ox,
        oy,
        oz,
        dx,
        dy,
        dz,
        distance,
        bodies and entry.volumes or nil,
        bodies and entry.surface or nil
      )
      if d and d < distance - 1e-6 then
        distance = d
        target = e
        kind = 'enemy'
        part = segment
        contact = receipt
      end
    end
  end
  local x, y, z = ox + dx * distance, oy + dy * distance, oz + dz * distance
  if target then
    local vx, vz = x - target.x, z - target.z
    local l = math.max(0.001, sqrt(vx * vx + vz * vz))
    normal = contact and contact.normal or { vx / l, 0, vz / l }
  end
  return target, distance, x, y, z, kind, normal, part, contact
end
-- Every body along the ray before the wall, nearest first (penetration).
function B.traceAll(g, dx, dy, dz, range, bodies, origin)
  local ox, oy, oz = B.origin(g)
  if origin then
    ox, oy, oz = unpack(origin)
  end
  local wall = B.world(g.world, ox, oy, oz, dx, dy, dz, range)
  local hits = {}
  for _, entry in ipairs(bodies or g.enemies) do
    local e = bodies and entry.enemy or entry
    if (bodies and entry.observed) or B.blocks(e) then
      local d, part, contact = B.body(
        g,
        e,
        ox,
        oy,
        oz,
        dx,
        dy,
        dz,
        wall,
        bodies and entry.volumes or nil,
        bodies and entry.surface or nil
      )
      if d and d < wall - 1e-6 then
        hits[#hits + 1] = {
          enemy = e,
          distance = d,
          part = part,
          contact = contact,
          x = ox + dx * d,
          y = oy + dy * d,
          z = oz + dz * d,
        }
      end
    end
  end
  table.sort(hits, function(a, b)
    return a.distance < b.distance
  end)
  return hits, wall
end
function B.trace(g, yaw, pitch, range)
  local dx, dy, dz = B.direction(yaw, pitch)
  return B.traceVector(g, dx, dy, dz, range)
end
return B
