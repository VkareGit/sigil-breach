-- The anatomy annotation of each painted atlas, by atlas id: the module of
-- each (content/art/anatomy_regions.lua), kept in its creature's package
-- (PLAN F4: content/creatures/<id>/anatomy.lua). Authored code (Author helpers)
-- or a data file written by the anatomy tools (qa/art/anatomy_export.lua,
-- tools/art/anatomy_editor, qa/art/anatomy_layers.lua).
return {
  imp = 'src.content.creatures.imp.anatomy',
  armored = 'src.content.creatures.armored.anatomy',
  stolas = 'src.content.creatures.stolas.anatomy',
  buer = 'src.content.creatures.buer.anatomy',
  boss = 'src.content.creatures.boss.anatomy',
  furfur = 'src.content.creatures.furfur.anatomy',
}
