-- A chapel hall is built from painted surfaces. Each surface has one image and
-- its layout in metres; that layout is both the template its painter received
-- (tools/art/chapel_hall) and the relief the hall is built with, so paint and
-- geometry cannot disagree. Exact prompts: assets/art/chapel-hall-provenance-v35.json
local Hall = {}
local DIR = 'assets/art/chapel-hall/'
local PAINT = { filter = 'linear', mipmaps = true, mipmapFilter = 'linear' }
local TILE =
  { filter = 'linear', mipmaps = true, mipmapFilter = 'linear', wrapX = 'repeat', wrapY = 'repeat' }
local function niche(cx)
  return {
    kind = 'niche',
    cx = cx,
    half = 1.15,
    sill = 0.35,
    spring = 3.2,
    apex = 5.25,
    depth = 0.62,
  }
end
local function panel(cx, half, sill, apex)
  return {
    kind = 'panel',
    cx = cx,
    half = half,
    sill = sill,
    spring = sill,
    apex = apex,
    depth = 0.11,
  }
end
local DADO = { kind = 'dado', top = 0.35, depth = 0.06 }
local COLONNETTE = { kind = 'colonnette', cx = 3.5, top = 5.2, radius = 0.13, sill = 0.35 }
local BAY = { niche(1.9), niche(5.1), panel(3.5, 3.3, 5.7, 10.2), COLONNETTE, DADO }
Hall.images = {
  bay_a = DIR .. 'bay-a.jpg',
  bay_b = DIR .. 'bay-b.jpg',
  bay_c = DIR .. 'bay-c.jpg',
  storm_a = DIR .. 'storm-a.jpg',
  storm_b = DIR .. 'storm-b.jpg',
  storm_c = DIR .. 'storm-c.jpg',
  nave_a = DIR .. 'nave-a.jpg',
  nave_b = DIR .. 'nave-b.jpg',
  nave_c = DIR .. 'nave-c.jpg',
  nave_door = DIR .. 'nave-door.png',
  nave_end = DIR .. 'nave-end.png',
  nave_chancel = DIR .. 'nave-chancel.png',
  nave_south = DIR .. 'nave-south.png',
  door_wall = DIR .. 'door-wall.png',
  strip = DIR .. 'strip.jpg',
  south = DIR .. 'south.jpg',
  chancel = DIR .. 'chancel.png',
  apse_side = DIR .. 'apse-side.png',
  rear = DIR .. 'rear.png',
  far_ruins = DIR .. 'far-ruins.png',
  banner_a = DIR .. 'banner-a.png',
  banner_b = DIR .. 'banner-b.png',
}
Hall.tiles = {
  floor = DIR .. 'floor.jpg',
  drum = DIR .. 'drum.jpg',
  ashlar = DIR .. 'ashlar.jpg',
  iron = DIR .. 'iron.jpg',
  clay = DIR .. 'clay.jpg',
  wood = DIR .. 'wood.jpg',
  tomb = DIR .. 'tomb.jpg',
  rubble = DIR .. 'rubble.jpg',
  sanctuary = DIR .. 'sanctuary.jpg',
  crypt = DIR .. 'crypt.jpg',
  narthex = DIR .. 'narthex.jpg',
  ceiling = DIR .. 'ceiling.jpg',
}
Hall.imageOptions, Hall.tileOptions = PAINT, TILE
Hall.surfaces = {
  bay_a = { image = 'bay_a', width = 7, height = 10.5, features = BAY },
  bay_b = { image = 'bay_b', width = 7, height = 10.5, features = BAY },
  bay_c = { image = 'bay_c', width = 7, height = 10.5, features = BAY },
  storm_a = { image = 'storm_a', width = 7, height = 10.5, features = BAY },
  storm_b = { image = 'storm_b', width = 7, height = 10.5, features = BAY },
  storm_c = { image = 'storm_c', width = 7, height = 10.5, features = BAY },
  nave_a = { image = 'nave_a', width = 7, height = 10.5, features = BAY },
  nave_b = { image = 'nave_b', width = 7, height = 10.5, features = BAY },
  nave_c = { image = 'nave_c', width = 7, height = 10.5, features = BAY },
  nave_door = {
    image = 'nave_door',
    width = 7,
    height = 10.5,
    features = {
      panel(3.5, 3.3, 5.7, 10.2),
      { kind = 'opening', cx = 3.5, half = 2, sill = 0, spring = 3.1, apex = 4.5 },
      { kind = 'dado', top = 0.35, depth = 0.06 },
    },
  },
  nave_end = {
    image = 'nave_end',
    width = 7,
    height = 10.5,
    features = {
      { kind = 'opening', cx = 2, half = 1.5, sill = 0, spring = 3, apex = 4.1 },
      { kind = 'dado', top = 0.35, depth = 0.06 },
    },
  },
  nave_chancel = {
    image = 'nave_chancel',
    width = 14.5,
    height = 14.5,
    features = {
      { kind = 'opening', cx = 7.25, half = 2.5, sill = 0, spring = 3.6, apex = 5.4 },
      { kind = 'dado', top = 0.35, depth = 0.06 },
    },
  },
  nave_south = {
    image = 'nave_south',
    width = 14.5,
    height = 14.5,
    features = { { kind = 'opening', cx = 7.25, half = 4.5, sill = 0, spring = 3, apex = 3.85 } },
  },
  door_wall = {
    image = 'door_wall',
    width = 10.5,
    height = 10.5,
    features = {
      niche(1.9),
      panel(2.75, 2.55, 5.7, 10.0),
      panel(7.5, 1.9, 5.7, 9.2),
      { kind = 'opening', cx = 7.5, half = 2, sill = 0, spring = 3.1, apex = 4.5 },
      { kind = 'dado', top = 0.35, depth = 0.06, to = 5.5 },
    },
  },
  strip = { image = 'strip', width = 7, height = 10.5, features = { DADO } },
  south = {
    image = 'south',
    width = 15,
    height = 10,
    features = { { kind = 'dado', top = 0.35, depth = 0.06 } },
  },
  chancel = {
    image = 'chancel',
    width = 16.2,
    height = 16.2,
    features = {
      { kind = 'opening', cx = 8.1, half = 4.5, sill = 0, spring = 6.8, apex = 14.2 },
      { kind = 'dado', top = 0.35, depth = 0.06 },
    },
  },
  apse_side = {
    image = 'apse_side',
    width = 7.33,
    height = 11,
    features = {
      { kind = 'dado', top = 0.35, depth = 0.05 },
      {
        kind = 'ruin',
        edge = {
          { 0, 11 },
          { 0.8, 10.2 },
          { 1.5, 10.6 },
          { 2.3, 9.1 },
          { 3.2, 9.4 },
          { 3.9, 8.1 },
          { 4.8, 8.3 },
          { 5.6, 7.1 },
          { 6.5, 7.4 },
          { 7.33, 6.2 },
        },
      },
    },
  },
  rear = { image = 'rear', width = 10.5, height = 15.75, features = {} },
}
-- The cloth of a banner inside its image, found when the image was prepared.
Hall.banner = { width = 1.6, height = 5.4 }
Hall.light = {
  ambient = { 0.17, 0.145, 0.135 },
  -- Bright sources are held back so the apse does not burn out while the far
  -- end of the hall stays readable.
  tone = 0.55,
  -- { x, y, z, r, g, b, power, reach }: x from the hall axis, z from the rear
  -- wall. The first is the tear in that wall; only its light is shadowed.
  sources = {
    { 0, 9.5, 1, 1, 0.7, 0.48, 1.5, 95 },
    { -2.5, 2.4, 5, 1, 0.62, 0.32, 0.32, 7 },
    { 2.5, 2.4, 5, 1, 0.62, 0.32, 0.32, 7 },
    { -4.3, 1.5, 10.6, 0.95, 0.6, 0.32, 0.5, 5 },
    { 4.3, 1.5, 10.6, 0.95, 0.6, 0.32, 0.5, 5 },
    { -4.3, 1.5, 17.8, 0.95, 0.6, 0.32, 0.46, 5 },
    { 0, 4, 22, 0.8, 0.52, 0.34, 0.3, 26 },
    { 6.2, 3, 22, 0.8, 0.52, 0.34, 0.3, 8 },
    { 0, 2.6, 10, 0.95, 0.6, 0.36, 0.34, 11 },
  },
}
local smooth = require('src.core.mathx').smoothstep
-- How far a point lies inside a pointed arch (negative: outside).
function Hall.inside(f, u, v)
  local half = f.half
  if v <= f.spring then
    return math.min(half - math.abs(u - f.cx), v - f.sill)
  end
  local rise, dy = f.apex - f.spring, v - f.spring
  if dy >= rise then
    return -1
  end
  local r = (half * half + rise * rise) / (2 * half)
  return half - (r - math.sqrt(math.max(0, r * r - dy * dy))) - math.abs(u - f.cx)
end
-- The height of a jagged upper edge at u.
function Hall.edgeAt(edge, u)
  for i = 1, #edge - 1 do
    local a, b = edge[i], edge[i + 1]
    if u >= a[1] and u <= b[1] then
      return a[2] + (b[2] - a[2]) * (u - a[1]) / (b[1] - a[1])
    end
  end
  return edge[#edge][2]
end
-- Depth of a surface at (u, v): negative recedes from the wall face.
function Hall.relief(surface, u, v)
  local d = 0
  for _, f in ipairs(surface.features) do
    if f.kind == 'niche' or f.kind == 'panel' then
      local s = Hall.inside(f, u, v)
      if s > 0 then
        d = d - f.depth * smooth(0, f.kind == 'niche' and 0.14 or 0.12, s)
      end
    elseif f.kind == 'colonnette' then
      if math.abs(u - f.cx) < f.radius and v < f.top and v > f.sill then
        d = d + 0.16 * math.sqrt(1 - ((u - f.cx) / f.radius) ^ 2)
      end
    elseif f.kind == 'dado' and v < f.top and (not f.to or u < f.to) then
      d = d + f.depth
    end
  end
  return d
end
return Hall
