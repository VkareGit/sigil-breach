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
    { 6, 6, 14, 8 }, -- western apse
    { 34, 8, 42, 12 },
    { 34, 6, 42, 8 }, -- eastern apse
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
    { 20, 32 },
    { 28, 12 },
    { 26, 4 },
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
    soundscape = require('src.content.maps.proving_soundscape'),
    atmosphere = {
      ambient = { 0.175, 0.18, 0.19 },
      figures = { 0.46, 0.45, 0.44 },
      sky = { 0.4, 0.3, 0.25 },
    },
    niches = false,
    pillarStyle = 'shaft',
    stonePaint = 'chapel_masonry',
    arches = {},
    rituals = {},
    aisles = { { x = 22.4, z = 24, length = 28 }, { x = 25.6, z = 24, length = 28 } },
    murals = {},
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
      { x = cx, z = z, halfSpan = 5, spring = 4.6, rise = 7.2 }
  end
  for _, x in ipairs({ cx - 5, cx + 5 }) do
    for _, z in ipairs({ 16.5, 23.5 }) do
      map.decor.arches[#map.decor.arches + 1] =
        { x = x, z = z, yaw = math.pi / 2, halfSpan = 3.5, spring = 4.6, rise = 7.0 }
    end
  end
  -- A high triumphal arch frames the smaller, raised altar chamber.
  map.decor.arches[#map.decor.arches + 1] =
    { x = cx, z = 9, halfSpan = 5, spring = 4.2, rise = 3.0 }
  for _, side in ipairs({ -1, 1 }) do
    map.decor.aisles[#map.decor.aisles + 1] = { x = cx + side * 1.8, z = 19, length = 19 }
    map.decor.candles[#map.decor.candles + 1] = { x = cx + side * 1.2, z = 7.5 }
    map.decor.props[#map.decor.props + 1] =
      { frame = 5, x = cx + side * 3.6, z = 10, size = 3.2, brightness = 0.48 }
    map.decor.banners[#map.decor.banners + 1] = { x = cx + side * 6.8, z = 21, side = -side }
    map.lamps[#map.lamps + 1] = { cx + side * 2.5, 10.5 }
  end
  local inward = index == 1 and 1 or -1
  map.lamps[#map.lamps + 1] = { cx + inward * 6, 25 }
end
-- Nave bays frame the sanctuary; lower passages make the tall halls a reveal.
for _, x in ipairs({ 20, 28 }) do
  for _, z in ipairs({ 10, 17, 24, 31, 38 }) do
    map.pillars[#map.pillars + 1] = { x, z }
  end
  for _, z in ipairs({ 13.5, 20.5, 27.5 }) do
    map.decor.arches[#map.decor.arches + 1] =
      { x = x, z = z, yaw = math.pi / 2, halfSpan = 3.5, spring = 4.6, rise = 7.0 }
  end
end
for _, z in ipairs({ 10, 17, 24, 31 }) do
  map.decor.arches[#map.decor.arches + 1] =
    { x = 24, z = z, halfSpan = 4, spring = 4.6, rise = 7.0 }
end
-- A low entrance opens onto the tall nave. These ribs agree with the real
-- narthex roof; they do not hang a second ceiling over the walking surface.
for _, z in ipairs({ 35, 38 }) do
  map.decor.arches[#map.decor.arches + 1] =
    { x = 24, z = z, halfSpan = 6.4, spring = 3.1, rise = 0.6, radius = 0.12 }
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
-- The fresco cycle and light accents are authored separately from routes,
-- collision, encounter slots and roof slabs.
require('src.content.maps.proving_art')(map)
require('src.content.maps.proving_roof')(map)
require('src.content.maps.proving_halls')(map)
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
