-- The fire's shop (ui/fire_shop.lua). Pixels of the 1280 by 720 frame; a
-- line is { x, y, w, font }: where a text starts, how wide it may run and
-- its size; every line is 26 high.
return {
  lineHeight = 26,
  -- The stations' tabs (first, step), the weapon cards' tabs, and an
  -- offer's buy and remove buttons (its rows: first, step).
  station = { x = 128, step = 344, y = 141, w = 328, h = 44 },
  card = { x = 128, step = 202, y = 204, w = 190, h = 42 },
  offerRows = { y = 212, step = 86 },
  buy = { x = 944, w = 208, h = 38, below = 42 },
  back = { x = 128, y = 593, w = 310, h = 48 },
  travel = { x = 824, y = 593, w = 328, h = 48 },
  veil = { 0.025, 0.018, 0.016, 0.94 },
  page = { 96, 44, 1088, 628, corner = 14 },
  merchant = { 128, 79, 490, 48 },
  wallet = { 844, 87, 308, font = 24 },
  -- The arsenal: the weapon's card, its name and whether it is owned.
  weaponCard = { 128, 258, 392, 262 },
  weaponName = { 150, 454, 348, font = 22 },
  owned = { 150, 486, 348, font = 16 },
  -- The vows and sigils: the plate, the seals two to a row (first, column
  -- and row steps, side), the flask, the capacity, and the tip's lines.
  plate = { 128, 204, 392, 316, corner = 12 },
  seals = { x = 185, y = 218, column = 152, row = 68, side = 60 },
  flask = { 260, 235, size = 128 },
  capacity = { 150, 360, 342, font = 20 },
  tip = { 150, 385, 342, font = 18, step = 24, lines = 5 },
  -- An offer: its row (first, step), name, preview and description (a
  -- sigil's two lines, step; another's one line, wider).
  offer = {
    y = 208,
    step = 86,
    name = { 550, 0, 380, font = 18 },
    preview = { 550, 25, 380, font = 14 },
    sigil = { 550, 44, 380, font = 12, step = 18, lines = 2 },
    other = { 550, 48, 600, font = 12 },
  },
  message = { 128, 553, 1024, font = 16 },
}
