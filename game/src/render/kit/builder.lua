-- Vertex lists of painted architecture: every vertex has its place in its own
-- image and its light baked in. A list carries the light it bakes with.
local B = {}
local sqrt, sin, cos, pi, max, min, abs =
  math.sqrt, math.sin, math.cos, math.pi, math.max, math.min, math.abs
B.format = {
  { 'VertexPosition', 'float', 3 },
  { 'VertexNormal', 'float', 3 },
  { 'VertexTexCoord', 'float', 2 },
  { 'VertexColor', 'float', 4 },
}
-- Metres of column one repeat of its image covers.
B.drumHeight = 2.2
function B.list(light)
  return { light = light }
end
-- One vertex. shade darkens the baked light; a list without a light is lit by
-- its image alone (the distant backdrop).
function B.put(list, x, y, z, nx, ny, nz, u, v, shade)
  local r, g, b = 1, 1, 1
  if list.light then
    r, g, b = list.light:at(x, y, z, nx, ny, nz)
  end
  local s = shade or 1
  list[#list + 1] = { x, y, z, nx, ny, nz, u, v, r * s, g * s, b * s, list.glow or 0 }
end
local function normal(a, b, c)
  local ux, uy, uz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
  local vx, vy, vz = c[1] - a[1], c[2] - a[2], c[3] - a[3]
  local nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
  local l = max(1e-6, sqrt(nx * nx + ny * ny + nz * nz))
  return nx / l, ny / l, nz / l
end
-- Points are { x, y, z, u, v }; front is a point the face looks towards.
function B.quad(list, a, b, c, d, front, shade)
  local nx, ny, nz = normal(a, b, c)
  if front and (front[1] - a[1]) * nx + (front[2] - a[2]) * ny + (front[3] - a[3]) * nz < 0 then
    nx, ny, nz = -nx, -ny, -nz
  end
  B.put(list, a[1], a[2], a[3], nx, ny, nz, a[4], a[5], shade)
  B.put(list, b[1], b[2], b[3], nx, ny, nz, b[4], b[5], shade)
  B.put(list, c[1], c[2], c[3], nx, ny, nz, c[4], c[5], shade)
  B.put(list, a[1], a[2], a[3], nx, ny, nz, a[4], a[5], shade)
  B.put(list, c[1], c[2], c[3], nx, ny, nz, c[4], c[5], shade)
  B.put(list, d[1], d[2], d[3], nx, ny, nz, d[4], d[5], shade)
end
-- A surface of revolution; profile = { { radius, height }, ... }.
-- bite(angle, y): a share of the radius knocked away; height: metres per image.
function B.lathe(list, x, z, profile, sides, wraps, shade, bite, height)
  height = height or B.drumHeight
  local function vertex(ring, s, nr, ny)
    local angle = s / sides * 2 * pi
    local c, n = cos(angle), sin(angle)
    local radius = bite and ring[1] * (1 - bite(angle, ring[2])) or ring[1]
    B.put(
      list,
      x + c * radius,
      ring[2],
      z + n * radius,
      c * nr,
      ny,
      n * nr,
      s / sides * wraps,
      ring[2] / height,
      shade
    )
  end
  for i = 1, #profile - 1 do
    local p, q = profile[i], profile[i + 1]
    local dr, dy = q[1] - p[1], q[2] - p[2]
    local l = max(1e-5, sqrt(dr * dr + dy * dy))
    local nr, ny = dy / l, -dr / l
    for s = 0, sides - 1 do
      vertex(p, s, nr, ny)
      vertex(p, s + 1, nr, ny)
      vertex(q, s + 1, nr, ny)
      vertex(p, s, nr, ny)
      vertex(q, s + 1, nr, ny)
      vertex(q, s, nr, ny)
    end
  end
end
-- A rectangular rib through points { x, y, z }; half sizes w (across) and h.
function B.rib(list, points, w, h, shade)
  for i = 1, #points - 1 do
    local a, b = points[i], points[i + 1]
    local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
    local l = max(1e-6, sqrt(dx * dx + dy * dy + dz * dz))
    dx, dy, dz = dx / l, dy / l, dz / l
    local sx, sz = -dz, dx
    local sl = sqrt(sx * sx + sz * sz)
    if sl < 1e-3 then
      sx, sz, sl = 1, 0, 1
    end
    sx, sz = sx / sl, sz / sl
    local ux, uy, uz = -sz * dy, sz * dx - sx * dz, sx * dy
    local function corner(p, m, n, v)
      return {
        p[1] + sx * m * w + ux * n * h,
        p[2] + uy * n * h,
        p[3] + sz * m * w + uz * n * h,
        (m + 1) * 0.3,
        v,
      }
    end
    local va, vb = i * 0.25, (i + 1) * 0.25
    local mx, my, mz = (a[1] + b[1]) / 2, (a[2] + b[2]) / 2, (a[3] + b[3]) / 2
    for _, f in ipairs({ { -1, -1, 1, -1 }, { 1, -1, 1, 1 }, { 1, 1, -1, 1 }, { -1, 1, -1, -1 } }) do
      local m, n = f[1] + f[3], f[2] + f[4]
      local front = { mx + (sx * m + ux * n) * 9, my + uy * n * 9, mz + (sz * m + uz * n) * 9 }
      B.quad(
        list,
        corner(a, f[1], f[2], va),
        corner(b, f[1], f[2], vb),
        corner(b, f[3], f[4], vb),
        corner(a, f[3], f[4], va),
        front,
        shade
      )
    end
  end
end
-- A quarter of a pointed arch, from its springing to its apex.
function B.arc(x0, y0, z0, x1, y1, z1, segments)
  local points = {}
  for i = 0, segments do
    local t = i / segments
    local s = sin(t * pi / 2)
    points[#points + 1] = { x0 + (x1 - x0) * s, y0 + (y1 - y0) * t ^ 0.72, z0 + (z1 - z0) * s }
  end
  return points
end
-- Forged oval links along a sagging line. Every other link is turned a quarter.
function B.chain(list, a, b, sag, links, shade)
  local function at(t)
    return a[1] + (b[1] - a[1]) * t,
      a[2] + (b[2] - a[2]) * t - sag * 4 * t * (1 - t),
      a[3] + (b[3] - a[3]) * t
  end
  local long, wide, thick = 0.2, 0.1, 0.032
  for i = 0, links do
    local x, y, z = at(i / links)
    local x2, y2, z2 = at((i + 0.6) / links)
    local dx, dy, dz = x2 - x, y2 - y, z2 - z
    local l = max(1e-5, sqrt(dx * dx + dy * dy + dz * dz))
    dx, dy, dz = dx / l, dy / l, dz / l
    local sx, sy, sz = dz, 0, -dx
    if abs(dy) > 0.95 then
      sx, sy, sz = 1, 0, 0
    end
    if i % 2 == 0 then
      sx, sy, sz = dy * sz - dz * sy, dz * sx - dx * sz, dx * sy - dy * sx
    end
    local sl = max(1e-4, sqrt(sx * sx + sy * sy + sz * sz))
    sx, sy, sz = sx / sl, sy / sl, sz / sl
    local ring = {}
    for k = 0, 12 do
      local angle = k / 12 * 2 * pi
      local along, across = cos(angle) * long, sin(angle) * wide
      ring[k + 1] = {
        x + dx * along + sx * across,
        y + dy * along + sy * across,
        z + dz * along + sz * across,
      }
    end
    B.rib(list, ring, thick, thick, shade)
  end
end
-- Same seed, same stones: the hall never depends on a random stream.
function B.random(seed)
  local state = seed * 2654435761 % 4294967296
  return function()
    state = (state * 1103515245 + 12345) % 2147483648
    return state / 2147483648
  end
end
-- A dressed block, tilted as it fell. half: half sizes along its own axes.
function B.block(list, c, half, yaw, tilt, seed, shade)
  local rng = B.random(seed)
  local cy, sy, ct, st = cos(yaw), sin(yaw), cos(tilt), sin(tilt)
  local corners = {}
  for i = 0, 7 do
    local lx = ((i % 2) * 2 - 1) * half[1] * (0.88 + rng() * 0.24)
    local ly = ((math.floor(i / 2) % 2) * 2 - 1) * half[2] * (0.88 + rng() * 0.24)
    local lz = ((math.floor(i / 4) % 2) * 2 - 1) * half[3] * (0.88 + rng() * 0.24)
    local tx, ty = lx * ct - ly * st, lx * st + ly * ct
    corners[i] = { c[1] + tx * cy - lz * sy, c[2] + ty, c[3] + tx * sy + lz * cy, lx, ly, lz }
  end
  local uo, vo = rng(), rng()
  local tone = (shade or 1) * (0.72 + rng() * 0.36)
  local function p(i, u, v)
    local q = corners[i]
    return { q[1], q[2], q[3], q[u] / 1.7 + uo, q[v] / 1.7 + vo }
  end
  for _, f in ipairs({
    { 0, 1, 3, 2, 4, 5 },
    { 4, 5, 7, 6, 4, 5 },
    { 0, 1, 5, 4, 4, 6 },
    { 2, 3, 7, 6, 4, 6 },
    { 0, 2, 6, 4, 6, 5 },
    { 1, 3, 7, 5, 6, 5 },
  }) do
    local a, e = corners[f[1]], corners[f[3]]
    B.quad(
      list,
      p(f[1], f[5], f[6]),
      p(f[2], f[5], f[6]),
      p(f[3], f[5], f[6]),
      p(f[4], f[5], f[6]),
      {
        (a[1] + e[1]) / 2 * 9 - c[1] * 8,
        (a[2] + e[2]) / 2 * 9 - c[2] * 8,
        (a[3] + e[3]) / 2 * 9 - c[3] * 8,
      },
      tone
    )
  end
end
-- A broken lump: rough facets, flat shaded. half: its half sizes.
function B.chunk(list, c, half, yaw, seed, shade)
  local rng = B.random(seed)
  local rings, sides = 4, 6
  local noise = {}
  for j = 0, rings do
    noise[j] = {}
    for i = 0, sides - 1 do
      noise[j][i] = 0.62 + rng() * 0.5
    end
    if j == 0 or j == rings then
      for i = 1, sides - 1 do
        noise[j][i] = noise[j][0]
      end
    end
  end
  local cy, sy = cos(yaw), sin(yaw)
  local uo, vo = rng(), rng()
  local function p(j, i)
    local n = noise[j][i % sides]
    local b, a = j / rings * pi, (i % sides) / sides * 2 * pi
    local lx, ly, lz =
      sin(b) * cos(a) * half[1] * n, cos(b) * half[2] * n, sin(b) * sin(a) * half[3] * n
    return {
      c[1] + lx * cy - lz * sy,
      c[2] + ly,
      c[3] + lx * sy + lz * cy,
      lx / 1.4 + uo,
      ly / 1.4 + lz / 1.4 + vo,
    }
  end
  local tone = (shade or 1) * (0.72 + rng() * 0.36)
  for j = 0, rings - 1 do
    for i = 0, sides - 1 do
      local a, b, d, e = p(j, i), p(j + 1, i), p(j + 1, i + 1), p(j, i + 1)
      local mx, my, mz = (a[1] + d[1]) / 2, (a[2] + d[2]) / 2, (a[3] + d[3]) / 2
      B.quad(list, a, b, d, e, { mx * 9 - c[1] * 8, my * 9 - c[2] * 8, mz * 9 - c[3] * 8 }, tone)
    end
  end
end
-- A block built up in steps of masonry; profile = { { inset, height }, ... }.
function B.moulded(list, x0, z0, x1, z1, y0, profile, shade)
  local function ring(inset, y)
    local a, b, c, d = x0 + inset, x1 - inset, z0 + inset, z1 - inset
    return { { a, y, c }, { b, y, c }, { b, y, d }, { a, y, d } }
  end
  local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
  local low, run = ring(profile[1][1], y0 + profile[1][2]), 0
  for i = 2, #profile do
    local high = ring(profile[i][1], y0 + profile[i][2])
    for k = 1, 4 do
      local n = k % 4 + 1
      local length = abs(low[k][1] - low[n][1]) + abs(low[k][3] - low[n][3])
      local p, q, r, s = low[k], low[n], high[n], high[k]
      B.quad(
        list,
        { p[1], p[2], p[3], run / 3.4, p[2] / 3.4 },
        { q[1], q[2], q[3], (run + length) / 3.4, q[2] / 3.4 },
        { r[1], r[2], r[3], (run + length) / 3.4, r[2] / 3.4 },
        { s[1], s[2], s[3], run / 3.4, s[2] / 3.4 },
        { (p[1] + q[1]) * 5 - cx * 9, p[2], (p[3] + q[3]) * 5 - cz * 9 },
        shade
      )
      run = run + length
    end
    low = high
  end
  local y = low[1][2]
  B.quad(
    list,
    { low[1][1], y, low[1][3], low[1][1] / 3.4, low[1][3] / 3.4 },
    { low[2][1], y, low[2][3], low[2][1] / 3.4, low[2][3] / 3.4 },
    { low[3][1], y, low[3][3], low[3][1] / 3.4, low[3][3] / 3.4 },
    { low[4][1], y, low[4][3], low[4][1] / 3.4, low[4][3] / 3.4 },
    { cx, y + 9, cz },
    shade
  )
end
-- A fallen column drum lying on the floor.
function B.drum(list, x, y, z, yaw, radius, length, shade)
  local dx, dz = cos(yaw), sin(yaw)
  local sides = 14
  for s = 0, sides - 1 do
    local a, b = s / sides * 2 * pi, (s + 1) / sides * 2 * pi
    local function p(t, ang)
      local across, up = cos(ang) * radius, sin(ang) * radius
      local jag = t == 0 and 0 or 0.11 * sin(ang * 5 + yaw * 7)
      local along = length * t + jag
      return {
        x + dx * along - dz * across,
        y + radius + up,
        z + dz * along + dx * across,
        ang / pi,
        along / 3.4,
      }
    end
    B.quad(list, p(0, a), p(1, a), p(1, b), p(0, b), {
      x + dx * length / 2 - dz * cos(a) * 9,
      y + radius + sin(a) * 9,
      z + dz * length / 2 + dx * cos(a) * 9,
    }, shade)
  end
  for _, t in ipairs({ 0, 1 }) do
    local c = { x + dx * length * t, y + radius, z + dz * length * t, 0.5, 0.5 }
    for s = 0, sides - 1 do
      local a, b = s / sides * 2 * pi, (s + 1) / sides * 2 * pi
      local function e(ang)
        local jag = t == 0 and 0 or 0.11 * sin(ang * 5 + yaw * 7)
        local along = length * t + jag
        local across, up = cos(ang) * radius, sin(ang) * radius
        return {
          x + dx * along - dz * across,
          y + radius + up,
          z + dz * along + dx * across,
          0.5 + cos(ang) * 0.18,
          0.5 + sin(ang) * 0.18,
        }
      end
      B.quad(
        list,
        c,
        e(a),
        e(b),
        c,
        { c[1] + dx * (t * 2 - 1) * 9, c[2], c[3] + dz * (t * 2 - 1) * 9 },
        shade
      )
    end
  end
end
-- A heap of rubble: a broken mound painted as loose stone, with dressed blocks
-- and chips resting on it. list: the mound's image; blocks: the blocks' image.
function B.heap(list, blocks, heap, seed)
  seed = seed or heap.seed
  local rng = B.random(seed)
  local cx, cz, radius, peak = heap.x, heap.z, heap.radius, heap.peak
  local base = heap.base or 0
  local phase = rng() * 9
  local function height(r, angle)
    local edge = radius * (0.84 + 0.16 * sin(angle * 3 + phase) * cos(angle * 2 - phase))
    local t = min(1, r / edge)
    local lump = 0.13 * sin(angle * 5 + r * 4 + phase) + 0.09 * sin(angle * 9 - r * 7)
    return max(0, peak * (1 - t * t) * (1 + lump)) + base
  end
  local rings, spokes = 12, 34
  local offsets = {}
  local function vertex(i, s)
    local key = i * 100 + s % spokes
    local o = offsets[key]
    if not o then
      o = { (rng() - 0.5) * 0.06, (rng() - 0.5) * 0.06 }
      offsets[key] = o
    end
    local r, angle = radius * i / rings, s / spokes * 2 * pi
    local x, z =
      cx + cos(angle) * r + (i > 0 and o[1] or 0), cz + sin(angle) * r + (i > 0 and o[2] or 0)
    local y = height(r, angle)
    return { x, y + (i < rings and y > base + 0.02 and o[1] * 1.6 or 0), z, x / 2.6, z / 2.6 }
  end
  for i = 0, rings - 1 do
    for s = 0, spokes - 1 do
      B.quad(
        list,
        vertex(i, s),
        vertex(i + 1, s),
        vertex(i + 1, s + 1),
        vertex(i, s + 1),
        { cx, 50, cz },
        0.72 + rng() * 0.3
      )
    end
  end
  for i = 1, heap.count do
    local big = i <= heap.count * 0.24
    local angle, r = rng() * 2 * pi, sqrt(rng()) * radius * (big and 0.78 or 0.98)
    local size = big and 0.12 + rng() * 0.15 or 0.03 + rng() ^ 2 * 0.07
    local long = 1 + rng() * 0.9
    local hy = size * (0.55 + rng() * 0.25)
    local c = { cx + cos(angle) * r, height(r, angle) + hy * 0.6, cz + sin(angle) * r }
    B.block(blocks, c, { size * long, hy, size }, rng() * pi, (rng() - 0.5) * 0.9, seed * 7919 + i)
  end
end
-- All the lists of a build, by the way each part is shown. A scope with no
-- group is always drawn; show says when a group's part is (render/kit/halls.lua).
local Sink = {}
Sink.__index = Sink
function B.sink(light)
  return setmetatable({ light = light, scopes = {}, order = {} }, Sink)
end
function Sink:scope(group, show, options)
  local key = tostring(group) .. '|' .. tostring(show)
  local scope = self.scopes[key]
  if not scope then
    local sink = self
    local lists = {}
    scope = setmetatable({}, {
      __index = function(t, image)
        local list = B.list(options and options.light or sink.light)
        rawset(t, image, list)
        lists[#lists + 1] = { image = image, list = list }
        return list
      end,
    })
    self.scopes[key] = scope
    self.order[#self.order + 1] = { group = group, show = show, options = options, lists = lists }
  end
  return scope
end
-- Vertices by image and group, in a stable order.
function Sink:parts(art)
  local out = {}
  for _, entry in ipairs(self.order) do
    for _, item in ipairs(entry.lists) do
      if #item.list > 0 then
        local name = item.image
        out[#out + 1] = {
          path = art.images[name] or art.tiles[name],
          options = art.images[name] and art.imageOptions or art.tileOptions,
          vertices = item.list,
          group = entry.group,
          show = entry.show,
          rise = entry.options and entry.options.rise,
          sway = entry.options and entry.options.sway,
        }
      end
    end
  end
  return out
end
return B
