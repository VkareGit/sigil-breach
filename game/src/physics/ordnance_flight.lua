-- Analytic flight, rolling resistance and circular-pillar contacts.
-- No damage, effects or session ownership in the geometry solver.
local Collision = require('src.physics.collision')
local Ground = require('src.physics.ground')
local heights = Collision.heights
-- Solve constant-acceleration flight at contact time. End-of-tick velocity
-- shortened throws; resolving only one contact discarded the rest of each tick.
local skin = 1e-5
local function flightY(b, t, acceleration)
  return b.y + b.vy * t - 0.5 * acceleration * t * t
end
local function descendingCrossing(b, height, acceleration)
  if acceleration == 0 then
    return b.vy < 0 and (height - b.y) / b.vy or math.huge
  end
  local d = b.vy * b.vy + 2 * acceleration * (b.y - height)
  if d < 0 then
    return math.huge
  end
  local root = math.sqrt(d)
  if b.vy < 0 and b.y >= height then
    return 2 * (b.y - height) / (root - b.vy)
  end
  return (b.vy + root) / acceleration
end
-- The first time the flight rises through height (math.huge: never).
local function ascendingCrossing(b, height, acceleration)
  if b.y >= height then
    return math.huge
  end
  if acceleration == 0 then
    return b.vy > 0 and (height - b.y) / b.vy or math.huge
  end
  local d = b.vy * b.vy - 2 * acceleration * (height - b.y)
  if b.vy <= 0 or d < 0 then
    return math.huge
  end
  return (b.vy - math.sqrt(d)) / acceleration
end
local none = {}
-- A deck of cell (cx, cz) met between entry and leave (plan v10 V3): its
-- side when the flight enters the cell at the slab's height, its top when it
-- falls onto it, its underside when it rises into it.
local function deck(w, b, cx, cz, entry, leave, ex, ez, acceleration, floorHeight)
  for _, slab in ipairs(Ground.decks(w, cx, cz) or none) do
    local bottom, top = slab[1], slab[2] + floorHeight
    local y = flightY(b, entry, acceleration)
    if y > bottom + skin and y < top - skin then
      return entry, ex, 0, ez
    end
    if not b.grounded then
      local land = descendingCrossing(b, top, acceleration)
      if y >= top - skin and land >= entry and land <= leave then
        return land, 0, 1, 0
      end
      local rise = ascendingCrossing(b, bottom, acceleration)
      if rise >= entry and rise <= leave then
        return rise, 0, -1, 0
      end
    end
  end
end
local function solidAt(w, x, z, y)
  local tile = w.map[z] and w.map[z][x]
  -- A grid corner never lies in the circular footprint of a pillar. Its exact
  -- side and cap are handled inside the cell, not at this DDA boundary.
  return (not tile and y <= heights.outside)
    or (tile == 2 and Ground.cell(w, x, z) > 0 and y <= Ground.cell(w, x, z))
    or (
      tile
      and tile ~= 2
      and y <= Ground.cell(w, x, z) + (tile == 0 and 0 or Collision.top(tile, w, x, z))
    )
end
-- Interval inside a pillar's circular footprint. Horizontal flight is linear
-- (ground drag uses effective travel time), so no temporal subdivision is needed.
local function pillarInterval(w, b, cx, cz)
  local x, z = b.x - cx, b.z - cz
  local radius = Collision.pillarOf(w)
  local a = b.vx * b.vx + b.vz * b.vz
  local c = x * x + z * z - radius * radius
  if a == 0 then
    return c <= 0 and -math.huge or math.huge, math.huge
  end
  local half = x * b.vx + z * b.vz
  local discriminant = half * half - a * c
  -- Tangency has no inward motion and no finite interval of support.
  if discriminant <= 0 then
    return math.huge, -math.huge
  end
  local root = math.sqrt(discriminant)
  return (-half - root) / a, (-half + root) / a
end
local function sweep(w, b, duration, acceleration, floorHeight)
  local hit, nx, ny, nz = duration, nil, nil, nil
  if not b.grounded then
    local floor = descendingCrossing(b, floorHeight, acceleration)
    if floor >= -1e-9 and floor <= hit then
      hit, nx, ny, nz = math.max(0, floor), 0, 1, 0
    end
  end
  local cx, cz = math.floor(b.x + 0.5), math.floor(b.z + 0.5)
  local sx, sz = b.vx >= 0 and 1 or -1, b.vz >= 0 and 1 or -1
  local deltaX = math.abs(b.vx) > 1e-10 and 1 / math.abs(b.vx) or math.huge
  local deltaZ = math.abs(b.vz) > 1e-10 and 1 / math.abs(b.vz) or math.huge
  local nextX = deltaX < math.huge and (cx + sx * 0.5 - b.x) / b.vx or math.huge
  local nextZ = deltaZ < math.huge and (cz + sz * 0.5 - b.z) / b.vz or math.huge
  local entry, ex, ez = 0, 0, 0
  while entry <= hit do
    local leave = math.min(nextX, nextZ, hit)
    local tile = w.map[cz] and w.map[cz][cx]
    local enterPillar, exitPillar
    if tile == 2 then
      enterPillar, exitPillar = pillarInterval(w, b, cx, cz)
    end
    if b.grounded and b.y > floorHeight + skin * 2 then
      local base = Ground.surface(w, cx, cz, b.y - floorHeight + skin * 2)
      local onCap = tile == 2 and b.y > base + floorHeight + skin * 2
      local support = base
        + (
          tile == 2 and (onCap and Collision.top(tile, w, cx, cz) or floorHeight)
          or ((not tile or tile > 0) and Collision.top(tile, w, cx, cz) or floorHeight)
        )
      if support < b.y - skin * 2 or (onCap and (entry < enterPillar or entry >= exitPillar)) then
        return entry, 0, 0, 0, 'edge'
      end
      if onCap and exitPillar <= leave then
        return exitPillar, 0, 0, 0, 'edge'
      end
    end
    if tile == 2 then
      local base = Ground.cell(w, cx, cz)
      if base > 0 then
        if flightY(b, entry, acceleration) < base - skin then
          return entry, ex, 0, ez
        end
        if not b.grounded then
          local top = descendingCrossing(b, base, acceleration)
          if top >= entry and top <= leave and (top < enterPillar or top > exitPillar) then
            return top, 0, 1, 0
          end
        end
      end
      local start, finish = math.max(entry, enterPillar), math.min(leave, exitPillar)
      if start < finish or (start == finish and start < exitPillar) then
        local height = base + Collision.top(tile, w, cx, cz)
        if flightY(b, start, acceleration) <= height then
          local x, z = b.x + b.vx * start - cx, b.z + b.vz * start - cz
          local len = math.sqrt(x * x + z * z)
          return start, len > 0 and x / len or 0, 0, len > 0 and z / len or 0
        end
        local top = descendingCrossing(b, height, acceleration)
        if top >= start and top <= finish then
          return top, 0, 1, 0
        end
      end
    elseif not tile or tile > 0 or Ground.cell(w, cx, cz) > 0 then
      local height = Ground.cell(w, cx, cz)
        + (tile == 0 and floorHeight or Collision.top(tile, w, cx, cz))
      if not b.grounded and flightY(b, entry, acceleration) <= height then
        return entry, ex, 0, ez
      end
      if b.grounded and height > b.y + skin then
        return entry, ex, 0, ez
      end
      local top = descendingCrossing(b, height, acceleration)
      if top >= entry and top <= leave then
        return top, 0, 1, 0
      end
    end
    if w.decks then
      local t, dx, dy, dz = deck(w, b, cx, cz, entry, leave, ex, ez, acceleration, floorHeight)
      if t then
        return t, dx, dy, dz
      end
    end
    if nextX > hit and nextZ > hit then
      break
    end
    if math.abs(nextX - nextZ) < 1e-10 then
      local y = flightY(b, nextX, acceleration)
      local sideX, sideZ = solidAt(w, cx + sx, cz, y), solidAt(w, cx, cz + sz, y)
      if sideX or sideZ or solidAt(w, cx + sx, cz + sz, y) then
        if sideX and not sideZ then
          return nextX, -sx, 0, 0
        end
        if sideZ and not sideX then
          return nextX, 0, 0, -sz
        end
        return nextX, -sx / math.sqrt(2), 0, -sz / math.sqrt(2)
      end
      entry = nextX
      nextX = nextX + deltaX
      nextZ = nextZ + deltaZ
      cx, cz = cx + sx, cz + sz
      ex, ez = -sx / math.sqrt(2), -sz / math.sqrt(2)
    elseif nextX < nextZ then
      entry = nextX
      nextX = nextX + deltaX
      cx = cx + sx
      ex, ez = -sx, 0
    else
      entry = nextZ
      nextZ = nextZ + deltaZ
      cz = cz + sz
      ex, ez = 0, -sz
    end
  end
  return hit, nx, ny, nz
end
local function advance(w, b, duration, gravity, floorHeight, K)
  -- Resistance per second on the floor, never per rendered frame.
  local groundDrag = K.groundDrag
  local remaining = duration
  local contacts = 0
  while remaining > 1e-9 do
    -- Analytic ground drag preserves a straight horizontal path. Effective travel
    -- time maps its collision time back to elapsed simulation seconds.
    local grounded = b.grounded
    local acceleration = grounded and 0 or gravity
    local travelTime = grounded and (1 - math.exp(-groundDrag * remaining)) / groundDrag
      or remaining
    local hit, nx, ny, nz, kind = sweep(w, b, travelTime, acceleration, floorHeight)
    local used = grounded and -math.log(math.max(1e-12, 1 - groundDrag * hit)) / groundDrag or hit
    used = math.min(remaining, math.max(0, used))
    b.x, b.y, b.z = b.x + b.vx * hit, flightY(b, hit, acceleration), b.z + b.vz * hit
    if grounded then
      local damp = math.exp(-groundDrag * used)
      b.vx, b.vz = b.vx * damp, b.vz * damp
    else
      b.vy = b.vy - gravity * used
    end
    remaining = remaining - used
    if not nx then
      break
    end
    contacts = contacts + 1
    if kind == 'edge' then
      b.grounded = false
      local speed = math.sqrt(b.vx * b.vx + b.vz * b.vz)
      if speed > 1e-10 then
        b.x, b.z = b.x + b.vx / speed * skin, b.z + b.vz / speed * skin
      end
    else
      if nx == 0 and ny == 0 and nz == 0 then
        b.vx, b.vy, b.vz = 0, 0, 0
        break
      end
      b.x, b.y, b.z = b.x + nx * skin, b.y + ny * skin, b.z + nz * skin
      local dot = b.vx * nx + b.vy * ny + b.vz * nz
      if dot < 0 then
        b.vx = (b.vx - K.bounce * dot * nx) * K.keep
        b.vy = (b.vy - K.bounce * dot * ny) * K.keep
        b.vz = (b.vz - K.bounce * dot * nz) * K.keep
      end
      if ny == 1 and b.vy < K.settle then
        b.grounded = true
        b.vy = 0
      end
    end
    -- Bound pathological coincident-contact loops without tunnelling through walls.
    if contacts >= K.maxContacts then
      b.vx, b.vy, b.vz = 0, 0, 0
      break
    end
  end
end
return { advance = advance }
