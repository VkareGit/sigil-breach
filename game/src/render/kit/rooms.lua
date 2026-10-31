-- The lesser rooms of a map: every floor, wall and ceiling comes from the map's
-- own cells and roofs, so a new room is dressed by naming its rectangle and
-- its painted wall. The wall image repeats along each run of wall.
local Art = require('src.content.art.chapel_hall')
local B = require('src.render.kit.builder')
local Light = require('src.render.kit.light')
local Props = require('src.render.kit.props')
local Ground = require('src.physics.ground')
local RoofCell = require('src.physics.roof_cell')
local Rooms = {}
local max = math.max
local DIRECTIONS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local function open(w, x, z)
  local row = w.map[z]
  return row ~= nil and row[x] ~= nil and row[x] ~= 1
end
-- How high a wall stands above the cell's floor: to the roof it meets.
local function wallTop(w, x, z)
  local top = 0
  for _, deck in ipairs(Ground.decks(w, x, z) or {}) do
    if deck[3] then
      for i = 1, 4 do
        top = max(top, deck[3][i])
      end
    else
      top = max(top, deck[1])
    end
  end
  return top > 0 and top or 4.2
end
local function wallFace(list, w, room, x, z, d)
  local px, pz = x + d[1] * 0.5, z + d[2] * 0.5
  local tx, tz = d[2] * 0.5, d[1] * 0.5
  local top = wallTop(w, x, z)
  local base = Ground.cell(w, x, z)
  local run = 0
  local tile = room.tile
  local function p(side, y)
    run = (px + tz * side) + (pz + tx * side)
    return { px + tx * side, y, pz + tz * side, run / tile.width, 1 - y / tile.height }
  end
  local rows = math.max(1, math.ceil(top - base))
  for i = 0, rows - 1 do
    local y0, y1 = base + (top - base) * i / rows, base + (top - base) * (i + 1) / rows
    B.quad(list, p(-1, y0), p(1, y0), p(1, y1), p(-1, y1), { x, 1, z })
  end
end
local function ceiling(list, w, x, z)
  for _, deck in ipairs(Ground.decks(w, x, z) or {}) do
    if deck[3] then
      local c = RoofCell.corners(deck, x, z)
      local function p(q)
        return { q[1], q[2], q[3], q[1] / 3.4, q[3] / 3.4 }
      end
      B.quad(list, p(c[1]), p(c[2]), p(c[3]), p(c[4]), { x, 0, z }, 0.8)
    end
  end
end
local function floorCell(list, risers, w, x, z)
  local h = Ground.cell(w, x, z)
  local function p(a, c)
    return { a, h, c, (a - 24) / 9 + 0.5, c / 9 }
  end
  B.quad(
    list,
    p(x - 0.5, z - 0.5),
    p(x + 0.5, z - 0.5),
    p(x + 0.5, z + 0.5),
    p(x - 0.5, z + 0.5),
    { x, h + 9, z }
  )
  for _, d in ipairs(DIRECTIONS) do
    local other = Ground.cell(w, x + d[1], z + d[2])
    if other < h and open(w, x + d[1], z + d[2]) then
      local px, pz = x + d[1] * 0.5, z + d[2] * 0.5
      local tx, tz = d[2] * 0.5, d[1] * 0.5
      local function q(side, y)
        return {
          px + tx * side,
          y,
          pz + tz * side,
          (px + tz * side + pz + tx * side) / 3.4,
          y / 3.4,
        }
      end
      B.quad(
        risers,
        q(-1, other),
        q(1, other),
        q(1, h),
        q(-1, h),
        { px + d[1] * 9, h, pz + d[2] * 9 },
        0.82
      )
    end
  end
end
local function pillar(list, w, x, z)
  local base, top = Ground.cell(w, x, z), wallTop(w, x, z)
  B.lathe(list, x, z, {
    { 0.62, base },
    { 0.62, base + 0.3 },
    { 0.5, base + 0.5 },
    { 0.46, base + 0.7 },
    { 0.46, top - 0.5 },
    { 0.62, top - 0.15 },
    { 0.62, top },
  }, 16, 1, 0.9)
end
function Rooms.build(w, hall)
  local sources = {}
  for _, lamp in ipairs(w.lamps) do
    sources[#sources + 1] = { lamp.x, 1.4, lamp.z, 1, 0.66, 0.38, 0.75, 9 }
  end
  for _, seal in ipairs(w.seals) do
    sources[#sources + 1] = { seal.x, 2.2, seal.z, 1, 0.66, 0.38, 0.5, 9 }
  end
  local light = Light.new({ ambient = hall.ambient, tone = hall.tone, sources = sources }, 0, 0, {})
  local sink = B.sink(light)
  local lists = sink:scope()
  for _, room in ipairs(hall.rooms) do
    local rect = room.rect
    for z = rect[2], rect[4] do
      for x = rect[1], rect[3] do
        local tile = w.map[z][x]
        if tile ~= 1 then
          floorCell(lists.floor, lists.ashlar, w, x, z)
          ceiling(lists.ceiling, w, x, z)
          if tile == 2 then
            pillar(lists.drum, w, x, z)
          end
          for _, d in ipairs(DIRECTIONS) do
            if not open(w, x + d[1], z + d[2]) then
              wallFace(lists[room.wall], w, room, x, z, d)
            end
          end
        end
      end
    end
  end
  for _, def in ipairs(hall.breakables or {}) do
    Props.add(sink, w, def)
  end
  return sink:parts(Art)
end
return Rooms
