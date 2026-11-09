-- The painted effect and spell sheets (render/fresco_effects.lua): each a
-- grid of frames, cut along its painted gutters (bands: the pixel rows
-- between frames, per row; columnBands: a column cut on its own), with what
-- each row means. The generic thorn rings are original attack ornaments, not
-- historical seals.
local F = {}
F.effects = {
  path = 'assets/art/effects-fresco-v12.png',
  columns = 4,
  rows = 4,
  bands = {
    { 0, 313, 627, 940, 1254 },
    { 0, 313, 627, 910, 1254 },
    { 0, 313, 627, 940, 1254 },
    {
      0,
      313,
      627,
      940,
      1254,
    },
  },
  meanings = { 'stone', 'blood', 'smoke', 'arc' },
}
F.spells = {
  path = 'assets/art/spells-fresco-v12.png',
  columns = 4,
  rows = 4,
  bands = {
    { 0, 360, 604, 929, 1254 },
    { 0, 360, 600, 925, 1254 },
    { 0, 360, 598, 930, 1254 },
    {
      0,
      380,
      598,
      930,
      1254,
    },
  },
  columnBands = { [2] = { 0, 313, 625, 920, 1254 } },
  meanings = { 'charge', 'projectile', 'warning', 'lightning' },
}
return F
