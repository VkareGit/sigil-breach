-- The proving ground's pages (ui/test_field.lua): its catalogue of demons
-- and tools, its heading in play, its death page and its map. Pixels of the
-- 1280 by 720 frame; a text is { x, y, w, h, font } and steps its font down
-- through the painted sizes until it fits; a button { x, y, w, h }.
return {
  -- The painted font's sizes, largest first, and the default.
  fonts = { 94, 64, 48, 42, 36, 28, 24, 22, 20, 18, 16, 14, 13, 12, 11 },
  font = 18,
  buttonHeight = 44,
  -- The death page's buttons.
  dead = {
    retry = { 410, 524, 460, 50 },
    catalogue = { 410, 586, 224, 44 },
    leave = { 650, 586, 220, 44 },
  },
  -- The catalogue: a row per demon (first, step), its face, its name and
  -- its one and three; the tools two to a row (first, column and row steps);
  -- the stations in a row; the page's last row and the hitbox toggle.
  rows = { y = 174, step = 48 },
  face = { x = 86, side = 44 },
  select = { x = 140, w = 258 },
  one = { x = 410, w = 86 },
  three = { x = 508, w = 108 },
  tools = { x = 654, y = 174, column = 264, row = 52, w = 250 },
  stations = { x = 654, y = 511, step = 176, w = 162 },
  close = { 86, 616, 440, 48 },
  archive = { 550, 616, 250, 48 },
  leave = { 826, 616, 342, 48 },
  hitboxes = { 904, 72, 264, 40 },
  -- The heading in play.
  plate = { 20, 16, 378, 64, corner = 9 },
  heading = { 35, 27, 348, 20, font = 14 },
  state = { 35, 48, 348, 22, font = 14 },
  -- The catalogue's page.
  veil = { 0.012, 0.010, 0.014, 0.97 },
  page = { 54, 36, 1172, 650, corner = 14 },
  title = { 86, 72, 610, 42, font = 36 },
  intro = { 86, 120, 1082, 26, font = 18 },
  demons = { 86, 148, 530, 22, font = 16 },
  toolsTitle = { 654, 148, 514, 22, font = 16 },
  selected = { 86, 474, 530, 26, font = 18 },
  entry = { 86, 505, 530, 22, font = 16 },
  live = { 86, 535, 530, 22, font = 16 },
  arms = { 654, 439, 514, 22, font = 14 },
  stationNames = { 654, 476, 514, 22, font = 16 },
  -- The death page.
  ending = {
    veil = { 0.015, 0.013, 0.017, 0.95 },
    page = { 280, 106, 720, 560, corner = 14 },
    fell = { 328, 173, 624, 54, font = 36 },
    kept = { 328, 268, 624, 34, font = 22 },
    tip = { 328, 320, 624, 30, font = 18 },
    stats = { 328, 380, 624, 30, font = 20 },
  },
  -- The map.
  map = {
    veil = { 0.015, 0.013, 0.017, 0.96 },
    page = { 100, 40, 1080, 640, corner = 14 },
    title = { 132, 84, 1016, 46, font = 36 },
    arena = { 132, 163, 440, 34, font = 22 },
    tip = { 132, 208, 440, 30, font = 18 },
    -- A seal per row: its picture (place, side, ink), its name.
    seal = { x = 140, y = 278, step = 74, side = 44, alpha = 0.95 },
    sealName = { 206, 288, 344, 28, font = 20 },
    legend = { 132, 535, 440, 28, font = 16 },
    pause = { 132, 573, 440, 26, font = 16 },
    side = 420,
    origin = { 652, 121 },
    sealRing = 9,
    knight = { radius = 4, heading = 15 },
    enemy = 4,
  },
}
