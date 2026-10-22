-- What the knight sees where a ray meets a demon (plan v7 H0). The painting
-- is placed by the renderer (render/renderer.lua: enemyPlacement) and drawn by
-- the sprite shader (render/shaders.lua: sprite). This module repeats only
-- the shader's per-pixel rule, on the CPU, from the same placement:
--   - the quad's local UV is snapped to a 320 x 320 grid (texel centres);
--   - the texel's alpha is read with the image's filter (nearest atlases,
--     linear supplements; mip levels are not modelled);
--   - alpha >= 0.30 is painted body; a living body also draws a one-texel
--     sinopia contour where a neighbour's alpha > 0.5; anything else is air.
-- A ray meets the painting where it crosses the sprite's vertical plane. The
-- class of that point is the truth the hit volumes are measured against. A
-- point within one grid texel of a painted/air boundary is 'edge': the
-- band of uncertainty, reported apart, never counted as a defect or a pass.
local Catalog = require('src.render.fresco_enemies')
local AbilityArt = require('src.render.ability_art')
local Truth = {}
Truth.__index = Truth
Truth.grid = 320
Truth.cut = 0.30
Truth.contour = 0.5
local floor, cos, sin = math.floor, math.cos, math.sin
-- renderer: a loaded renderer (R.new) — its images, frames and placement.
function Truth.new(renderer)
  local t = setmetatable({ renderer = renderer, paths = {}, data = {}, sizes = {} }, Truth)
  for _, kind in ipairs(Catalog.kinds) do
    local entry = Catalog.entries[kind]
    t.paths[renderer.animations[kind]] = entry.path
    for _, replacement in ipairs(entry.replacements or {}) do
      local image = renderer.frameImages[kind][replacement.targets[1]]
      if image then
        t.paths[image] = replacement.path
      end
    end
  end
  for key, entry in pairs(AbilityArt.entries) do
    local sheet = renderer.abilityArt[key]
    if sheet then
      t.paths[sheet.image] = entry.path
    end
  end
  return t
end
function Truth:release()
  for _, data in pairs(self.data) do
    data:release()
  end
  self.data = {}
end
local function imageData(t, path)
  local data = t.data[path]
  if not data then
    data = love.image.newImageData(path)
    t.data[path] = data
    t.sizes[path] = { data:getDimensions() }
  end
  return data, t.sizes[path]
end
-- Alpha of source pixel (x, y) of an image file.
function Truth:pixel(path, x, y)
  local data, size = imageData(self, path)
  local _, _, _, a = data:getPixel(math.min(size[1] - 1, x), math.min(size[2] - 1, y))
  return a
end
-- A copy of the renderer's placement of e, with its source image path,
-- pixel size and filter: everything needed to read what is drawn.
function Truth:place(g, e, out)
  local p = self.renderer:enemyPlacement(g, e)
  out = out or {}
  for k, v in pairs(p) do
    out[k] = v
  end
  out.path = assert(self.paths[p.image], 'hit truth: unknown sprite image')
  local _, size = imageData(self, out.path)
  out.width, out.height = size[1], size[2]
  out.linear = p.image:getFilter() == 'linear'
  out.x = e.x + cos(p.yaw) * p.shift
  out.z = e.z - sin(p.yaw) * p.shift
  out.live = e.hp > 0
  local rect = p.region.rect
  out.key = string.format(
    '%s:%.6f,%.6f,%.6f,%.6f:%s',
    out.path,
    rect[1],
    rect[2],
    rect[3],
    rect[4],
    out.live and 'live' or 'dead'
  )
  return out
end
-- Alpha of the source image at atlas UV, with the image's filter.
local function alpha(t, p, au, av)
  local data = imageData(t, p.path)
  local w, h = p.width, p.height
  if not p.linear then
    local x = math.min(w - 1, math.max(0, floor(au * w)))
    local y = math.min(h - 1, math.max(0, floor(av * h)))
    local _, _, _, a = data:getPixel(x, y)
    return a
  end
  local fx, fy = au * w - 0.5, av * h - 0.5
  local x0, y0 = floor(fx), floor(fy)
  local tx, ty = fx - x0, fy - y0
  local function at(x, y)
    local _, _, _, a =
      data:getPixel(math.min(w - 1, math.max(0, x)), math.min(h - 1, math.max(0, y)))
    return a
  end
  local top = at(x0, y0) * (1 - tx) + at(x0 + 1, y0) * tx
  local bottom = at(x0, y0 + 1) * (1 - tx) + at(x0 + 1, y0 + 1) * tx
  return top * (1 - ty) + bottom * ty
end
-- The class of grid texel (i, j) of the placed sprite (0-based, j from the
-- top of the painting): 'body', 'contour' or 'air'.
local CLASSES = { 'air', 'body', 'contour' }
local CODES = { air = 1, body = 2, contour = 3 }
function Truth:texel(p, i, j)
  local n = Truth.grid
  if i < 0 or j < 0 or i >= n or j >= n then
    return 'air'
  end
  -- A frame's texels never change: classify each once per image, rect and
  -- life (the contour belongs to living bodies only).
  self.memo = self.memo or {}
  local memo = self.memo[p.key]
  if not memo then
    memo = {}
    self.memo[p.key] = memo
  end
  local index = j * n + i
  local code = memo[index]
  if code then
    return CLASSES[code]
  end
  local class = self:texelUncached(p, i, j)
  memo[index] = CODES[class]
  return class
end
function Truth:texelUncached(p, i, j)
  local n = Truth.grid
  local rect = p.region.rect
  local lu, lv = (i + 0.5) / n, (j + 0.5) / n
  local au, av = rect[1] + lu * rect[3], rect[2] + lv * rect[4]
  if alpha(self, p, au, av) >= Truth.cut then
    return 'body'
  end
  if p.live then
    local su, sv = rect[3] / n, rect[4] / n
    local lo1, lo2 = rect[1] + su * 0.5, rect[2] + sv * 0.5
    local hi1, hi2 = rect[1] + rect[3] - su * 0.5, rect[2] + rect[4] - sv * 0.5
    local function near(du, dv)
      local u = math.min(hi1, math.max(lo1, au + du))
      local v = math.min(hi2, math.max(lo2, av + dv))
      return alpha(self, p, u, v) > Truth.contour
    end
    if near(su, 0) or near(-su, 0) or near(0, sv) or near(0, -sv) then
      return 'contour'
    end
  end
  return 'air'
end
-- Grid texel of a point in the sprite's quad (quad u, v in [0, 1], v up);
-- mirror applied as the shader does.
function Truth.cell(p, u, v)
  local su = p.mirror > 0.5 and 1 - u or u
  return floor(su * Truth.grid), floor((1 - v) * Truth.grid)
end
-- Quad coordinates (u, v up) of a world point on the sprite's plane.
function Truth.quad(p, wx, wy, wz)
  local s = (wx - p.x) * cos(p.yaw) - (wz - p.z) * sin(p.yaw)
  local y0 = (wy - p.baseY) / p.size
  local x0 = s / p.size - y0 * p.lean
  return x0 / p.sx + 0.5, y0 / p.sy
end
-- The world point of quad coordinates (u, v up).
function Truth.world(p, u, v)
  local y0 = v * p.sy
  local s = ((u - 0.5) * p.sx + y0 * p.lean) * p.size
  return p.x + cos(p.yaw) * s, p.baseY + y0 * p.size, p.z - sin(p.yaw) * s
end
-- Quad coordinates of a source pixel (px, py) of the placed frame's image.
function Truth.fromPixel(p, px, py)
  local rect = p.region.rect
  local lu = ((px + 0.5) / p.width - rect[1]) / rect[3]
  local lv = ((py + 0.5) / p.height - rect[2]) / rect[4]
  local u = p.mirror > 0.5 and 1 - lu or lu
  return u, 1 - lv
end
-- The class of the drawn point at quad (u, v); edge: a neighbouring grid
-- texel is of the other kind (painted versus air).
function Truth:classify(p, u, v)
  if u < 0 or u >= 1 or v < 0 or v > 1 then
    return 'air', false
  end
  local i, j = Truth.cell(p, u, v)
  local class = self:texel(p, i, j)
  local painted = class ~= 'air'
  if class == 'contour' then
    return class, true
  end
  for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
    if (self:texel(p, i + d[1], j + d[2]) ~= 'air') ~= painted then
      return class, true
    end
  end
  return class, false
end
-- Where a ray (origin o, unit direction d) crosses the sprite's plane:
-- distance along the ray and quad (u, v); nil when it runs along it or away.
function Truth.cross(p, ox, oy, oz, dx, dy, dz)
  local nx, nz = sin(p.yaw), cos(p.yaw)
  local denom = dx * nx + dz * nz
  if math.abs(denom) < 1e-9 then
    return nil
  end
  local t = ((p.x - ox) * nx + (p.z - oz) * nz) / denom
  if t < 0 then
    return nil
  end
  local u, v = Truth.quad(p, ox + dx * t, oy + dy * t, oz + dz * t)
  return t, u, v
end
return Truth
