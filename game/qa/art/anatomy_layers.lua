-- Anatomy from part layers (plan v10 V7): each part of a creature painted as
-- its own mask over the source image (a PNG of the same size; opaque =
-- the part). For every frame of the atlas the part's region is its mask
-- inside the frame, traced row by row into a polygon (the left edge down,
-- the right edge up) in frame UV; the frame-wide fallback comes first, the
-- parts after it in legend order (the last that covers a pixel wins). The
-- result is an ordinary annotation: export it (qa/art/anatomy_export.lua)
-- and bake the masks (BAKE-HIT-MASKS.ps1) as for any other.
--   legend = { body = material, parts = { { id, zone, material,
--              hittable?, masks = { [source path] = mask path } }... } }
local Author = require('src.content.art.anatomy.author')
local Sheet = require('src.content.art.sheet')
local Layers = {}
local OPAQUE = 0.5
-- The rows traced per frame: a polygon of about this many points a side.
local SAMPLES = 24
-- The part's polygon inside a frame's pixel rectangle, or nil when the mask
-- has fewer than two rows of it there (size: the source's pixel size; frame
-- UV as content/art/anatomy/author.lua: fromPixels).
function Layers.trace(mask, frame, size, x0, x1, y0, y1)
  local function span(y)
    local first, last
    for x = x0, x1 do
      local _, _, _, a = mask:getPixel(x, y)
      if a > OPAQUE then
        first = first or x
        last = x
      end
    end
    return first, last
  end
  local top, bottom
  for y = y0, y1 do
    if span(y) then
      top, bottom = top or y, y
    end
  end
  if not top or bottom == top then
    return nil
  end
  -- Rows from the part's top to its bottom, both included.
  local step =
    math.max(1, math.min(math.floor((y1 - y0 + 1) / SAMPLES), math.floor((bottom - top) / 2)))
  local left, right = {}, {}
  local y = top
  while true do
    local first, last = span(y)
    if first then
      left[#left + 1] = { first, y }
      right[#right + 1] = { last + 1, y }
    end
    if y == bottom then
      break
    end
    y = math.min(bottom, y + step)
  end
  if #left < 2 then
    return nil
  end
  local polygon = {}
  local function add(x, y)
    local r = frame.rect
    local u, v = (x / size[1] - r[1]) / r[3], (y / size[2] - r[2]) / r[4]
    polygon[#polygon + 1] = math.max(0, math.min(1, u))
    polygon[#polygon + 1] = math.max(0, math.min(1, v))
  end
  for _, p in ipairs(left) do
    add(p[1], p[2])
  end
  add(left[#left][1], left[#left][2] + 1)
  add(right[#right][1], right[#right][2] + 1)
  for i = #right, 1, -1 do
    add(right[i][1], right[i][2])
  end
  return polygon
end
-- The annotation of a sheet's frames from a legend of part masks.
function Layers.annotation(sheet, legend)
  local layout = Sheet.layout(sheet)
  local cache, annotation = {}, { frames = {} }
  local function mask(path)
    cache[path] = cache[path] or love.image.newImageData(path)
    return cache[path]
  end
  for index, frame in ipairs(layout.frames) do
    local spec = sheet.frames[index]
    local source = sheet.sources[spec.source]
    local x0, x1, y0, y1 = Sheet.cut(source, spec.cell)
    local parts = { Author.body(legend.body) }
    for _, p in ipairs(legend.parts) do
      local path = p.masks[frame.sourcePath]
      local polygon = path and Layers.trace(mask(path), frame, source.size, x0, x1, y0, y1)
      if polygon then
        local part = Author.part(p.id, p.zone, p.material, polygon)
        if p.hittable == false then
          part.hittable = false
        end
        parts[#parts + 1] = part
      end
    end
    annotation.frames[index] = { parts = parts }
  end
  for _, data in pairs(cache) do
    data:release()
  end
  return annotation
end
return Layers
