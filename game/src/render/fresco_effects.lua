-- Asset registration only: all attack times, radii and damage live in simulation.
local Atlas = require('src.render.atlas')
local FrescoSheets = require('src.content.art.fresco_sheets')
local F = {}
F.effects = FrescoSheets.effects
F.spells = FrescoSheets.spells
function F.load(renderer)
  local e, s = F.effects, F.spells
  renderer.effects, renderer.effectFeet, renderer.effectFrames =
    Atlas.load(e.path, e.columns, e.rows, e.bands, e.columnBands, renderer.resources)
  renderer.spells, renderer.spellFeet, renderer.spellFrames =
    Atlas.load(s.path, s.columns, s.rows, s.bands, s.columnBands, renderer.resources)
end
return F
