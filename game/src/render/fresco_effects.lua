-- Asset registration only: all attack times, radii and damage live in simulation.
-- The generic thorn rings are original attack ornaments, not historical seals.
local Atlas = require('src.render.atlas')
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
function F.load(renderer)
  local e, s = F.effects, F.spells
  renderer.effects, renderer.effectFeet, renderer.effectFrames =
    Atlas.load(e.path, e.columns, e.rows, e.bands, e.columnBands, renderer.resources)
  renderer.spells, renderer.spellFeet, renderer.spellFrames =
    Atlas.load(s.path, s.columns, s.rows, s.bands, s.columnBands, renderer.resources)
end
return F
