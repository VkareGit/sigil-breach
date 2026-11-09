-- The measures of the interface's shared pieces (ui/skin.lua, ui/kit.lua)
-- and of its small screens. Pixels of the 1280 by 720 frame; a box is
-- { x, y, w, h }; a font is named by its size.
return {
  skin = {
    path = 'assets/art/ui-fresco-v12.png',
    cards = 'assets/art/weapon-cards-v45.png',
    -- The atlas is cut along its painted gutters: the third row's columns,
    -- and the rows (the last column's third row ends lower). Pixels of its
    -- 1254-pixel side.
    side = 1254,
    rowCuts = { 292, 628, 940 },
    bands = { 278, 620, 899 },
    lastBand = 926,
    -- A pixel counts as painted above this opacity.
    painted = 0.55,
    -- A frame's corners are this share of its shorter side.
    corner = 0.23,
    -- The fonts tried for an inscription, largest first.
    inscriptionSizes = { 48, 36, 28, 24, 20, 18, 16, 14 },
    -- A meter: its tally marks, the bare plaster, an empty mark, a filled
    -- one (a share of its colour) and the mark's dark foot.
    meter = {
      segments = 16,
      height = 8,
      mark = 6,
      plaster = { 0.26, 0.17, 0.11 },
      empty = { 0.57, 0.48, 0.35 },
      fill = { 0.88, 0.84, 0.80 },
      foot = { 0.70, 0.65, 0.60 },
    },
  },
  kit = {
    font = 18,
    width = 1280,
    panelCorner = 12,
    -- A key: its smallest width, its font (shrinking to smallest), padding,
    -- its height and the ink's height.
    key = {
      least = 30,
      font = 14,
      smallest = 11,
      pad = 22,
      inset = 10,
      height = 40,
      ink = 20,
      corner = 10,
    },
    bar = 5,
  },
  loading = {
    fonts = { 12, 16, 22 },
    clear = { 0.025, 0.019, 0.021 },
    panel = { 330, 268, 620, 184 },
    zone = { 354, 290, 572, 142 },
    title = { 362, 296, 556, 32, font = 22 },
    count = { 362, 341, 556, 24, font = 16 },
    meter = { 374, 382, 532 },
    back = { 362, 406, 556, 22, font = 12 },
  },
  -- Every size of the painted font the interface loads.
  fonts = { 11, 12, 13, 14, 16, 18, 20, 22, 24, 28, 36, 42, 48, 64, 94 },
  -- A button: its corner, the marker of the selected one (inset, reach, half
  -- height); a narrow button (below narrow px) and its font, a wide one's;
  -- the smallest font and the step down; the label's padding (narrow, wide),
  -- its inset (narrow, wide) and its end gap.
  button = {
    corner = 8,
    marker = { inset = 10, reach = 16, half = 4 },
    narrow = 60,
    narrowFont = 24,
    font = 18,
    smallest = 12,
    step = 2,
    padNarrow = 22,
    padWide = 40,
    padHeight = 22,
    zone = 10,
    insetNarrow = 11,
    insetWide = 24,
    tail = 12,
    top = 11,
  },
  -- The ink of a painted title, and the gap between painted numerals (a
  -- share of their height).
  titleInk = { 0.89, 0.84, 0.73 },
  numerals = { gap = 0.065 },
  -- The occult archive (ui/occult_archive.lua): its list of entries (first
  -- row, step), the way back, the veil and page, its labels { x, y, w, h,
  -- font }, the figure (a plate's box, a seal's place and side) and the
  -- figure's zone.
  archive = {
    entry = { x = 126, y = 177, step = 58, w = 340, h = 48 },
    back = { x = 445, y = 612, w = 390, h = 44 },
    veil = 0.90,
    page = { 80, 45, 1120, 630, corner = 20 },
    title = { 160, 92, 960, 36, font = 28 },
    subtitle = { 160, 138, 960, 25, font = 16 },
    name = { 518, 184, 610, 28, font = 20 },
    plate = { 668, 226, 310, 280 },
    seal = { 683, 226, 280 },
    figure = { 620, 218, 400, 294 },
    source = { 505, 522, 638, 24, font = 16 },
    detail = { 505, 551, 638, 23, font = 16 },
    hint = { 126, 578, 1026, 24, font = 16 },
  },
  -- The map's way back.
  mapBack = { x = 810, y = 610, w = 290, h = 42 },
  shotReport = {
    -- Distances closer than this read as one.
    spread = 0.1,
    zone = { 86, 562, 1082, 44 },
    first = { 86, 562, 1082, 20 },
    second = { 86, 586, 1082, 20 },
    font = 14,
  },
}
