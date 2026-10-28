-- A partition of the existing painted arena, not a new campaign level.
-- The nave keeps the range/physics tools. Side courts host one live trial.
local map = require('src.core.schema').copy(require('src.content.maps.limbo'))
map.id = 'proving'
-- Dim reflected light leaves the existing fire pools and silhouettes legible.
map.decor.atmosphere = {
  ambient = { 0.14, 0.135, 0.15 },
  figures = { 0.46, 0.45, 0.46 },
  sky = { 0.66, 0.52, 0.49 },
}
map.rooms = {
  { 9, 19, 23, 29 }, -- narthex / side aisles, divided by real columns
  { 11, 10, 21, 29 }, -- nave and uninterrupted shooting lane
  { 3, 10, 9, 21 },
  { 23, 10, 29, 21 }, -- ash / storm courts
  { 9, 15, 11, 18 },
  { 21, 15, 23, 18 }, -- transept / chapel portals
  { 14, 4, 18, 10 },
  { 14, 2, 18, 3 }, -- stepped apse / presbytery
  { 8, 2, 12, 9 },
  { 20, 2, 24, 9 }, -- flesh / bindings
  { 12, 6, 14, 8 },
  { 18, 6, 20, 8 }, -- chapel doorways
}
-- The church's hierarchy comes from space and repetition, not new textures:
-- tall central ribs, lower aisle arcades, side chapels, a raised eastern end.
-- The broken roof keeps the existing painted infernal horizon visible.
map.elevations = {
  { x1 = 14, z1 = 4, x2 = 18, z2 = 5, height = 0.16 },
  { x1 = 14, z1 = 2, x2 = 18, z2 = 3, height = 0.32 },
}
map.pillars[#map.pillars + 1] = { 10, 19 }
map.pillars[#map.pillars + 1] = { 22, 19 }
-- Keep the duel centre open. Arcade piers belong to the perimeter, not
-- the player's dodge lane or the boss's straight committed charge.
for i = #map.pillars, 1, -1 do
  local p = map.pillars[i]
  if (p[1] == 5 or p[1] == 27) and (p[2] == 14 or p[2] == 19) then
    table.remove(map.pillars, i)
  end
end
for _, x in ipairs({ 3, 9, 23, 29 }) do
  for _, z in ipairs({ 13, 19 }) do
    map.pillars[#map.pillars + 1] = { x, z }
  end
  map.decor.arches[#map.decor.arches + 1] = {
    x = x,
    z = 16,
    yaw = math.pi / 2,
    halfSpan = 3,
    spring = 3.8,
    rise = 1.65,
  }
end
-- Two high transverse ribs make each court read as a chapel. Existing
-- stone/fresco materials, actual piers under every end, no collision trick.
for _, x in ipairs({ 6, 26 }) do
  for _, z in ipairs({ 13, 19 }) do
    map.decor.arches[#map.decor.arches + 1] = {
      x = x,
      z = z,
      halfSpan = 3,
      spring = 3.8,
      rise = 1.9,
    }
  end
end
map.seals[1].x, map.seals[1].z = 4.1, 17
map.seals[2].x, map.seals[2].z = 27.9, 17
map.seals[2].id = 'furfur'
map.seals[2].name = 'creature_furfur'
map.seals[2].color = { 0.65, 0.42, 0.24 }
map.seals[3].x, map.seals[3].z = 16, 3.5
-- A larger, upright ink impression stands just above each working altar.
map.seals[1].summoning, map.seals[2].summoning = true, true
map.lamps = {
  { 10, 27 },
  { 22, 27 },
  { 10, 22 },
  { 22, 22 },
  { 9, 18 },
  { 23, 18 },
  { 4, 16 },
  { 28, 16 },
  { 8.5, 8.8 },
  { 24, 8.8 },
  { 14, 4 },
  { 18, 4 },
}
for _, x in ipairs({ 12, 20 }) do
  for _, z in ipairs({ 12.5, 17.5, 22.5 }) do
    map.decor.arches[#map.decor.arches + 1] =
      { x = x, z = z, yaw = math.pi / 2, halfSpan = 2.5, spring = 3.8, rise = 1.15 }
  end
end
for _, x in ipairs({ 10.2, 21.8 }) do
  for _, z in ipairs({ 25 }) do
    map.decor.arches[#map.decor.arches + 1] =
      { x = x, z = z, halfSpan = 1.8, spring = 3.8, rise = 0.8 }
  end
end
for _, x in ipairs({ 10, 22 }) do
  map.decor.arches[#map.decor.arches + 1] =
    { x = x, z = 16.5, yaw = math.pi / 2, halfSpan = 2.5, spring = 3.8, rise = 1.2 }
end
map.decor.arches[#map.decor.arches + 1] =
  { x = 16, z = 5.5, halfSpan = 2.5, spring = 3.8, rise = 1.6 }
map.decor.aisles = {
  { x = 13.8, z = 18, length = 20 },
  { x = 18.2, z = 18, length = 20 },
}
map.decor.candles = {
  { x = 14, z = 28 },
  { x = 18, z = 28 },
  { x = 4.3, z = 16 },
  { x = 27.7, z = 16 },
  { x = 14.5, z = 3.7 },
  { x = 17.5, z = 3.7 },
  { x = 14, z = 5.2 },
  { x = 18, z = 5.2 },
}
map.decor.props[1].x, map.decor.props[1].z = 10, 2
map.decor.props[2].x, map.decor.props[2].z = 22, 2
-- Perimeter stays against the walls, leaving the entire duel floor and the
-- transept exits open. These flames are scenery, never invisible damage.
local function courtFire(x1, x2)
  local points = {}
  for z = 10.1, 21.1, 0.8 do
    points[#points + 1] = { x = x1, z = z }
    -- A broad gap for the real exit and the altar on each side.
    if z < 15 or z > 18 then
      points[#points + 1] = { x = x2, z = z }
    end
  end
  for x = math.min(x1, x2) + 0.8, math.max(x1, x2) - 0.4, 0.8 do
    points[#points + 1] = { x = x, z = 10.1 }
    points[#points + 1] = { x = x, z = 21.1 }
  end
  return points
end
map.proving = {
  exhibits = false, -- Atlas boards remain available on the library/gallery map.
  chambers = {
    {
      id = 'ash',
      fire = courtFire(2.9, 9.1),
      entry = { x = 7, z = 20, yaw = math.pi },
      slots = { { x = 7, z = 12 }, { x = 4, z = 12 }, { x = 8, z = 15 } },
    },
    {
      id = 'storm',
      fire = courtFire(29.1, 22.9),
      entry = { x = 25, z = 20, yaw = math.pi },
      slots = { { x = 25, z = 12 }, { x = 28, z = 12 }, { x = 24, z = 15 } },
    },
    {
      id = 'flesh',
      entry = { x = 10.5, z = 8.5, yaw = math.pi },
      slots = { { x = 9, z = 3.6 }, { x = 11, z = 3.6 }, { x = 9, z = 5.8 } },
    },
    {
      id = 'bindings',
      entry = { x = 22, z = 8.5, yaw = math.pi },
      slots = { { x = 23, z = 3.6 }, { x = 21, z = 3.6 }, { x = 23, z = 5.5 } },
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
  -- The existing painted medallions; their action and position are data.
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
