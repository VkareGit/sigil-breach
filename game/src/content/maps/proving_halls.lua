-- The proving ground built as painted architecture. A hall is data: walls by
-- painted surface, piers, furniture, what is solid. Decor the grid used to place
-- inside a hall leaves with it; solid furniture becomes raised cells, so
-- collision, shots and routes need nothing of their own.
local SOLID = 0.5
local PIER_TOP = 8.4
local RADIUS = 0.62
local function segment(id, kind, a, b, radius, extra)
  local def = extra or {}
  def.id, def.kind, def.from, def.to, def.radius = id, kind, a, b, radius
  return def
end
-- A pier that can fall: the roof it carried, the wall behind it when that wall
-- is outside the building, and where the rubble lies. side: towards the wall.
local function fall(hall, p, index, outer)
  local side = p.x < hall.x and -1 or 1
  local x, z = p.x, p.z
  local inward = -side
  local def = segment(
    hall.id .. '-pier-' .. index,
    'pier',
    { x, 0, z },
    { x, PIER_TOP, z },
    RADIUS,
    {
      cell = { x, z },
      hole = {
        x = x + inward * (outer and 0.6 or 2.0),
        z = z,
        radius = hall.half > 5 and 3.1 or 2.5,
        seed = index * 1.3 + x,
      },
      rubble = {
        { x, z, 0.62 },
        { x, z - 1, 0.3 },
        { x, z + 1, 0.3 },
        { x + inward, z, 0.3 },
      },
      heaps = {
        { x = x + side * 0.4, z = z, radius = 2.1, peak = 0.95, count = 90 },
        { x = x + inward * 1.6, z = z + 1.1, radius = 1.3, peak = 0.3, count = 30 },
      },
    }
  )
  -- The fallen shaft closes the aisle behind it.
  local aisle = x + side
  while math.abs(aisle - hall.x) < hall.half do
    def.rubble[#def.rubble + 1] = { aisle, z, 0.62 }
    aisle = aisle + side
  end
  if outer then
    def.tear = {
      side = side,
      z = z,
      half = 3.45,
      low = 5.4,
      high = 10.9,
      seed = index * 2.1 + x,
      columns = {},
    }
    local edge = side < 0 and 1 or 49
    for c = hall.x + side * (hall.half + 0.5), edge, side do
      def.tear.columns[#def.tear.columns + 1] = c
    end
  end
  return def
end
local function vaultHeight(hall, rise)
  return function(x)
    local t = 1 - math.abs(x - hall.x) / hall.half
    return 10.5 + rise * math.max(t, 0) ^ 0.62
  end
end
-- One of the two duelling halls. Offsets are from the hall axis, on the side
-- facing away from the door; door is the side (+1 east, -1 west) the door is on.
local function chapel(id, cx, door, art)
  local function X(dx)
    return cx + dx * door
  end
  local function cells(dx1, z1, dx2, z2, height)
    local a, b = X(dx1), X(dx2)
    return { math.min(a, b), z1, math.max(a, b), z2, height }
  end
  local function heap(dx, z, radius, peak, count, seed)
    return { x = X(dx), z = z, radius = radius, peak = peak, count = count, seed = seed }
  end
  local hall = {
    id = id,
    kit = 'chapel',
    x = cx,
    half = 7.5,
    backdrops = {},
    apse = 4.5,
    rear = 5.5,
    chancel = 11.5,
    south = 29.5,
    southTop = 10,
    rearWall = 'rear',
    chancelWall = { surface = 'chancel', from = 0.6, to = 15.6, back = true },
    southWall = { surface = 'south' },
    solidFrom = SOLID,
    footprint = cx < 24 and { { 3, 12, 17, 29 }, { 6, 6, 14, 11 } }
      or { { 31, 12, 45, 29 }, { 34, 6, 42, 11 } },
    walls = {
      {
        side = -door,
        { surface = 'strip', z = 11.5, from = 2.5, to = 4 },
        { surface = art[1], z = 13 },
        { surface = art[2], z = 20 },
        { surface = 'strip', z = 27, from = 0, to = 2.5 },
      },
      {
        side = door,
        { surface = 'strip', z = 11.5, from = 4, to = 5.5 },
        { surface = art[3], z = 13 },
        { surface = 'door_wall', z = 20, from = 0, to = 9.5 },
      },
    },
    piers = {},
    sarcophagi = {
      { x = X(-6), z1 = 15, z2 = 17 },
      { x = X(6), z1 = 15, z2 = 17 },
    },
    altar = { x1 = cx - 2, x2 = cx + 2, z = 6, top = 2.2 },
    posts = { { x = X(-3), z = 8, height = 1.5 }, { x = X(3), z = 8, height = 1.5 } },
    pedestals = { { x = cx - 2, z = 11, height = 1 }, { x = cx + 3, z = 11, height = 1 } },
    breakables = {},
    heaps = {
      heap(-3.7, 10.6, 1.5, 1.05, 90, 11),
      heap(3.7, 10.4, 1.7, 1.15, 100, 12),
      heap(3.6, 6.6, 1.6, 1.6, 100, 13),
      heap(-3.6, 6.5, 1.3, 1.1, 70, 14),
      heap(-6.6, 19.6, 1.0, 0.3, 30, 15),
      heap(6.1, 23, 1.4, 0.3, 40, 16),
      heap(-3.5, 21.9, 1.0, 0.3, 26, 17),
      heap(3.8, 18.5, 1.15, 0.3, 30, 18),
      heap(-3.2, 14.6, 0.9, 0.28, 22, 19),
      heap(-1.9, 12.2, 0.8, 0.26, 18, 20),
      heap(2.4, 11.9, 0.9, 0.28, 22, 21),
    },
    drums = {
      { x = X(3.2), z = 13.6, yaw = 0.6, radius = 0.46, length = 1.3 },
      { x = X(-3.4), z = 13.3, yaw = 2.5, radius = 0.42, length = 1.1 },
    },
    -- Raised cells: { x1, z1, x2, z2, height }.
    solids = {
      { cx - 2, 6, cx + 2, 6, 2.2 }, -- altar
      cells(-3, 8, -3, 8, 1.5),
      cells(3, 8, 3, 8, 1.5), -- posts
      { cx - 2, 11, cx - 2, 11, 1 },
      { cx + 3, 11, cx + 3, 11, 1 }, -- the fires' pedestals
      cells(-6, 15, -6, 17, 1),
      cells(6, 15, 6, 17, 1), -- sarcophagi
      cells(-4, 10, -4, 11, 0.62),
      cells(4, 9, 4, 11, 0.62),
      cells(3, 6, 4, 7, 0.9),
      cells(-4, 6, -3, 7, 0.7),
      cells(-4, 8, -4, 9, 0.62),
      cells(4, 8, 4, 8, 0.62),
    },
    -- Four real steps up to the altar: { x1, z1, x2, z2, height }.
    steps = {
      { cx - 3, 10, cx + 3, 10, 0.16 },
      { cx - 3, 9, cx + 3, 9, 0.32 },
      { cx - 2, 8, cx + 2, 8, 0.48 },
      { cx - 2, 7, cx + 2, 7, 0.64 },
    },
    candles = {},
  }
  for _, z in ipairs({ 13, 20, 27 }) do
    hall.piers[#hall.piers + 1] = { x = cx - 5, z = z }
    hall.piers[#hall.piers + 1] = { x = cx + 5, z = z }
  end
  hall.vaultHeight = vaultHeight(hall, 5.6)
  local list = hall.breakables
  for i, p in ipairs(hall.piers) do
    list[#list + 1] = fall(hall, p, i, (p.x - cx) * door < 0)
  end
  -- Banners hang on the piers that look down the hall and fall with them.
  for i, spot in ipairs({ { -5, 13, 1 }, { 5, 13, 2 }, { -5, 20, 3 }, { 5, 20, 4 } }) do
    local x = X(spot[1])
    local hung = hall.id .. '-banner-' .. i
    local carrier
    for k, p in ipairs(hall.piers) do
      if p.x == x and p.z == spot[2] then
        carrier = hall.id .. '-pier-' .. k
      end
    end
    list[#list + 1] = segment(
      hung,
      'banner',
      { x, 2.6, spot[2] + 0.72 },
      { x, 8, spot[2] + 0.72 },
      0.8,
      { supports = carrier }
    )
  end
  local function chain(id, top, low, sag, links)
    list[#list + 1] = segment(hall.id .. '-chain-' .. id, 'chain', top, low, 0.24, {
      sag = sag,
      links = links,
      length = top[2] - low[2],
    })
  end
  chain(1, { X(-4.4), 8.8, 10.9 }, { X(-3), 1.75, 8.4 }, 0.5, 21)
  chain(2, { X(4.4), 8.8, 10.9 }, { X(3), 1.75, 8.4 }, 0.5, 21)
  chain(3, { X(3.9), 8.6, 11.3 }, { X(3.9), 5.2, 11.3 }, 0.01, 9)
  local function urn(i, dx, z, scale)
    local x = X(dx)
    list[#list + 1] = segment(
      hall.id .. '-urn-' .. i,
      'urn',
      { x, 0, z },
      { x, 0.8 * scale, z },
      0.3 * scale,
      { scale = scale }
    )
  end
  for i, spot in ipairs({
    { -6.7, 14.3, 1 },
    { -6.5, 18.7, 0.8 },
    { -6.9, 21.6, 1.1 },
    { -6.6, 25.6, 0.9 },
    { -6.2, 28.5, 1 },
    { 6.8, 14.2, 0.9 },
    { 6.5, 18.4, 1.1 },
    { 6.9, 21.4, 0.8 },
    { 6.4, 24.8, 1 },
    { -3.4, 28.7, 1 },
    { -2.6, 28.9, 0.75 },
    { 3.6, 28.7, 0.9 },
  }) do
    urn(i, spot[1], spot[2], spot[3])
  end
  for i, spot in ipairs({ { -6, 15.3 }, { -6, 16.8 }, { 6, 15.4 }, { 6, 16.7 } }) do
    local x = X(spot[1])
    list[#list + 1] = segment(
      hall.id .. '-candles-' .. i,
      'candles',
      { x, 1, spot[2] },
      { x, 1.4, spot[2] },
      0.2,
      { base = 1 }
    )
  end
  return hall
end
local nave = {
  id = 'nave',
  kit = 'chapel',
  x = 24,
  half = 4.5,
  chancel = 9.5,
  south = 34.5,
  solidFrom = SOLID,
  footprint = { { 20, 10, 28, 34 } },
  chancelWall = { surface = 'nave_chancel', from = 2.75, to = 11.75 },
  southWall = { surface = 'nave_south', from = 2.75, to = 11.75 },
  walls = {
    {
      side = -1,
      { surface = 'strip', z = 9.5, from = 0, to = 0.5 },
      { surface = 'nave_a', z = 10 },
      { surface = 'nave_b', z = 17 },
      { surface = 'nave_door', z = 24 },
      { surface = 'nave_end', z = 31, from = 0, to = 3.5 },
    },
    {
      side = 1,
      { surface = 'strip', z = 9.5, from = 0.5, to = 1 },
      { surface = 'nave_c', z = 10 },
      { surface = 'nave_a', z = 17 },
      { surface = 'nave_door', z = 24 },
      { surface = 'nave_end', z = 31, from = 0, to = 3.5 },
    },
  },
  piers = {
    { x = 20, z = 10 },
    { x = 28, z = 10 },
    { x = 20, z = 17 },
    { x = 28, z = 17 },
    { x = 20, z = 24 },
    { x = 28, z = 24 },
    { x = 20, z = 31 },
    { x = 28, z = 31 },
  },
  breakables = {},
  light = {
    ambient = { 0.2, 0.17, 0.155 },
    tone = 0.55,
    sources = {
      { 0, 4, 0, 1, 0.66, 0.42, 1.0, 30 },
      { -3.2, 2.2, 7, 0.95, 0.6, 0.32, 0.5, 8 },
      { 3.2, 2.2, 7, 0.95, 0.6, 0.32, 0.5, 8 },
      { -3.2, 2.2, 14.5, 0.95, 0.6, 0.32, 0.5, 8 },
      { 3.2, 2.2, 14.5, 0.95, 0.6, 0.32, 0.5, 8 },
      { 0, 3, 22, 0.8, 0.52, 0.34, 0.4, 16 },
    },
  },
  lamps = { { 21.3, 16.5 }, { 26.7, 16.5 }, { 21.3, 24 }, { 26.7, 24 } },
  solids = {},
  steps = {},
  candles = {},
}
nave.vaultHeight = vaultHeight(nave, 4.2)
do
  local list = nave.breakables
  for i, p in ipairs(nave.piers) do
    if p.z == 17 or p.z == 24 then
      list[#list + 1] = fall(nave, p, i, false)
      list[#list + 1] = segment(
        'nave-banner-' .. i,
        'banner',
        { p.x + (p.x < 24 and 0.5 or -0.5), 2.6, p.z + 0.72 },
        { p.x + (p.x < 24 and 0.5 or -0.5), 8, p.z + 0.72 },
        0.8,
        { supports = 'nave-pier-' .. i }
      )
    end
  end
  for i, spot in ipairs({
    { 21, 11.5, 21, 15 },
    { 27, 11.5, 27, 15 },
    { 21, 18.6, 21, 22.4 },
    { 27, 18.6, 27, 22.4 },
  }) do
    list[#list + 1] = segment(
      'nave-bench-' .. i,
      'bench',
      { spot[1], 0.3, spot[2] },
      { spot[3], 0.3, spot[4] },
      0.3
    )
  end
  for i, spot in ipairs({ { 20.9, 30.2 }, { 27.1, 30.2 }, { 21.3, 23.1 }, { 26.7, 15.9 } }) do
    list[#list + 1] = segment(
      'nave-urn-' .. i,
      'urn',
      { spot[1], 0, spot[2] },
      { spot[1], 0.8, spot[2] },
      0.3,
      { scale = 1 }
    )
  end
end
local WALL = { width = 6.3, height = 4.2 }
local rooms = {
  id = 'rooms',
  kit = 'rooms',
  ambient = { 0.2, 0.17, 0.16 },
  tone = 0.55,
  footprint = {},
  rooms = {
    { rect = { 22, 2, 26, 9 }, wall = 'sanctuary', tile = WALL },
    { rect = { 18, 2, 21, 8 }, wall = 'crypt', tile = WALL },
    { rect = { 27, 2, 30, 8 }, wall = 'crypt', tile = WALL },
    { rect = { 14, 2, 17, 5 }, wall = 'crypt', tile = WALL },
    { rect = { 31, 2, 34, 5 }, wall = 'crypt', tile = WALL },
    { rect = { 18, 26, 19, 29 }, wall = 'narthex', tile = WALL },
    { rect = { 29, 26, 30, 29 }, wall = 'narthex', tile = WALL },
    { rect = { 18, 32, 19, 34 }, wall = 'narthex', tile = WALL },
    { rect = { 29, 32, 30, 34 }, wall = 'narthex', tile = WALL },
    { rect = { 18, 35, 30, 39 }, wall = 'narthex', tile = WALL },
  },
}
for i, room in ipairs(rooms.rooms) do
  rooms.footprint[i] = room.rect
end
rooms.breakables = {}
for i, spot in ipairs({
  { 18.6, 2.6, 1 },
  { 20.6, 2.6, 0.8 },
  { 18.5, 7.4, 1.1 },
  { 29.4, 2.6, 1 },
  { 27.4, 2.6, 0.8 },
  { 29.5, 7.4, 1.1 },
  { 14.6, 2.6, 0.9 },
  { 16, 4.6, 1 },
  { 33.4, 2.6, 0.9 },
  { 32, 4.6, 1 },
  { 19, 38.6, 1 },
  { 29, 38.6, 1 },
  { 18.7, 35.4, 0.8 },
  { 29.3, 35.4, 0.8 },
}) do
  rooms.breakables[i] = segment(
    'room-urn-' .. i,
    'urn',
    { spot[1], 0, spot[2] },
    { spot[1], 0.8 * spot[3], spot[2] },
    0.3 * spot[3],
    { scale = spot[3] }
  )
end
local ash = chapel('ash', 10, 1, { 'bay_a', 'bay_b', 'bay_c' })
local storm = chapel('storm', 38, -1, { 'storm_a', 'storm_b', 'storm_c' })
-- Beyond a torn wall the burning city stands on that side too.
for _, hall in ipairs({ ash, storm }) do
  hall.backdrops[1] = { hall.x - 34, -9, hall.x + 34, -9, bottom = -6, top = 40 }
end
ash.backdrops[2] = { -26, -14, -26, 58, bottom = -8, top = 34 }
storm.backdrops[2] = { 74, 58, 74, -14, bottom = -8, top = 34 }
local function within(hall, x, z)
  local cx, cz = math.floor(x + 0.5), math.floor(z + 0.5)
  for _, rect in ipairs(hall.footprint) do
    if cx >= rect[1] and cx <= rect[3] and cz >= rect[2] and cz <= rect[4] then
      return true
    end
  end
  return false
end
local function clear(list, hall)
  for i = #list, 1, -1 do
    if within(hall, list[i].x, list[i].z) and not list[i].id then
      table.remove(list, i)
    end
  end
end
-- The hall paints this wall itself; the named surface only keeps its lettering,
-- now on the bare plaster between the altar and the lunette.
local function inscribe(decor, id)
  for _, panel in ipairs(decor.murals) do
    if panel.id == id then
      panel.surfaceOnly, panel.size, panel.y = true, 1.2, -0.15
    end
  end
  for _, item in ipairs(decor.inscriptions) do
    if item.surface == id then
      item.v = 0.5
    end
  end
end
local function dress(map, hall)
  local decor = map.decor
  for _, key in ipairs({ 'arches', 'aisles', 'banners', 'candles', 'props', 'floorArt', 'murals' }) do
    clear(decor[key], hall)
  end
  inscribe(decor, hall.id .. '-witnesses')
  for i = #map.lamps, 1, -1 do
    local lamp = map.lamps[i]
    if within(hall, lamp[1], lamp[2]) then
      if lamp[2] > hall.chancel then
        table.remove(map.lamps, i)
      else
        lamp.scale = 1.5
        lamp.lightHeight = map.lampHeight * lamp.scale / 1.7
      end
    end
  end
  for _, spot in ipairs(hall.lamps or {}) do
    map.lamps[#map.lamps + 1] = {
      spot[1],
      spot[2],
      scale = 0.88,
      lightHeight = map.lampHeight * 0.88 / 1.7,
      brightness = 0.62,
      color = { 0.84, 0.61, 0.39 },
    }
  end
  for _, candle in ipairs(hall.candles) do
    decor.candles[#decor.candles + 1] = candle
  end
  for i = #map.elevations, 1, -1 do
    if within(hall, map.elevations[i].x1, map.elevations[i].z1) then
      table.remove(map.elevations, i)
    end
  end
  for _, group in ipairs({ hall.steps, hall.solids }) do
    for _, s in ipairs(group) do
      map.elevations[#map.elevations + 1] =
        { x1 = s[1], z1 = s[2], x2 = s[3], z2 = s[4], height = s[5] }
    end
  end
  -- The roof of the hall is the vault that is drawn; an apse has none.
  for i = #map.decks, 1, -1 do
    local deck = map.decks[i]
    if within(hall, deck.x1, deck.z1) then
      if hall.rearWall and deck.z1 < 12 then
        table.remove(map.decks, i)
      else
        local x, height = deck.x1, hall.vaultHeight
        deck.bottoms =
          { height(x - 0.5), height(x + 0.5), height(x + 0.5), height(x - 0.5), height(x) }
        deck.top = 17.5
        deck.thickness = deck.top - math.min(unpack(deck.bottoms))
      end
    end
  end
end
return function(map)
  local decor = map.decor
  decor.halls = { ash, storm, nave, rooms }
  decor.horizon = 'chapel_inferno'
  decor.zenith = 'chapel_zenith'
  map.solids = { wall = 17.5, pillar = PIER_TOP, radius = RADIUS }
  decor.breakables = {}
  for _, hall in ipairs(decor.halls) do
    for _, def in ipairs(hall.breakables) do
      decor.breakables[#decor.breakables + 1] = def
    end
  end
  decor.atmosphere.skyGain = 0.92
  decor.atmosphere.skySmoke = 1
  decor.atmosphere.sky = { 1, 0.92, 0.86 }
  for _, hall in ipairs({ ash, storm, nave }) do
    dress(map, hall)
  end
  -- The pale card behind the sanctuary altar gives way to the painted wall.
  for i = #decor.murals, 1, -1 do
    if decor.murals[i].art == 'chapel_judgment' then
      table.remove(decor.murals, i)
    end
  end
end
