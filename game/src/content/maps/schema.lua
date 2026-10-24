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
  number(map.size, label .. '.size')
  assert(map.size >= 1 and map.size % 1 == 0, label .. ' needs an integer size')
  number(map.floor or 0, label .. '.floor')
  if map.stepHeight ~= nil then
    number(map.stepHeight, label .. '.stepHeight')
    assert(map.stepHeight >= 0, label .. '.stepHeight must be non-negative')
  end
  assert(type(map.rooms) == 'table', label .. ' needs rooms')
  for _, key in ipairs({ 'rooms', 'pillars', 'zones', 'lamps', 'seals', 'gates', 'elevations' }) do
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
      cell(area[i], map.size, label .. '.room')
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
    cell(p[1], map.size, label .. '.pillar.x')
    cell(p[2], map.size, label .. '.pillar.z')
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
  end
  local used = {}
  for _, area in ipairs(map.elevations or {}) do
    for _, key in ipairs({ 'x1', 'x2', 'z1', 'z2' }) do
      cell(area[key], map.size, label .. '.elevation.' .. key)
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
      for _, coord in ipairs(rect) do
        cell(coord, map.size, label .. '.muralWalls coordinate')
      end
      assert(rect[1] <= rect[3] and rect[2] <= rect[4], label .. '.muralWalls bounds reversed')
    end
  end
end
return Schema
