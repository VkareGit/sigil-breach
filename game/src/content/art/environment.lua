-- Named wall paintings. Map placement is separate from the image source;
-- a new panel does not add a renderer branch or replace a creature atlas.
local chapel = 'assets/art/chapel-fresco-v34.png'
local function panel(rect, tileAspect)
  return {
    path = chapel,
    rect = rect,
    filter = 'linear',
    mipmaps = true,
    mipmapFilter = 'linear',
    tileAspect = tileAspect,
  }
end
local function relic(x, y, width, height)
  return {
    path = 'assets/art/chapel-ossuary-v34.png',
    rect = { x / 1354, y / 1162, width / 1354, height / 1162 },
    aspect = width / height,
    filter = 'linear',
    mipmaps = true,
    mipmapFilter = 'linear',
  }
end
local function remains(x, y, width, height)
  return {
    path = 'assets/art/chapel-ritual-remains-v34.png',
    rect = { x / 1254, y / 1254, width / 1254, height / 1254 },
    aspect = width / height,
    filter = 'linear',
    mipmaps = true,
    mipmapFilter = 'linear',
  }
end
return {
  cold_brazier = remains(62, 153, 514, 417),
  broken_binding = remains(650, 125, 585, 450),
  spent_censer = remains(34, 786, 583, 344),
  binding_scorch = remains(627, 627, 627, 627),
  chapel_inferno = {
    path = 'assets/art/chapel-hall/inferno-sky.jpg',
    rect = { 0, 0, 1, 1 },
    filter = 'linear',
    wrapX = 'repeat',
  },
  chapel_zenith = {
    path = 'assets/art/chapel-hall/zenith.jpg',
    rect = { 0, 0, 1, 1 },
    filter = 'linear',
    wrapX = 'repeat',
    wrapY = 'repeat',
  },
  chapel_masonry = {
    path = 'assets/art/chapel-masonry-v34.png',
    rect = { 0, 0, 1, 1 },
    filter = 'linear',
    mipmaps = true,
    mipmapFilter = 'linear',
  },
  ossuary_niche = relic(35, 17, 627, 615),
  fallen_masonry = relic(690, 241, 639, 405),
  funerary_shelf = relic(39, 708, 627, 427),
  broken_capital = relic(708, 730, 621, 403),
  chapel_judgment = panel({ 0.002, 0.002, 0.496, 0.496 }),
  chapel_judgment_crown = panel({ 0.002, 0.002, 0.496, 0.238 }),
  chapel_witnesses = panel({ 0.002, 0.245, 0.496, 0.250 }),
  chapel_procession = panel({ 0.502, 0.002, 0.496, 0.496 }),
  chapel_mourners = panel({ 0.002, 0.502, 0.496, 0.496 }),
  chapel_plaster = panel({ 0.51, 0.508, 0.48, 0.35 }),
  chapel_frieze = panel({ 0.506, 0.894, 0.488, 0.098 }, 0.488 / 0.098),
  chapel_door_barred = {
    path = 'assets/art/chapel-door-barred-v38.png',
    rect = { 0, 0, 1, 1 },
    filter = 'linear',
    mipmaps = true,
    mipmapFilter = 'linear',
  },
  chapel_door_open = {
    path = 'assets/art/chapel-door-open-v38.png',
    rect = { 0, 0, 1, 1 },
    filter = 'linear',
    mipmaps = true,
    mipmapFilter = 'linear',
  },
  catacomb_loculi = {
    path = 'assets/art/catacomb-loculi-fresco.png',
    rect = { 0, 0, 1, 1 },
    filter = 'linear',
    mipmaps = true,
    mipmapFilter = 'linear',
  },
}
