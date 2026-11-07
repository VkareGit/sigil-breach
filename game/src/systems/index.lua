-- The order of the systems of one simulation step: THE place that decides
-- it (docs/TECHNIKA.md, Architektura). Move before sweeping attacks, fire before the
-- demons act, measure, stop immediately after the knight's death, then
-- the world around the fight and the mode's progression. Bodies (0.25):
-- whoever moved into another body stops at the contact (the knight after
-- his move, the demons after theirs).
local Clocks = require('src.systems.clocks')
local Knight = require('src.systems.knight')
local SystemsCombat = require('src.systems.combat')
local SystemsWorld = require('src.systems.world')
return {
  Clocks,
  Knight.recovery,
  Knight.reload,
  Knight.snapshot,
  Knight.motion,
  Knight.contact,
  SystemsWorld.effects,
  SystemsWorld.transientsBefore,
  Knight.trigger,
  Knight.casting,
  SystemsCombat.demons,
  SystemsCombat.separation,
  SystemsCombat.bodies,
  SystemsWorld.scenery,
  SystemsCombat.hazards,
  SystemsCombat.projectiles,
  SystemsCombat.charges,
  SystemsCombat.effects,
  SystemsWorld.telemetry,
  SystemsWorld.remains,
  SystemsWorld.stillPlaying,
  SystemsWorld.transientsAfter,
  SystemsWorld.supplies,
  SystemsWorld.progression,
}
