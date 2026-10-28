-- The proving basilica is authored independently of the campaign arena.
-- Axial nave -> raised presbytery; two quiet aisles -> two duelling chapels.
-- Roofs are real deck solids: shots, jumps, light and the mesh share them.
local map = {
  id = 'proving',
  size = 33,
  floor = 0,
  anchors = { secret = { x = 10, z = 3 }, boss = { x = 16, z = 8 } },
  rooms = {
    { 11, 10, 21, 30 }, -- three naves, uninterrupted centre
    { 9, 23, 23, 30 }, -- wider narthex: weapon racks and physics stations
    { 14, 2, 18, 10 }, -- presbytery, altar on two real steps
    { 2, 10, 9, 22 },
    { 23, 10, 30, 22 }, -- enclosed combat chapels
    { 9, 15, 11, 18 },
    { 21, 15, 23, 18 }, -- broad chapel entrances
    { 8, 2, 12, 8 },
    { 20, 2, 24, 8 }, -- smaller creature chapels
    { 12, 6, 14, 8 },
    { 18, 6, 20, 8 },
  },
  pillars = {},
  elevations = {
    { x1 = 14, z1 = 4, x2 = 18, z2 = 5, height = 0.16 },
    { x1 = 14, z1 = 2, x2 = 18, z2 = 3, height = 0.32 },
  },
  seals = {
    {
      x = 4.1,
      z = 17,
      id = 'asmoday',
      name = 'seal_asmoday',
      court = 'court_embers',
      color = { 0.8, 0.35, 0.12 },
      summoning = true,
    },
    {
      x = 27.9,
      z = 17,
      id = 'furfur',
      name = 'creature_furfur',
      court = 'court_stars',
      color = { 0.65, 0.42, 0.24 },
      summoning = true,
    },
    {
      x = 16,
      z = 3.5,
      id = 'buer',
      name = 'seal_buer',
      court = 'court_resin',
      color = { 0.38, 0.55, 0.35 },
    },
  },
  portal = { x = 16, z = 2.9 },
  spawn = { x = 16, z = 27.5, yaw = math.pi },
  lamps = {
    { 11, 28 },
    { 21, 28 },
    { 11, 23 },
    { 21, 23 },
    { 11, 18 },
    { 21, 18 },
    { 11, 13 },
    { 21, 13 },
    { 3, 15.5 },
    { 29, 15.5 },
    { 3, 21 },
    { 29, 21 },
    { 9, 7 },
    { 23, 7 },
    { 14, 4 },
    { 18, 4 },
  },
  lampHeight = 1.18,
  emberClear = 2,
  ember = { x = 18, z = 26 },
  gates = {},
  zones = {
    { name = 'zone_court_of_embers', xBelow = 10 },
    { name = 'zone_court_of_stars', xAbove = 22 },
    { name = 'zone_choir_of_resin', zBelow = 9 },
    { name = 'zone_nave' },
  },
  decor = {
    atmosphere = {
      ambient = { 0.19, 0.16, 0.145 },
      figures = { 0.46, 0.45, 0.44 },
      sky = { 0.4, 0.3, 0.25 },
    },
    niches = false,
    arches = {},
    -- One main inlay, aligned with the altar. No scattered rings in the nave.
    rituals = { { x = 16, z = 12.5, rings = { 2.2, 2.3 }, orbit = 2.1, seals = 9 } },
    aisles = { { x = 13.8, z = 19.5, length = 20 }, { x = 18.2, z = 19.5, length = 20 } },
    -- Existing paintings placed as triptychs within their own wall bays.
    muralWalls = { { 2, 10, 2, 22 }, { 30, 10, 30, 22 }, { 14, 30, 18, 30 }, { 14, 2, 18, 2 } },
    murals = {
      { frame = 1, x = 1.65, y = 0.7, z = 16, yaw = math.pi / 2, size = 3.1 },
      { frame = 2, x = 30.35, y = 0.7, z = 16, yaw = -math.pi / 2, size = 3.1 },
      { frame = 3, x = 16, y = 0.8, z = 1.65, yaw = 0, size = 3.0 },
      { frame = 4, x = 16, y = 0.8, z = 30.35, yaw = math.pi, size = 3.1 },
    },
    banners = { { x = 10.25, z = 25.5, side = 1 }, { x = 21.75, z = 25.5, side = -1 } },
    candles = {
      { x = 14, z = 28 },
      { x = 18, z = 28 },
      { x = 4.1, z = 16.2 },
      { x = 27.9, z = 16.2 },
      { x = 14.5, z = 3.7 },
      { x = 17.5, z = 3.7 },
      { x = 14, z = 5.2 },
      { x = 18, z = 5.2 },
    },
    props = {
      { frame = 5, x = 10, z = 2, size = 3.3, brightness = 0.85 },
      { frame = 5, x = 22, z = 2, size = 3.3, brightness = 0.85 },
    },
  },
}
-- Four repeated bays, no free-standing obstacles in either duel centre.
for _, x in ipairs({ 12, 20 }) do
  for _, z in ipairs({ 10, 15, 20, 25, 30 }) do
    map.pillars[#map.pillars + 1] = { x, z }
  end
  for _, z in ipairs({ 12.5, 17.5, 22.5, 27.5 }) do
    map.decor.arches[#map.decor.arches + 1] =
      { x = x, z = z, yaw = math.pi / 2, halfSpan = 2.5, spring = 3.8, rise = 1.25 }
  end
end
for _, z in ipairs({ 10, 15, 20, 25, 30 }) do
  map.decor.arches[#map.decor.arches + 1] =
    { x = 16, z = z, halfSpan = 4, spring = 4.6, rise = 2.2 }
end
for _, x in ipairs({ 5.5, 26.5 }) do
  for _, z in ipairs({ 11, 21 }) do
    map.decor.arches[#map.decor.arches + 1] =
      { x = x, z = z, halfSpan = 4, spring = 4.6, rise = 1.5 }
  end
end
-- Bounded cell strips make a low-poly barrel ceiling. Its stepped underside
-- IS the collision shape; there is no decorative roof bullets fly through.
-- A common high top seals the joins. Low end bays close the outer walls.
local cells = {}
for _, r in ipairs(map.rooms) do
  for z = r[2], r[4] do
    cells[z] = cells[z] or {}
    for x = r[1], r[3] do
      cells[z][x] = true
    end
  end
end
map.decks = {}
local strips = {}
for z = 1, map.size do
  for x = 1, map.size do
    if cells[z] and cells[z][x] then
      local bottom = 4.2
      if x >= 12 and x <= 20 and z >= 9 and z <= 29 then
        local edge = math.max(0, math.abs(x - 16) - 0.5) / 4.5
        bottom = 4.9 + 2.2 * math.sqrt(1 - edge * edge)
      elseif ((x >= 2 and x <= 9) or (x >= 23 and x <= 30)) and z >= 11 and z <= 21 then
        local centre = x < 16 and 5.5 or 26.5
        local edge = math.max(0, math.abs(x - centre) - 0.5) / 4
        bottom = 4.9 + 1.5 * math.sqrt(1 - edge * edge)
      elseif x >= 14 and x <= 18 and z >= 3 and z <= 8 then
        bottom = 5.2
      end
      -- Adjacent cells of equal underside are one solid, not one draw/cast
      -- candidate per tile. Shape and silhouette are exactly the same.
      local previous = strips[x]
      if previous and previous.z2 == z - 1 and previous.thickness == 7.6 - bottom then
        previous.z2 = z
      else
        local deck = { x1 = x, x2 = x, z1 = z, z2 = z, top = 7.6, thickness = 7.6 - bottom }
        map.decks[#map.decks + 1] = deck
        strips[x] = deck
      end
    end
  end
end
local function courtFire(left, right)
  local points = {}
  for z = 10.2, 22.2, 0.9 do
    for _, x in ipairs({ left, right }) do
      if not ((x == 9.3 or x == 22.7) and z > 14.5 and z < 18.5) then
        points[#points + 1] = { x = x, z = z }
      end
    end
  end
  for x = left + 0.9, right - 0.4, 0.9 do
    points[#points + 1] = { x = x, z = 10.2 }
    points[#points + 1] = { x = x, z = 22.2 }
  end
  return points
end
map.proving = {
  exhibits = false,
  chambers = {
    {
      id = 'ash',
      fire = courtFire(1.9, 9.3),
      entry = { x = 7, z = 20, yaw = math.pi },
      slots = { { x = 7, z = 12 }, { x = 4, z = 12 }, { x = 8, z = 15 } },
    },
    {
      id = 'storm',
      fire = courtFire(22.7, 30.1),
      entry = { x = 25, z = 20, yaw = math.pi },
      slots = { { x = 25, z = 12 }, { x = 28, z = 12 }, { x = 24, z = 15 } },
    },
    {
      id = 'flesh',
      entry = { x = 10.5, z = 8, yaw = math.pi },
      slots = { { x = 9, z = 3.6 }, { x = 11, z = 3.6 }, { x = 9, z = 5 } },
    },
    {
      id = 'bindings',
      entry = { x = 22, z = 8, yaw = math.pi },
      slots = { { x = 23, z = 3.6 }, { x = 21, z = 3.6 }, { x = 23, z = 5 } },
    },
  },
  trials = {
    { id = 'ash', chamber = 'ash', creature = 'boss' },
    { id = 'storm', chamber = 'storm', creature = 'furfur' },
    { id = 'claws', chamber = 'flesh', creature = 'imp' },
    { id = 'iron', chamber = 'flesh', creature = 'armored' },
    { id = 'stars', chamber = 'bindings', creature = 'stolas' },
    { id = 'resin', chamber = 'bindings', creature = 'buer' },
  },
  pads = {
    { altar = 'asmoday', trial = 'ash', spawn = 'boss' },
    { altar = 'furfur', trial = 'storm', spawn = 'furfur' },
    { x = 10, z = 8, trial = 'claws', spawn = 'imp' },
    { x = 12.1, z = 8, trial = 'iron', spawn = 'armored' },
    { x = 20.5, z = 8, trial = 'stars', spawn = 'stolas' },
    { x = 23, z = 8, trial = 'resin', spawn = 'buer' },
    { x = 13.4, z = 28.6, weapon = 'exorcist' },
    { x = 18.6, z = 28.6, weapon = 'judge' },
    { x = 16, z = 28.9, refill = true },
  },
}
return map
