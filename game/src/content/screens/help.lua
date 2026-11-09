-- The help page (ui/screens/help.lua): the rules of the fight, the keys and
-- the bestiary. Pixels of the 1280 by 720 frame; a box is { x, y, w, h }, a
-- line { y, font }; font is a size.
return {
  veil = 0.96,
  page = { 70, 42, 1140, 640, corner = 14 },
  -- The Goetia seals in the parchment's margin: their side and the zone's
  -- padding round them, and their ink.
  margin = { side = 36, pad = 4, alpha = 0.55 },
  writing = { 158, 106, 964, 492 },
  heading = { 440, 112, 400, 50, font = 28 },
  pageCount = { 572, font = 11 },
  -- The bestiary's pages: a card holds this little text at its smallest
  -- font, or it is drawn larger, two to a page instead of four.
  detail = { font = 11, width = 208 },
  -- The rules page: its title; each rule's seal (column start and step,
  -- the seal's place in its column and side), its name and its three lines
  -- (the smaller font where a line is wider than wide); then the lines
  -- beneath (first row, step).
  rules = {
    title = { 170, font = 18 },
    x = 182,
    step = 310,
    seal = { x = 100, y = 200, side = 96 },
    zone = { y = 304, w = 296, h = 92 },
    name = { y = 304, h = 24, font = 18 },
    line = { y = 312, step = 20, font = 14, small = 12, wide = 290 },
    beneath = { y = 410, step = 30, font = 14 },
  },
  -- The buttons: back, and the pages before and after.
  back = { x = 460, y = 619, w = 360, h = 42 },
  previous = { x = 170, y = 619, w = 240, h = 42 },
  next = { x = 870, y = 619, w = 240, h = 42 },
  title = { 170, font = 18 },
  -- The keys: four to a row (first, column step, row step), the key's width,
  -- the words beside it; then the rule below them.
  keys = {
    x = 170,
    y = 200,
    column = 240,
    row = 44,
    width = 88,
    words = { x = 100, y = 8, font = 18 },
  },
  rule = { 170, 294, 940 },
  -- A card: its column (start, step when detailed and not), text width, the
  -- face's place and side, and its three captions (y, first font) detailed
  -- and not; the fonts tried for a caption, and a caption's rows.
  card = {
    x = 160,
    step = { detailed = 480, plain = 240 },
    width = { detailed = 448, plain = 208 },
    face = { y = 312, detailed = { x = 186, side = 76 }, plain = { x = 54, side = 116 } },
    name = { detailed = { 392, font = 13 }, plain = { 435, font = 18 }, row = 24 },
    desc = { detailed = { 446, font = 13 }, plain = { 467, font = 14 } },
    tip = { detailed = { 486, font = 13 }, plain = { 491, font = 14 } },
    fonts = { 18, 16, 14, 13, 12, 11 },
    smallest = 11,
    row = 18,
    height = 26,
    inset = 6,
  },
  bestiaryCount = { 299, font = 11 },
  reload = { 528, font = 18 },
  charge = { 554, font = 16 },
  ward = { 580, font = 14 },
}
