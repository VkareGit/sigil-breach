-- Small data constructors for manually reviewed anatomy, and the one
-- coordinate convention every region is stored in:
--   FRAME UV — u across, v down, from the top-left corner of the frame's
--   drawn rectangle in its source image; 0..1 inside the frame.
-- Regions may be traced in other units; these convert them explicitly, from
-- the frame's metadata (content/art/enemy_frames.lua, ability_frames.lua: its
-- source image and rect) and the source's pixel size (content/art/sources):
--   fromPixels(frame, x, y)                   a pixel of the source image
--   fromCell(frame, cell, cols, rows, x, y)   a pixel inside cell (1-based,
--                                             row by row) of a cols x rows grid
--                                             laid over the source image
--   cellPolygon(frame, cell, cols, rows, poly) the same for a polygon, clamped
--                                             to the frame
-- Constructors never inspect alpha or infer anatomy; the hit engine clips the
-- authored regions by the baked pigment mask (enemies/surface.lua).
local Sources = require('src.content.art.sources')
local Author = {}
function Author.size(frame)
  return assert(Sources[frame.sourcePath], 'unknown source size: ' .. tostring(frame.sourcePath))
end
function Author.fromPixels(frame, x, y)
  local size, r = Author.size(frame), frame.rect
  return (x / size[1] - r[1]) / r[3], (y / size[2] - r[2]) / r[4]
end
function Author.fromCell(frame, cell, columns, rows, x, y)
  local size = Author.size(frame)
  local w, h = size[1] / columns, size[2] / rows
  return Author.fromPixels(
    frame,
    (cell - 1) % columns * w + x,
    math.floor((cell - 1) / columns) * h + y
  )
end
local function clamp01(value)
  return math.max(0, math.min(1, value))
end
function Author.cellPolygon(frame, cell, columns, rows, polygon)
  local out = {}
  for i = 1, #polygon, 2 do
    local u, v = Author.fromCell(frame, cell, columns, rows, polygon[i], polygon[i + 1])
    out[i], out[i + 1] = clamp01(u), clamp01(v)
  end
  return out
end
-- A part: stable id, damage zone (head, torso, lower; false = blocks a shot
-- without a wound), ballistic material (content/ballistic_surfaces.lua) and
-- its polygon (copied: one table per part).
function Author.part(id, zone, material, polygon)
  local points = {}
  for i, value in ipairs(polygon) do
    points[i] = value
  end
  return { id = id, zone = zone, material = material, polygon = points }
end
function Author.box(id, zone, material, left, top, right, bottom)
  return Author.part(id, zone, material, { left, top, right, top, right, bottom, left, bottom })
end
function Author.head(cx, top, bottom, radius, material)
  local h = bottom - top
  return Author.part('head', 'head', material or 'flesh', {
    cx - radius * 0.7,
    top,
    cx + radius * 0.7,
    top,
    cx + radius,
    top + h * 0.25,
    cx + radius,
    bottom - h * 0.28,
    cx,
    bottom,
    cx - radius,
    bottom - h * 0.28,
    cx - radius,
    top + h * 0.25,
  })
end
function Author.segment(id, zone, material, ax, ay, bx, by, radius)
  local dx, dy = bx - ax, by - ay
  local length = math.sqrt(dx * dx + dy * dy)
  local nx, ny = -dy / length * radius, dx / length * radius
  return Author.part(
    id,
    zone,
    material,
    { ax + nx, ay + ny, bx + nx, by + ny, bx - nx, by - ny, ax - nx, ay - ny }
  )
end
-- Painted but never met by a shot (a flame, light): drawn, no contact.
function Author.effect(id, polygon)
  local part = Author.part(id, false, 'effect', polygon)
  part.hittable = false
  return part
end
-- The fallback region under all others: any pigment no later part claims.
function Author.body(material)
  return Author.box('torso', 'torso', material or 'flesh', 0, 0, 1, 1)
end
return Author
