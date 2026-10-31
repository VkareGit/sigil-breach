-- Light baked into a hall's vertices: the tear, the fires, soft contact under
-- what stands on the floor, and the piers' long shadows thrown from the tear.
local L = {}
L.__index = L
local sqrt, max, min = math.sqrt, math.max, math.min
local function smooth(a, b, x)
  local t = max(0, min(1, (x - a) / (b - a)))
  return t * t * (3 - 2 * t)
end
-- spec: the kit's light; x, rear: the hall axis and rear wall; blockers: { x, z, r }.
function L.new(spec, x, rear, blockers)
  local sources = {}
  for i, s in ipairs(spec.sources) do
    sources[i] = { s[1] + x, s[2], s[3] + rear, s[4], s[5], s[6], s[7], s[8] }
  end
  return setmetatable({ spec = spec, sources = sources, blockers = blockers }, L)
end
-- How much of the way from (x, z) to the tear no blocker stands in.
local function open(self, x, z)
  local s = self.sources[1]
  local tx, tz = s[1] - x, s[3] - z
  local length = max(1e-4, sqrt(tx * tx + tz * tz))
  tx, tz = tx / length, tz / length
  local visible = 1
  for _, b in ipairs(self.blockers) do
    local bx, bz = b.x - x, b.z - z
    local along = bx * tx + bz * tz
    if along > b.r * 0.4 and along < length then
      local across = math.abs(bx * tz - bz * tx)
      local soft = b.r * 0.55 + along * 0.05
      visible = visible * (0.34 + 0.66 * smooth(b.r - soft, b.r + soft, across))
    end
  end
  return visible
end
local function contact(self, x, z)
  local shade = 1
  for _, b in ipairs(self.blockers) do
    local dx, dz = x - b.x, z - b.z
    local d = sqrt(dx * dx + dz * dz)
    shade = shade * (0.48 + 0.52 * smooth(b.r * 0.9, b.r + 1.0, d))
  end
  return shade
end
function L:at(x, y, z, nx, ny, nz)
  local a = self.spec.ambient
  local r, g, b = a[1], a[2], a[3]
  local reach = y < 4 and open(self, x, z) or 1
  for i, s in ipairs(self.sources) do
    local dx, dy, dz = s[1] - x, s[2] - y, s[3] - z
    local d2 = dx * dx + dy * dy + dz * dz
    local d = sqrt(d2) + 1e-5
    local ndl = max(0, (nx * dx + ny * dy + nz * dz) / d)
    local f = s[7] / (1 + d2 / s[8]) * (0.28 + ndl * 0.72)
    if i == 1 then
      f = f * reach
    end
    r, g, b = r + s[4] * f, g + s[5] * f, b + s[6] * f
  end
  local k = 0.35 + 0.65 * smooth(15, 7, y)
  if y < 0.9 and ny > 0.5 then
    k = k * (1 + (contact(self, x, z) - 1) * (1 - y / 0.9))
  end
  local tone = self.spec.tone
  return r / (1 + r * tone) * k, g / (1 + g * tone) * k, b / (1 + b * tone) * k
end
return L
