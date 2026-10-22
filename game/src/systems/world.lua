-- The world around the fight: effects and transient bodies (particles,
-- shells, corpses), measurements, supplies and the progression of the mode.
local Presentation = require('src.session.presentation')
local Interactions = require('src.session.interactions')
local Telemetry = require('src.combat.telemetry')
local Modes = require('src.run.modes')
local World = {}
-- Presentation updates keep their place inside the step (their timing is
-- part of how effects look); without a presentation they do nothing.
World.effects = Presentation.stage('effects')
World.transientsBefore = Presentation.stage('transientsBefore')
World.telemetry = {
  name = 'telemetry',
  run = function(g, dt)
    Telemetry.tick(g, dt)
  end,
}
-- The knight died (or a mode ended the fight): nothing else this step.
World.stillPlaying = {
  name = 'stillPlaying',
  run = function(g)
    return g.state == 'playing'
  end,
}
World.transientsAfter = Presentation.stage('transientsAfter')
World.supplies = {
  name = 'supplies',
  run = function(g)
    Interactions.collectSupplies(g)
  end,
}
World.progression = {
  name = 'progression',
  run = function(g, dt)
    Modes.of(g).progress(g, dt)
  end,
}
return World
