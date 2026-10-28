-- A slab with a triangulated underside. The four authored corner heights
-- are shared by rendering, point rays and finite-sphere casts. Old flat
-- decks use their existing fast path. Each half is a convex triangular prism.
local R = {}
local abs, min, max, sqrt = math.abs, math.min, math.max, math.sqrt
local EPS = 1e-8
local cache = setmetatable({}, { __mode = 'k' })
local function dot(a, b)
  return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end
local function sub(a, b)
  return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end
local function cross(a, b)
  return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end
function R.height(deck, x, z)
  local h = deck[3]
  if not h then
    return deck[1]
  end
  local u, v = x - math.floor(x + 0.5) + 0.5, z - math.floor(z + 0.5) + 0.5
  if h[5] then
    if u >= v then
      if u + v <= 1 then
        return h[1] * (1 - u - v) + h[2] * (u - v) + h[5] * 2 * v
      end
      return h[2] * (u - v) + h[3] * (u + v - 1) + h[5] * 2 * (1 - u)
    end
    if u + v >= 1 then
      return h[3] * (u + v - 1) + h[4] * (v - u) + h[5] * 2 * (1 - v)
    end
    return h[4] * (v - u) + h[1] * (1 - u - v) + h[5] * 2 * u
  end
  if u >= v then
    return h[1] * (1 - u) + h[2] * (u - v) + h[3] * v
  end
  return h[1] * (1 - v) + h[3] * u + h[4] * (v - u)
end
function R.corners(deck, x, z)
  local h = deck[3]
  return {
    { x - 0.5, h[1], z - 0.5 },
    { x + 0.5, h[2], z - 0.5 },
    { x + 0.5, h[3], z + 0.5 },
    {
      x - 0.5,
      h[4],
      z + 0.5,
    },
  }
end
local function triangle(a, b, c, center)
  local ab, ac = sub(b, a), sub(c, a)
  local n = cross(ab, ac)
  local len = sqrt(dot(n, n))
  for i = 1, 3 do
    n[i] = n[i] / len
  end
  if dot(n, sub(center, a)) > 0 then
    for i = 1, 3 do
      n[i] = -n[i]
    end
  end
  return { a = a, b = b, c = c, ab = ab, ac = ac, n = n, d = dot(n, a) }
end
local function prism(a, b, c, top)
  local u, v, w = { a[1], top, a[3] }, { b[1], top, b[3] }, { c[1], top, c[3] }
  local center =
    { (a[1] + b[1] + c[1]) / 3, (a[2] + b[2] + c[2] + 3 * top) / 6, (a[3] + b[3] + c[3]) / 3 }
  local faces = {}
  for _, p in ipairs({
    { a, b, c },
    { u, w, v },
    { a, u, v },
    { a, v, b },
    { b, v, w },
    { b, w, c },
    {
      c,
      w,
      u,
    },
    {
      c,
      u,
      a,
    },
  }) do
    faces[#faces + 1] = triangle(p[1], p[2], p[3], center)
  end
  return faces
end
local function shapes(deck, x, z)
  local stored = cache[deck]
  local result = stored and stored.x == x and stored.z == z and stored.faces
  if not result then
    local p = R.corners(deck, x, z)
    if deck[3][5] then
      local middle = { x, deck[3][5], z }
      result = {}
      for i = 1, 4 do
        result[i] = prism(p[i], p[i % 4 + 1], middle, deck[2])
      end
    else
      result = { prism(p[1], p[2], p[3], deck[2]), prism(p[1], p[3], p[4], deck[2]) }
    end
    cache[deck] = { x = x, z = z, faces = result }
  end
  return result
end
-- Closest point on a triangle, using its Voronoi regions.
local function closest(f, p)
  local a, b, c, ab, ac = f.a, f.b, f.c, f.ab, f.ac
  local ap = sub(p, a)
  local d1, d2 = dot(ab, ap), dot(ac, ap)
  if d1 <= 0 and d2 <= 0 then
    return a
  end
  local bp = sub(p, b)
  local d3, d4 = dot(ab, bp), dot(ac, bp)
  if d3 >= 0 and d4 <= d3 then
    return b
  end
  local vc = d1 * d4 - d3 * d2
  if vc <= 0 and d1 >= 0 and d3 <= 0 then
    local v = d1 / (d1 - d3)
    return { a[1] + ab[1] * v, a[2] + ab[2] * v, a[3] + ab[3] * v }
  end
  local cp = sub(p, c)
  local d5, d6 = dot(ab, cp), dot(ac, cp)
  if d6 >= 0 and d5 <= d6 then
    return c
  end
  local vb = d5 * d2 - d1 * d6
  if vb <= 0 and d2 >= 0 and d6 <= 0 then
    local w = d2 / (d2 - d6)
    return { a[1] + ac[1] * w, a[2] + ac[2] * w, a[3] + ac[3] * w }
  end
  local va = d3 * d6 - d5 * d4
  if va <= 0 and d4 - d3 >= 0 and d5 - d6 >= 0 then
    local w = (d4 - d3) / ((d4 - d3) + (d5 - d6))
    return { b[1] + (c[1] - b[1]) * w, b[2] + (c[2] - b[2]) * w, b[3] + (c[3] - b[3]) * w }
  end
  local inv = 1 / (va + vb + vc)
  local v, w = vb * inv, vc * inv
  return { a[1] + ab[1] * v + ac[1] * w, a[2] + ab[2] * v + ac[2] * w, a[3] + ab[3] * v + ac[3] * w }
end
local function distance(faces, p)
  local inside, best, normal = true, math.huge, nil
  for _, f in ipairs(faces) do
    if dot(f.n, p) > f.d + EPS then
      inside = false
    end
    local delta = sub(p, closest(f, p))
    local d = dot(delta, delta)
    if d < best then
      best = d
      if d > EPS * EPS then
        local len = sqrt(d)
        normal = { delta[1] / len, delta[2] / len, delta[3] / len }
      else
        normal = f.n
      end
    end
  end
  return inside and 0 or best, normal
end
local function ray(faces, o, d, limit)
  local lo, hi, normal = 0, limit, { 0, -1, 0 }
  for _, f in ipairs(faces) do
    local q, speed = dot(f.n, o) - f.d, dot(f.n, d)
    if abs(speed) < 1e-12 then
      if q > EPS then
        return
      end
    else
      local t = -q / speed
      if speed < 0 then
        if t > lo then
          lo, normal = t, f.n
        end
      else
        hi = min(hi, t)
      end
      if lo > hi + EPS then
        return
      end
    end
  end
  if hi >= 0 and lo <= limit then
    return max(0, lo), normal
  end
end
local function sweep(faces, o, d, radius, limit)
  if radius == 0 then
    return ray(faces, o, d, limit)
  end
  -- Clip to the expanded halfspaces first. This is only the broad phase:
  -- exact distance below rejects rounded-edge/corner false positives.
  local lo, hi = 0, limit
  for _, f in ipairs(faces) do
    local q, speed = dot(f.n, o) - f.d - radius, dot(f.n, d)
    if abs(speed) < 1e-12 then
      if q > EPS then
        return
      end
    else
      local t = -q / speed
      if speed < 0 then
        lo = max(lo, t)
      else
        hi = min(hi, t)
      end
      if lo > hi + EPS then
        return
      end
    end
  end
  if lo > limit or hi < 0 then
    return
  end
  lo, hi = max(0, lo), min(limit, hi)
  local function at(t)
    return distance(faces, { o[1] + d[1] * t, o[2] + d[2] * t, o[3] + d[3] * t })
  end
  local threshold = (radius + EPS) ^ 2
  local first, n = at(lo)
  if first <= threshold then
    return lo, n
  end
  local left, right = lo, hi
  -- Squared distance to a convex solid is convex along a straight flight.
  local speed = sqrt(dot(d, d))
  -- Each ternary reduction keeps 2/3 of the interval. Derive a bounded
  -- iteration count from spatial tolerance, including non-unit velocities.
  local reductions = math.ceil(math.log(max(1, (hi - lo) * speed / EPS)) / math.log(3 / 2)) + 2
  for _ = 1, reductions do
    local a, b = left + (right - left) / 3, right - (right - left) / 3
    if at(a) < at(b) then
      right = b
    else
      left = a
    end
  end
  local middle = (left + right) / 2
  if at(middle) > threshold then
    return
  end
  left, right = lo, middle
  local bisections = math.ceil(math.log(max(1, (right - left) * speed / EPS)) / math.log(2)) + 2
  for _ = 1, bisections do
    local t = (left + right) / 2
    if at(t) <= threshold then
      right = t
    else
      left = t
    end
  end
  local _, normal = at(right)
  return right, normal
end
function R.cast(deck, x, z, ox, oy, oz, dx, dy, dz, radius, limit)
  if
    max(oy, oy + dy * limit) + radius < deck[1] - EPS
    or min(oy, oy + dy * limit) - radius > deck[2] + EPS
  then
    return
  end
  local o, d = { ox, oy, oz }, { dx, dy, dz }
  local best, normal
  for _, faces in ipairs(shapes(deck, x, z)) do
    local t, n = sweep(faces, o, d, radius, best or limit)
    if t and (not best or t < best) then
      best, normal = t, n
    end
  end
  return best, normal
end
return R
