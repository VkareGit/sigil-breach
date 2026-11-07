-- A painted surface as a wall: the image is laid straight on and the surface's
-- layout pushes the wall in and out under it, so a niche has real depth.
local ChapelHall = require('src.content.art.chapel_hall')
local Builder = require('src.render.kit.builder')
local Relief = {}
local sqrt, ceil, max, min = math.sqrt, math.ceil, math.max, math.min
local e = 0.03
local smooth = require('src.core.mathx').smoothstep
-- frame: origin x, z (where u = from stands), along ux, uz; facing nx, nz;
-- from, to: the part of the surface used (metres of u);
-- split(along, v): the list of a part of the wall that can fall, or nil.
function Relief.wall(list, surface, frame)
  local from, to = frame.from or 0, frame.to or surface.width
  local detailed = false
  for _, f in ipairs(surface.features) do
    detailed = detailed or f.kind == 'niche' or f.kind == 'panel'
  end
  local step = detailed and 0.14 or 0.6
  local nu, nv = ceil((to - from) / step), ceil(surface.height / step)
  local rows = {}
  for iv = 0, nv do
    local row = {}
    local v = surface.height * iv / nv
    for iu = 0, nu do
      local u = from + (to - from) * iu / nu
      local d = ChapelHall.relief(surface, u, v)
      local du = (ChapelHall.relief(surface, u + e, v) - ChapelHall.relief(surface, u - e, v))
        / (2 * e)
      local dv = (ChapelHall.relief(surface, u, v + e) - ChapelHall.relief(surface, u, v - e))
        / (2 * e)
      local nx, ny, nz = frame.nx - frame.ux * du, -dv, frame.nz - frame.uz * du
      local l = sqrt(nx * nx + ny * ny + nz * nz)
      row[iu] = {
        frame.x + frame.ux * (u - from) + frame.nx * d,
        v,
        frame.z + frame.uz * (u - from) + frame.nz * d,
        nx / l,
        ny / l,
        nz / l,
        u / surface.width,
        1 - v / surface.height,
        (0.5 + 0.5 * smooth(-0.62, 0, d)) * (frame.shade or 1),
      }
    end
    rows[iv] = row
  end
  for iv = 0, nv - 1 do
    local low, high = rows[iv], rows[iv + 1]
    for iu = 0, nu - 1 do
      local a, b, c, d = low[iu], low[iu + 1], high[iu + 1], high[iu]
      local into = list
      if frame.split then
        local along = frame.z + frame.uz * ((iu + 0.5) / nu * (to - from))
        into = frame.split(along, (a[2] + c[2]) / 2) or list
      end
      Builder.put(into, a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9])
      Builder.put(into, b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9])
      Builder.put(into, c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9])
      Builder.put(into, a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9])
      Builder.put(into, c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9])
      Builder.put(into, d[1], d[2], d[3], d[4], d[5], d[6], d[7], d[8], d[9])
    end
  end
end
return Relief
