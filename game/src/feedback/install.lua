-- The presentation plugged into the simulation (0.24 F1): loading this
-- module registers every presentation hook and the per-session event
-- listeners (session/presentation.lua). The application loads it once; a
-- headless simulation simply does not, and runs the same.
local Presentation = require('src.session.presentation')
local Audio = require('src.audio.audio')
local Effects = require('src.feedback.effects')
local Listeners = require('src.feedback.listeners')
require('src.feedback.transients')
require('src.feedback.death_response')
require('src.feedback.motion')
local Install = {}
-- A sound cue from the simulation, at a place when it names one.
function Install.cue(g, sound, volume, x, z)
  if x then
    return Audio.playAt(sound, x, z, g.player, volume)
  end
  return Audio.play(sound, volume)
end
Presentation.hook('cue', Install.cue)
Presentation.hook('capture', function(_, captured)
  love.mouse.setRelativeMode(captured)
end)
Presentation.hook('audio', function(g, dt)
  Audio.update(dt, g)
end)
Presentation.hook('effects', Effects.update)
Presentation.attacher(Listeners.attach)
return Install
