-- The order of the systems of one simulation step: THE place that decides
-- it (docs/TECHNIKA.md, Architektura). Move before sweeping attacks, fire before the
-- demons act, measure, stop immediately after the knight's death, then
-- the world around the fight and the mode's progression. Bodies (0.25):
-- whoever moved into another body stops at the contact (the knight after
-- his move, the demons after theirs).
local Clocks = require('src.systems.clocks')
local Knight = require('src.systems.knight')
local Combat = require('src.systems.combat')
local World = require('src.systems.world')
return {
  Clocks,
  Knight.recovery,
  Knight.reload,
  Knight.snapshot,
  Knight.motion,
  Knight.contact,
  World.effects,
  World.transientsBefore,
  Knight.trigger,
  Knight.casting,
  Combat.demons,
  Combat.separation,
  Combat.bodies,
  World.scenery,
  Combat.hazards,
  Combat.projectiles,
  Combat.charges,
  Combat.effects,
  World.telemetry,
  World.remains,
  World.stillPlaying,
  World.transientsAfter,
  World.supplies,
  World.progression,
}
