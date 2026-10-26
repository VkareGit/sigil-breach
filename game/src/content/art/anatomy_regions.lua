-- Semantic anatomy annotations of the existing paintings, never silhouette guesses.
-- Each authored frame lists arbitrary stable part IDs with independent damage zones
-- and materials. Polygons use local UV, top-left origin; last matching part wins.
-- A surface with hittable=false is decorative; zone=false can still block a shot.
-- layouts: by annotation id (content/art/anatomy/index.lua); an atlas is
-- annotated under its own id, and a creature may name another annotation of
-- the same frames (appearance.regions).
local Materials = require('src.content.ballistic_surfaces')
local Sequences = require('src.content.ability_art')
local resolved = setmetatable({}, { __mode = 'k' })
local Anatomy = {
  layouts = {},
  abilities = setmetatable({}, {
    __index = function(_, id)
      local entry = Sequences.entries[id]
      if not entry then
        return nil
      end
      if not resolved[entry] then
        resolved[entry] = type(entry.anatomy) == 'string' and require(entry.anatomy)
          or entry.anatomy
      end
      return resolved[entry]
    end,
  }),
}
local annotations = require('src.content.art.anatomy.index')
local ids = {}
for id in pairs(annotations) do
  ids[#ids + 1] = id
end
table.sort(ids)
for _, id in ipairs(ids) do
  Anatomy.layouts[id] = require(annotations[id])
end
local ZONES = { head = true, torso = true, lower = true }
local function polygonProblem(poly)
  if type(poly) ~= 'table' or #poly < 6 or #poly % 2 ~= 0 then
    return 'polygon size'
  end
  for _, value in ipairs(poly) do
    if type(value) ~= 'number' or value ~= value or value < -0.25 or value > 1.25 then
      return 'polygon far outside the frame'
    end
  end
  -- A region may cross the frame edge: the pigment mask clips it later.
  -- Reject collapsed/collinear regions, without rounding narrow authored parts.
  local twiceArea = 0
  for i = 1, #poly, 2 do
    local j = i + 2 > #poly and 1 or i + 2
    twiceArea = twiceArea + poly[i] * poly[j + 1] - poly[j] * poly[i + 1]
  end
  if twiceArea == 0 then
    return 'polygon has zero area'
  end
end
local function coversFrame(poly)
  if type(poly) ~= 'table' or #poly ~= 8 then
    return false
  end
  local corners = {}
  for i = 1, 8, 2 do
    local x, y = poly[i], poly[i + 1]
    if not ((x == 0 or x == 1) and (y == 0 or y == 1)) then
      return false
    end
    local key = x + y * 2
    if corners[key] then
      return false
    end
    corners[key] = true
  end
  for i = 1, 8, 2 do
    local x, y = poly[i], poly[i + 1]
    local j = i == 7 and 1 or i + 2
    -- Adjacent corners follow the perimeter, in either winding direction.
    -- A bow-tie has all four corners but is not a frame-wide fallback.
    if math.abs(x - poly[j]) + math.abs(y - poly[j + 1]) ~= 1 then
      return false
    end
  end
  return true
end
-- What is wrong with one annotated frame (none: an empty list): stable string
-- ids, a damage zone or false, a known material, polygons at the frame (a
-- region may be traced past its edge, the mask clips it, never far from it:
-- that is a coordinate in the wrong units), a frame-wide fallback first, a
-- hittable head, named anchors inside the frame. tests/cases/anatomy_data.lua
-- holds every shipped frame to it; a new annotation is held to the same.
function Anatomy.problems(frame, where)
  local out = {}
  local function fail(message)
    out[#out + 1] = message .. ' at ' .. where
  end
  local ids, heads = {}, 0
  for n, part in ipairs(frame.parts) do
    if type(part.id) ~= 'string' or ids[part.id] then
      fail('part id ' .. tostring(part.id))
    end
    ids[part.id or n] = true
    if not (part.zone == false or ZONES[part.zone]) then
      fail('zone ' .. tostring(part.zone))
    end
    if not Materials[part.material] then
      fail('material ' .. tostring(part.material))
    end
    if part.hittable ~= nil and type(part.hittable) ~= 'boolean' then
      fail('hittable')
    end
    local poly = part.polygon
    local problem = polygonProblem(poly)
    if problem then
      fail(problem .. ' ' .. tostring(part.id))
    end
    heads = heads + (part.zone == 'head' and part.hittable ~= false and 1 or 0)
  end
  local first = frame.parts[1] and frame.parts[1].polygon
  if not coversFrame(first) then
    fail('no frame-wide fallback region first')
  end
  if heads == 0 then
    fail('no head region')
  end
  for name, point in pairs(frame.anchors or {}) do
    if
      type(name) ~= 'string'
      or not (point[1] >= 0 and point[1] <= 1 and point[2] >= 0 and point[2] <= 1)
    then
      fail('anchor ' .. tostring(name))
    end
  end
  return out
end
return Anatomy
