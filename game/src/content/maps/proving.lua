-- Processional basilica and two apsidal duelling halls. Map coordinates are
-- metres/cell centres; the vault bands below produce the actual solid roof.
local map = {
  id = 'proving',
  width = 49,
  depth = 43,
  floor = 0,
  anchors = { secret = { x = 16, z = 3 }, boss = { x = 24, z = 7 } },
  rooms = {
    { 20, 10, 28, 39 },
    { 18, 32, 30, 39 }, -- nave / narthex
    { 22, 2, 26, 10 }, -- sanctuary
    { 3, 12, 17, 29 },
    { 31, 12, 45, 29 }, -- clear duelling floors
    { 6, 8, 14, 12 },
    { 8, 6, 12, 8 }, -- western apse
    { 34, 8, 42, 12 },
    { 36, 6, 40, 8 }, -- eastern apse
    { 17, 26, 20, 29 },
    { 28, 26, 31, 29 }, -- low thresholds
    { 18, 2, 21, 8 },
    { 27, 2, 30, 8 }, -- lesser creature crypts
    { 21, 6, 22, 8 },
    { 26, 6, 27, 8 },
    { 14, 2, 18, 5 },
    { 30, 2, 34, 5 }, -- approved burial galleries
  },
  pillars = {},
  elevations = {
    { x1 = 22, z1 = 4, x2 = 26, z2 = 5, height = 0.16 },
    { x1 = 22, z1 = 2, x2 = 26, z2 = 3, height = 0.32 },
    { x1 = 6, z1 = 8, x2 = 14, z2 = 9, height = 0.16 },
    { x1 = 8, z1 = 6, x2 = 12, z2 = 7, height = 0.32 },
    { x1 = 34, z1 = 8, x2 = 42, z2 = 9, height = 0.16 },
    { x1 = 36, z1 = 6, x2 = 40, z2 = 7, height = 0.32 },
  },
  seals = {
    {
      x = 10,
      z = 7,
      id = 'asmoday',
      name = 'seal_asmoday',
      court = 'court_embers',
      color = { 0.8, 0.35, 0.12 },
      summoning = true,
    },
    {
      x = 38,
      z = 7,
      id = 'furfur',
      name = 'creature_furfur',
      court = 'court_stars',
      color = { 0.65, 0.42, 0.24 },
      summoning = true,
    },
    {
      x = 24,
      z = 3.5,
      id = 'buer',
      name = 'seal_buer',
      court = 'court_resin',
      color = { 0.38, 0.55, 0.35 },
    },
  },
  portal = { x = 24, z = 2.9 },
  spawn = { x = 24, z = 36, yaw = math.pi },
  lamps = {
    { 20, 38 },
    { 28, 38 },
    { 20, 32 },
    { 28, 32 },
    { 20, 22 },
    { 28, 22 },
    { 20, 12 },
    { 28, 12 },
    { 22, 4 },
    { 26, 4 },
    { 20.8, 6 },
    { 27.2, 6 },
    { 16, 4.7 },
    { 32, 4.7 },
  },
  lampHeight = 1.18,
  emberClear = 2,
  ember = { x = 27, z = 35 },
  gates = {},
  zones = {
    { name = 'zone_court_of_embers', xBelow = 18 },
    { name = 'zone_court_of_stars', xAbove = 30 },
    { name = 'zone_choir_of_resin', zBelow = 10 },
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
    rituals = { { x = 24, z = 14, rings = { 2.2, 2.3 }, orbit = 2.1, seals = 9 } },
    aisles = { { x = 22.4, z = 24, length = 28 }, { x = 25.6, z = 24, length = 28 } },
    murals = {
      { frame = 3, x = 24, y = 0.8, z = 1.65, yaw = 0, size = 3 },
      { frame = 4, x = 24, y = 0.8, z = 39.35, yaw = math.pi, size = 4 },
    },
    banners = { { x = 19.3, z = 34, side = 1 }, { x = 28.7, z = 34, side = -1 } },
    candles = {
      { x = 22, z = 37 },
      { x = 26, z = 37 },
      { x = 22.5, z = 3.7 },
      { x = 25.5, z = 3.7 },
    },
    props = {},
  },
}
-- A hall has a centre, two side colonnades, an apse and a quiet entry at its
-- rear. The repeated bays establish scale; nothing stands on the attack axis.
for index, cx in ipairs({ 10, 38 }) do
  for _, z in ipairs({ 13, 20, 27 }) do
    for _, x in ipairs({ cx - 5, cx + 5 }) do
      map.pillars[#map.pillars + 1] = { x, z }
    end
    map.decor.arches[#map.decor.arches + 1] =
      { x = cx, z = z, halfSpan = 5, spring = 4.6, rise = 4.4 }
  end
  for _, x in ipairs({ cx - 5, cx + 5 }) do
    for _, z in ipairs({ 16.5, 23.5 }) do
      map.decor.arches[#map.decor.arches + 1] =
        { x = x, z = z, yaw = math.pi / 2, halfSpan = 3.5, spring = 3.8, rise = 1.5 }
    end
  end
  -- A high triumphal arch frames the smaller, raised altar chamber.
  map.decor.arches[#map.decor.arches + 1] =
    { x = cx, z = 9, halfSpan = 5, spring = 4.2, rise = 3.0 }
  map.decor.murals[#map.decor.murals + 1] =
    { frame = index, x = cx, y = 0.65, z = 5.65, yaw = 0, size = 3.5 }
  map.decor.murals[#map.decor.murals + 1] =
    { frame = index, x = cx - 7.35, y = 0.5, z = 17, yaw = math.pi / 2, size = 4.1 }
  map.decor.murals[#map.decor.murals + 1] =
    { frame = index + 2, x = cx + 7.35, y = 0.5, z = 24, yaw = -math.pi / 2, size = 4.1 }
  map.decor.rituals[#map.decor.rituals + 1] =
    { x = cx, z = 21, rings = { 2.6, 2.7 }, orbit = 2.4, seals = 9 }
  for _, side in ipairs({ -1, 1 }) do
    map.decor.aisles[#map.decor.aisles + 1] = { x = cx + side * 1.8, z = 19, length = 19 }
    map.decor.candles[#map.decor.candles + 1] = { x = cx + side * 1.2, z = 7.5 }
    map.decor.props[#map.decor.props + 1] =
      { frame = 5, x = cx + side * 3.6, z = 10, size = 3.2, brightness = 0.75 }
    map.decor.banners[#map.decor.banners + 1] = { x = cx + side * 6.8, z = 21, side = -side }
    for _, z in ipairs({ 14.8, 25 }) do
      map.lamps[#map.lamps + 1] = { cx + side * 6, z }
    end
    map.lamps[#map.lamps + 1] = { cx + side * 3.2, 9.6 }
  end
end
-- Nave bays frame the sanctuary; lower passages make the tall halls a reveal.
for _, x in ipairs({ 20, 28 }) do
  for _, z in ipairs({ 10, 17, 24, 31, 38 }) do
    map.pillars[#map.pillars + 1] = { x, z }
  end
  for _, z in ipairs({ 13.5, 20.5, 27.5, 34.5 }) do
    map.decor.arches[#map.decor.arches + 1] =
      { x = x, z = z, yaw = math.pi / 2, halfSpan = 3.5, spring = 3.8, rise = 1.5 }
  end
end
for _, z in ipairs({ 10, 17, 24, 31, 38 }) do
  map.decor.arches[#map.decor.arches + 1] =
    { x = 24, z = z, halfSpan = 4, spring = 4.6, rise = 3.5 }
end
for _, bay in ipairs({
  { 13.58, 3.5, math.pi / 2 },
  { 34.42, 3.5, -math.pi / 2 },
  { 18, 1.58, 0 },
  { 30, 1.58, 0 },
}) do
  map.decor.murals[#map.decor.murals + 1] =
    { art = 'catacomb_loculi', x = bay[1], z = bay[2], yaw = bay[3], y = 0.18, size = 2.65 }
end
-- Roof authoring, in priority order. A band covers floor cells; centre and
-- halfWidth describe the cross-section, spring/rise its physical underside.
-- Without a band the low roof is 4.2 m. Editing a room does not require a
-- renderer branch: update these authored bands along with its floor bounds.
local bands = {
  { x1 = 17, x2 = 19, z1 = 26, z2 = 29, spring = 3.1 },
  { x1 = 29, x2 = 31, z1 = 26, z2 = 29, spring = 3.1 },
  { x1 = 14, x2 = 18, z1 = 2, z2 = 5, spring = 3.0 },
  { x1 = 30, x2 = 34, z1 = 2, z2 = 5, spring = 3.0 },
  { x1 = 21, x2 = 27, z1 = 10, z2 = 38, spring = 4.9, rise = 3.7, centre = 24, halfWidth = 4 },
  { x1 = 4, x2 = 16, z1 = 12, z2 = 28, spring = 4.8, rise = 4.5, centre = 10, halfWidth = 6.5 },
  { x1 = 32, x2 = 44, z1 = 12, z2 = 28, spring = 4.8, rise = 4.5, centre = 38, halfWidth = 6.5 },
  { x1 = 6, x2 = 14, z1 = 6, z2 = 11, spring = 7.4 },
  { x1 = 34, x2 = 42, z1 = 6, z2 = 11, spring = 7.4 },
  { x1 = 22, x2 = 26, z1 = 2, z2 = 9, spring = 5.4 },
}
local cells, strips = {}, {}
for _, room in ipairs(map.rooms) do
  for z = room[2], room[4] do
    cells[z] = cells[z] or {}
    for x = room[1], room[3] do
      cells[z][x] = true
    end
  end
end
map.decks = {}
for z = 1, map.depth do
  for x = 1, map.width do
    if cells[z] and cells[z][x] then
      local bottom = 4.2
      for _, band in ipairs(bands) do
        if x >= band.x1 and x <= band.x2 and z >= band.z1 and z <= band.z2 then
          local edge = band.rise and math.max(0, math.abs(x - band.centre) - 0.5) / band.halfWidth
            or 0
          bottom = band.spring + (band.rise or 0) * math.sqrt(math.max(0, 1 - edge * edge))
          break
        end
      end
      -- A perimeter cornice closes the vault against the existing 4.2 m
      -- stone walls. It is a real slab, so high shots cannot leave a gap
      -- that merely looks closed. Central bays keep their full height.
      if
        not (cells[z - 1] and cells[z - 1][x])
        or not (cells[z + 1] and cells[z + 1][x])
        or not cells[z][x - 1]
        or not cells[z][x + 1]
      then
        bottom = math.min(bottom, 4.2)
      end
      local previous = strips[x]
      if previous and previous.z2 == z - 1 and previous.thickness == 10.4 - bottom then
        previous.z2 = z
      else
        local deck = { x1 = x, x2 = x, z1 = z, z2 = z, top = 10.4, thickness = 10.4 - bottom }
        map.decks[#map.decks + 1], strips[x] = deck, deck
      end
    end
  end
end
local function courtFire(cx, doorSide)
  local points = {}
  for z = 12.2, 29.2, 0.9 do
    for _, side in ipairs({ -1, 1 }) do
      if not (side == doorSide and z > 25.5) then
        points[#points + 1] = { x = cx + side * 7.2, z = z }
      end
    end
  end
  for x = cx - 6.3, cx + 6.3, 0.9 do
    points[#points + 1] = { x = x, z = 29.2 }
  end
  -- Keep the axis into the raised apse open: the arena belongs to a church.
  for _, side in ipairs({ -1, 1 }) do
    points[#points + 1] = { x = cx + side * 6, z = 12.2 }
  end
  return points
end
map.proving = {
  exhibits = false,
  stations = {
    start = { x = 24, z = 36 },
    physics = {
      stand = { x = 24, z = 33 },
      domino = { x = 24, z = 29.5, step = 0.8, count = 3 },
      slam = { x = 29.9, z = 36 },
      tripLabel = 2.1,
    },
  },
  chambers = {
    {
      id = 'ash',
      fire = courtFire(10, 1),
      entry = { x = 10, z = 25, yaw = math.pi },
      slots = { { x = 10, z = 15 }, { x = 7, z = 15 }, { x = 13, z = 17 } },
    },
    {
      id = 'storm',
      fire = courtFire(38, -1),
      entry = { x = 38, z = 25, yaw = math.pi },
      slots = { { x = 38, z = 15 }, { x = 35, z = 15 }, { x = 41, z = 17 } },
    },
    {
      id = 'flesh',
      entry = { x = 20, z = 8, yaw = math.pi },
      slots = { { x = 19, z = 3.5 }, { x = 20.5, z = 3.5 }, { x = 18.8, z = 5 } },
    },
    {
      id = 'bindings',
      entry = { x = 28, z = 8, yaw = math.pi },
      slots = { { x = 29, z = 3.5 }, { x = 27.5, z = 3.5 }, { x = 29.2, z = 5 } },
    },
  },
  trials = {
    { id = 'ash', chamber = 'ash', creature = 'boss' },
    { id = 'storm', chamber = 'storm', creature = 'furfur' },
    -- Warning + the shared 0.6 s arrival grace already give preparation.
    -- Ordinary live trials need no additional 1.2 s as harmless dummies.
    { id = 'claws', chamber = 'flesh', creature = 'imp', readyDelay = 0.2 },
    { id = 'iron', chamber = 'flesh', creature = 'armored', readyDelay = 0.2 },
    { id = 'stars', chamber = 'bindings', creature = 'stolas', readyDelay = 0.2 },
    { id = 'resin', chamber = 'bindings', creature = 'buer', readyDelay = 0.2 },
  },
  pads = {
    { altar = 'asmoday', trial = 'ash', spawn = 'boss' },
    { altar = 'furfur', trial = 'storm', spawn = 'furfur' },
    { x = 19, z = 7.5, trial = 'claws', spawn = 'imp' },
    { x = 21, z = 7.5, trial = 'iron', spawn = 'armored' },
    { x = 27, z = 7.5, trial = 'stars', spawn = 'stolas' },
    { x = 29.5, z = 7.5, trial = 'resin', spawn = 'buer' },
    { x = 21.4, z = 37.5, weapon = 'exorcist' },
    { x = 26.6, z = 37.5, weapon = 'judge' },
    { x = 24, z = 38, refill = true },
  },
}
return map
