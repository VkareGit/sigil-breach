-- Continuous finite-sphere contact with the world's actual tile solids.
-- Closest distance to a convex box/capped pillar is convex along a segment;
-- locate its minimum, then the first radius crossing. No ray fan or square
-- expansion of round corners. Numerical spatial tolerance is 1e-8 m.
local Collision = require('src.physics.collision')
local Ground = require('src.physics.ground')
local Cast = {}
local EPS = 1e-8
local directionEpsilon = 1e-6
local min, max, sqrt = math.min, math.max, math.sqrt
local function slab(lo, hi, origin, direction, lower, upper)
  if math.abs(direction) < directionEpsilon * directionEpsilon then
    if origin < lower or origin > upper then
      return nil
    end
    return lo, hi
  end
  local a, b = (lower - origin) / direction, (upper - origin) / direction
  if a > b then
    a, b = b, a
  end
  lo, hi = max(lo, a), min(hi, b)
  if lo > hi then
    return nil
  end
  return lo, hi
end
-- Closest point on a vertical box or capped cylinder extending down to ground.
local function separation(x, y, z, cx, cz, top, pillar)
  local qx, qz
  if pillar then
    local vx, vz = x - cx, z - cz
    local d = sqrt(vx * vx + vz * vz)
    local s = d > 0 and min(1, Collision.pillarRadius / d) or 1
    qx, qz = cx + vx * s, cz + vz * s
  else
    qx, qz = max(cx - 0.5, min(cx + 0.5, x)), max(cz - 0.5, min(cz + 0.5, z))
  end
  local vx, vy, vz = x - qx, max(0, y - top), z - qz
  return sqrt(vx * vx + vy * vy + vz * vz), vx, vy, vz
end
local function first(distance, lo, hi, radius, dx, dy, dz)
  local entry = lo
  if distance(entry) > radius + EPS then
    -- A convex distance can enter and leave between two clear endpoints.
    -- Ternary minimization finds that interval even at a rounded rim graze.
    while hi - lo > EPS do
      local a, b = lo + (hi - lo) / 3, hi - (hi - lo) / 3
      if a == lo or b == hi then
        break
      end
      if distance(a) <= distance(b) then
        hi = b
      else
        lo = a
      end
    end
    local closest = (lo + hi) * 0.5
    if distance(closest) > radius + EPS then
      return nil
    end
    lo, hi = entry, closest
    while hi - lo > EPS do
      local mid = (lo + hi) * 0.5
      if mid == lo or mid == hi then
        break
      end
      if distance(mid) <= radius + EPS then
        hi = mid
      else
        lo = mid
      end
    end
    entry = hi
  end
  local d, nx, ny, nz = distance(entry)
  if d > EPS then
    return entry, { nx / d, ny / d, nz / d }
  end
  return entry, { -dx, -dy, -dz }
end
local function contact(ox, oy, oz, dx, dy, dz, cx, cz, top, pillar, radius, limit)
  local extent = (pillar and Collision.pillarRadius or 0.5) + radius
  local lo, hi = slab(0, limit, ox, dx, cx - extent, cx + extent)
  if not lo then
    return nil
  end
  lo, hi = slab(lo, hi, oz, dz, cz - extent, cz + extent)
  if not lo then
    return nil
  end
  lo, hi = slab(lo, hi, oy, dy, -math.huge, top + radius)
  if not lo then
    return nil
  end
  return first(function(t)
    return separation(ox + dx * t, oy + dy * t, oz + dz * t, cx, cz, top, pillar)
  end, lo, hi, radius, dx, dy, dz)
end
-- The exterior is unbounded, not just one extra ring of tiles.
local function outside(origin, oy, direction, dy, plane, sign, radius, limit, axis)
  local top = Collision.heights.outside
  local lo, hi = slab(0, limit, origin * sign, direction * sign, -math.huge, plane * sign + radius)
  if not lo then
    return nil
  end
  lo, hi = slab(lo, hi, oy, dy, -math.huge, top + radius)
  if not lo then
    return nil
  end
  return first(function(t)
    local side = max(0, (origin + direction * t - plane) * sign) * sign
    local up = max(0, oy + dy * t - top)
    return sqrt(side * side + up * up), axis == 'x' and side or 0, up, axis == 'z' and side or 0
  end, lo, hi, radius, axis == 'x' and direction or 0, dy, axis == 'z' and direction or 0)
end
function Cast.world(w, ox, oy, oz, dx, dy, dz, range, radius, floorSurface)
  oy = oy - Ground.height(w)
  local best, normal, kind = range, { 0, 0, 0 }, 'range'
  local floor = floorSurface + radius
  if oy <= floor then
    return 0, { 0, 1, 0 }, 'floor'
  end
  if dy < 0 then
    local t = (floor - oy) / dy
    if t >= 0 and t <= best then
      best, normal, kind = t, { 0, 1, 0 }, 'floor'
    end
  end
  for axis = 1, 2 do
    local origin, direction = axis == 1 and ox or oz, axis == 1 and dx or dz
    for sign = -1, 1, 2 do
      local plane = sign == 1 and 0.5 or w.size + 0.5
      local t, n =
        outside(origin, oy, direction, dy, plane, sign, radius, best, axis == 1 and 'x' or 'z')
      if t and (t < best or kind == 'range') then
        best, normal, kind = t, n, 'wall'
      end
    end
  end
  local endX, endZ = ox + dx * best, oz + dz * best
  local x1 = max(0, math.ceil(min(ox, endX) - radius - 0.5))
  local x2 = min(w.size + 1, math.floor(max(ox, endX) + radius + 0.5))
  local z1 = max(0, math.ceil(min(oz, endZ) - radius - 0.5))
  local z2 = min(w.size + 1, math.floor(max(oz, endZ) + radius + 0.5))
  for z = z1, z2 do
    for x = x1, x2 do
      local tile = w.map[z] and w.map[z][x]
      local elevation = Ground.cell(w, x, z)
      if not tile or tile > 0 or elevation > 0 then
        local top = elevation + (tile == 0 and floorSurface or Collision.top(tile))
        local t, n = contact(ox, oy, oz, dx, dy, dz, x, z, top, tile == 2, radius, best)
        if t and (t < best or kind == 'range') then
          best, normal, kind = t, n, 'wall'
        end
        if tile == 2 and elevation > 0 then
          t, n = contact(ox, oy, oz, dx, dy, dz, x, z, elevation, false, radius, best)
          if t and (t < best or kind == 'range') then
            best, normal, kind = t, n, 'wall'
          end
        end
      end
    end
  end
  return best, normal, kind
end
return Cast
