local M = {}
local sqrt, sin, cos, pi = math.sqrt, math.sin, math.cos, math.pi
local format = {
  { 'VertexPosition', 'float', 3 },
  { 'VertexNormal', 'float', 3 },
  {
    'VertexColor',
    'float',
    4,
  },
}
function M.builder()
  return {}
end
function M.tri(v, a, b, c, col)
  local ux, uy, uz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
  local vx, vy, vz = c[1] - a[1], c[2] - a[2], c[3] - a[3]
  local nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
  local len = math.max(0.00001, sqrt(nx * nx + ny * ny + nz * nz))
  for _, p in ipairs({ a, b, c }) do
    v[#v + 1] =
      { p[1], p[2], p[3], nx / len, ny / len, nz / len, col[1], col[2], col[3], col[4] or 0 }
  end
end
function M.quad(v, a, b, c, d, col)
  M.tri(v, a, b, c, col)
  M.tri(v, a, c, d, col)
end
function M.box(v, x, y, z, w, h, d, col)
  local a, b, c, e = x - w / 2, x + w / 2, z - d / 2, z + d / 2
  local t = y + h
  M.quad(v, { a, y, c }, { a, t, c }, { b, t, c }, { b, y, c }, col)
  M.quad(v, { b, y, e }, { b, t, e }, { a, t, e }, { a, y, e }, col)
  M.quad(v, { a, y, e }, { a, t, e }, { a, t, c }, { a, y, c }, col)
  M.quad(v, { b, y, c }, { b, t, c }, { b, t, e }, { b, y, e }, col)
  M.quad(v, { a, t, c }, { a, t, e }, { b, t, e }, { b, t, c }, col)
  M.quad(v, { a, y, e }, { a, y, c }, { b, y, c }, { b, y, e }, col)
end
function M.cone(v, x, y, z, r1, r2, h, col, n)
  n = n or 10
  for i = 0, n - 1 do
    local a, b = i * 2 * pi / n, (i + 1) * 2 * pi / n
    M.quad(
      v,
      { x + cos(a) * r1, y, z + sin(a) * r1 },
      { x + cos(a) * r2, y + h, z + sin(a) * r2 },
      { x + cos(b) * r2, y + h, z + sin(b) * r2 },
      { x + cos(b) * r1, y, z + sin(b) * r1 },
      col
    )
    if r2 > 0 then
      M.tri(
        v,
        { x, y + h, z },
        { x + cos(b) * r2, y + h, z + sin(b) * r2 },
        { x + cos(a) * r2, y + h, z + sin(a) * r2 },
        col
      )
    end
  end
end
function M.sphere(v, x, y, z, rx, ry, rz, col, n)
  n = n or 10
  local rings = 6
  local function p(a, b)
    return { x + cos(a) * sin(b) * rx, y + cos(b) * ry, z + sin(a) * sin(b) * rz }
  end
  for j = 0, rings - 1 do
    for i = 0, n - 1 do
      M.quad(
        v,
        p(i * 2 * pi / n, j * pi / rings),
        p(i * 2 * pi / n, (j + 1) * pi / rings),
        p((i + 1) * 2 * pi / n, (j + 1) * pi / rings),
        p((i + 1) * 2 * pi / n, j * pi / rings),
        col
      )
    end
  end
end
function M.beam(v, a, b, r, col, n)
  n = n or 8
  local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
  local l = sqrt(dx * dx + dy * dy + dz * dz)
  if l < 0.001 then
    return
  end
  dx, dy, dz = dx / l, dy / l, dz / l
  local ux, uy, uz = -dz, 0, dx
  local ul = sqrt(ux * ux + uz * uz)
  if ul < 0.01 then
    ux, uy, uz = 1, 0, 0
  else
    ux, uz = ux / ul, uz / ul
  end
  local vx, vy, vz = dy * uz - dz * uy, dz * ux - dx * uz, dx * uy - dy * ux
  local function p(o, t)
    local c, s = cos(t) * r, sin(t) * r
    return { o[1] + ux * c + vx * s, o[2] + uy * c + vy * s, o[3] + uz * c + vz * s }
  end
  for i = 0, n - 1 do
    M.quad(
      v,
      p(a, i * 2 * pi / n),
      p(b, i * 2 * pi / n),
      p(b, (i + 1) * 2 * pi / n),
      p(a, (i + 1) * 2 * pi / n),
      col
    )
  end
end
function M.ring(v, x, y, z, r, t, col, n, vertical)
  n = n or 64
  for i = 0, n - 1 do
    local a, b = i * 2 * pi / n, (i + 1) * 2 * pi / n
    local function p(ang, rad)
      if vertical then
        return { x + cos(ang) * rad, y + sin(ang) * rad, z }
      else
        return { x + cos(ang) * rad, y, z + sin(ang) * rad }
      end
    end
    M.quad(v, p(a, r), p(b, r), p(b, r + t), p(a, r + t), col)
  end
end
function M.finish(v)
  return love.graphics.newMesh(format, v, 'triangles', 'static')
end
function M.dynamic(capacity)
  return love.graphics.newMesh(format, capacity, 'triangles', 'stream')
end
-- The tracer shader ignores normals; write its six vertices into a reused slab.
function M.traceQuad(vertices, offset, t, rx, ry, rz, alpha)
  for i = 1, 6 do
    local endpoint = i == 3 or i == 5 or i == 6
    local sign = (i == 2 or i == 3 or i == 5) and 1 or -1
    local v = vertices[offset + i]
    v[1] = (endpoint and t.x2 or t.x1) + rx * sign
    v[2] = (endpoint and t.y2 or t.y1) + ry * sign
    v[3] = (endpoint and t.z2 or t.z1) + rz * sign
    v[7], v[8], v[9], v[10] = t.color[1], t.color[2], t.color[3], alpha
  end
end

return M
