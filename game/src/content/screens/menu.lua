-- The main menu's page (ui/screens/menu.lua). Pixels of the 1280 by 720
-- frame; a box is { x, y, w, h }, a place { x, y }; font is a size.
return {
  -- The curtain: strips abutting (no 1 px overlap, which drew dark lines),
  -- its darkest share and the distance over which it thins.
  curtain = { strips = 64, width = 20, alpha = 0.98, thins = 70 },
  page = { 36, 38, 500, 600, corner = 12 },
  writing = { 70, 74, 434, 532 },
  sigil = { 72, 105, 300, 104 },
  breach = { 72, 216, 240, 44 },
  rule = { 72, 274, 80 },
  trial = { 72, 292, font = 24 },
  tagline = { 72, 329, font = 18 },
  ring = { 402, 145, size = 94 },
  chapel = { 76, 78, font = 20 },
  way = { 72, 360, font = 18 },
  version = { 65, 659, font = 16 },
  fullscreen = { 1248, 673, font = 16 },
  proving = { 580, 324, 590, 284, corner = 12 },
  provingField = { 612, 358, 526, 226 },
  provingTitle = { 612, 360, 526, 35, font = 28 },
  -- The stations, one row each (first row, step).
  station = { 612, 400, 526, 25, step = 34, font = 18 },
  waits = { 612, 560, 526, 24, font = 16 },
  -- The note that a save was recovered or could not be read.
  recovery = { 566, 614, 650, 42, corner = 8 },
  recoveryField = { 582, 622, 618, 26 },
  recoveryText = { 584, 622, 612, 26, font = 16 },
}
