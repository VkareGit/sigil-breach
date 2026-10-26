-- Spatial authoring is validated before a world allocates cells or a renderer
-- sees it. Elevations are a heightfield, not overlapping platform solids.
local MathX = require('src.core.mathx')
local Schema = {}
local function number(value, name)
  assert(MathX.finite(value), name .. ' must be finite')
end
local function cell(value, size, name)
  number(value, name)
  assert(value % 1 == 0 and value >= 1 and value <= size, name .. ' is outside the cell grid')
end
local function spot(value, name)
  assert(type(value) == 'table', name .. ' needs coordinates')
  number(value.x, name .. '.x')
  number(value.z, name .. '.z')
  if value.y ~= nil then
    number(value.y, name .. '.y')
  end
end
local function positive(value, name)
  number(value, name)
  assert(value > 0, name .. ' must be positive')
end
local function integer(value, name, minimum, maximum)
  number(value, name)
  assert(
    value % 1 == 0 and value >= minimum and (not maximum or value <= maximum),
    name .. ' is outside its integer range'
  )
end
local function list(value, name)
  assert(type(value) == 'table', name .. ' must be a list')
  local count = 0
  for key in pairs(value) do
    integer(key, name .. ' index', 1)
    count = count + 1
  end
  for i = 1, count do
    assert(value[i] ~= nil, name .. ' must not contain holes')
  end
end
function Schema.check(map, id)
  local label = 'map ' .. id
  -- width (x) and depth (z) in cells, or size for a square map.
  local width, depth = map.width or map.size, map.depth or map.size
  number(width, label .. '.width')
  number(depth, label .. '.depth')
  assert(
    width >= 1 and width % 1 == 0 and depth >= 1 and depth % 1 == 0,
    label .. ' needs integer width and depth (or size)'
  )
  local function cellX(value, name)
    cell(value, width, name)
  end
  local function cellZ(value, name)
    cell(value, depth, name)
  end
  number(map.floor or 0, label .. '.floor')
  if map.stepHeight ~= nil then
    number(map.stepHeight, label .. '.stepHeight')
    assert(map.stepHeight >= 0, label .. '.stepHeight must be non-negative')
  end
  assert(type(map.rooms) == 'table', label .. ' needs rooms')
  for _, key in ipairs({
    'rooms',
    'pillars',
    'zones',
    'lamps',
    'seals',
    'gates',
    'elevations',
    'decks',
  }) do
    if map[key] then
      list(map[key], label .. '.' .. key)
    end
  end
  if map.emberClear ~= nil then
    number(map.emberClear, label .. '.emberClear')
    assert(map.emberClear >= 0, label .. '.emberClear must be non-negative')
  end
  local opened = {}
  for _, area in ipairs(map.rooms) do
    for i = 1, 4 do
      if i % 2 == 1 then
        cellX(area[i], label .. '.room.x')
      else
        cellZ(area[i], label .. '.room.z')
      end
    end
    assert(area[1] <= area[3] and area[2] <= area[4], label .. ' room bounds are reversed')
    for z = area[2], area[4] do
      opened[z] = opened[z] or {}
      for x = area[1], area[3] do
        opened[z][x] = true
      end
    end
  end
  for _, p in ipairs(map.pillars or {}) do
    cellX(p[1], label .. '.pillar.x')
    cellZ(p[2], label .. '.pillar.z')
    assert(opened[p[2]] and opened[p[2]][p[1]], label .. ' pillar outside open room')
  end
  for _, key in ipairs({ 'spawn', 'portal', 'ember' }) do
    spot(map[key], label .. '.' .. key)
  end
  number(map.spawn.yaw, label .. '.spawn.yaw')
  assert(type(map.zones) == 'table' and #map.zones > 0, label .. ' needs zones')
  for _, zone in ipairs(map.zones) do
    assert(type(zone.name) == 'string' and #zone.name > 0, label .. ' zone needs a name')
    for _, axis in ipairs({ 'xBelow', 'xAbove', 'zBelow', 'zAbove' }) do
      if zone[axis] ~= nil then
        number(zone[axis], label .. '.zone.' .. axis)
      end
    end
  end
  for key, anchor in pairs(map.anchors or {}) do
    spot(anchor, label .. '.anchors.' .. key)
  end
  for _, gate in ipairs(map.gates or {}) do
    spot(gate, label .. '.gate')
  end
  for _, seal in ipairs(map.seals or {}) do
    spot(seal, label .. '.seal')
    assert(
      type(seal.name) == 'string' and type(seal.court) == 'string',
      label .. '.seal needs name and court'
    )
    list(seal.color, label .. '.seal.color')
    assert(#seal.color == 3, label .. '.seal.color requires RGB')
    for _, component in ipairs(seal.color) do
      number(component, label .. '.seal.color')
      assert(component >= 0 and component <= 1, label .. '.seal.color outside [0,1]')
    end
  end
  if #(map.lamps or {}) > 0 then
    number(map.lampHeight, label .. '.lampHeight')
  end
  for _, lamp in ipairs(map.lamps or {}) do
    number(lamp[1], label .. '.lamp.x')
    number(lamp[2], label .. '.lamp.z')
    if lamp[3] ~= nil then
      number(lamp[3], label .. '.lamp.surface')
    end
  end
  local used = {}
  for _, area in ipairs(map.elevations or {}) do
    for _, key in ipairs({ 'x1', 'x2', 'z1', 'z2' }) do
      if key:sub(1, 1) == 'x' then
        cellX(area[key], label .. '.elevation.' .. key)
      else
        cellZ(area[key], label .. '.elevation.' .. key)
      end
    end
    number(area.height, label .. '.elevation.height')
    assert(area.height >= 0, label .. ': elevation is measured above the floor datum')
    assert(area.x1 <= area.x2 and area.z1 <= area.z2, label .. ': elevation bounds reversed')
    for z = area.z1, area.z2 do
      used[z] = used[z] or {}
      for x = area.x1, area.x2 do
        assert(opened[z] and opened[z][x], label .. ': elevation outside open floor')
        assert(not used[z][x], label .. ': overlapping elevation regions')
        used[z][x] = true
      end
    end
  end
  -- Decks (plan v10 V3): slabs over open floor, top m over the datum and
  -- thickness m deep, leaving room under them; two decks of a cell never
  -- overlap.
  local slabs = {}
  for _, area in ipairs(map.decks or {}) do
    for _, key in ipairs({ 'x1', 'x2', 'z1', 'z2' }) do
      if key:sub(1, 1) == 'x' then
        cellX(area[key], label .. '.deck.' .. key)
      else
        cellZ(area[key], label .. '.deck.' .. key)
      end
    end
    positive(area.top, label .. '.deck.top')
    positive(area.thickness, label .. '.deck.thickness')
    assert(area.x1 <= area.x2 and area.z1 <= area.z2, label .. ': deck bounds reversed')
    local bottom = area.top - area.thickness
    for z = area.z1, area.z2 do
      slabs[z] = slabs[z] or {}
      for x = area.x1, area.x2 do
        assert(opened[z] and opened[z][x], label .. ': deck outside open floor')
        local floor = 0
        for _, e in ipairs(map.elevations or {}) do
          if x >= e.x1 and x <= e.x2 and z >= e.z1 and z <= e.z2 then
            floor = e.height
          end
        end
        assert(bottom > floor, label .. ': a deck must leave room above the floor under it')
        for _, other in ipairs(slabs[z][x] or {}) do
          assert(bottom >= other[2] or area.top <= other[1], label .. ': overlapping decks')
        end
        slabs[z][x] = slabs[z][x] or {}
        table.insert(slabs[z][x], { bottom, area.top })
      end
    end
  end
  local decor = map.decor or {}
  for _, key in ipairs({
    'arches',
    'rituals',
    'aisles',
    'banners',
    'candles',
    'reliquaries',
    'murals',
    'props',
  }) do
    if decor[key] then
      list(decor[key], label .. '.decor.' .. key)
    end
    for _, item in ipairs(decor[key] or {}) do
      spot(item, label .. '.decor.' .. key)
    end
  end
  if decor.portal then
    spot(decor.portal, label .. '.decor.portal')
    number(decor.portal.y, label .. '.decor.portal.y')
    positive(decor.portal.radius, label .. '.decor.portal.radius')
    assert(decor.portal.radius > 0.2, label .. '.decor.portal radius cannot invert its inner ring')
  end
  for _, arch in ipairs(decor.arches or {}) do
    for _, key in ipairs({ 'halfSpan', 'spring', 'rise' }) do
      positive(arch[key], label .. '.arch.' .. key)
    end
  end
  for _, ritual in ipairs(decor.rituals or {}) do
    list(ritual.rings, label .. '.ritual.rings')
    for _, radius in ipairs(ritual.rings) do
      positive(radius, label .. '.ritual.radius')
    end
    positive(ritual.orbit, label .. '.ritual.orbit')
    integer(ritual.seals, label .. '.ritual.seals', 0)
  end
  for _, aisle in ipairs(decor.aisles or {}) do
    positive(aisle.length, label .. '.aisle.length')
  end
  for _, banner in ipairs(decor.banners or {}) do
    assert(banner.side == 1 or banner.side == -1, label .. '.banner.side must be -1 or 1')
  end
  for _, mural in ipairs(decor.murals or {}) do
    integer(mural.frame, label .. '.mural.frame', 1, 4)
    positive(mural.size, label .. '.mural.size')
    number(mural.y, label .. '.mural.y')
    number(mural.yaw, label .. '.mural.yaw')
  end
  for _, prop in ipairs(decor.props or {}) do
    integer(prop.frame, label .. '.prop.frame', 1, 8)
    positive(prop.size, label .. '.prop.size')
    positive(prop.brightness, label .. '.prop.brightness')
  end
  if decor.muralWalls then
    list(decor.muralWalls, label .. '.muralWalls')
    for _, rect in ipairs(decor.muralWalls) do
      list(rect, label .. '.muralWalls rectangle')
      assert(#rect == 4, label .. '.muralWalls rectangle needs four cell coordinates')
      for index, coord in ipairs(rect) do
        if index % 2 == 1 then
          cellX(coord, label .. '.muralWalls x')
        else
          cellZ(coord, label .. '.muralWalls z')
        end
      end
      assert(rect[1] <= rect[3] and rect[2] <= rect[4], label .. '.muralWalls bounds reversed')
    end
  end
end
return Schema
