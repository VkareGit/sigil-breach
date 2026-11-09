local Context = require('src.session.context')
-- The presentation plugged into the simulation (0.24 F1): loading this
-- module registers every presentation hook and the per-session event
-- listeners (session/presentation.lua). The application loads it once; a
-- headless simulation simply does not, and runs the same.
local Presentation = require('src.session.presentation')
local Audio = require('src.audio.audio')
local FX = require('src.feedback.effects')
local FeedbackListeners = require('src.feedback.listeners')
require('src.feedback.transients')
require('src.feedback.death_response')
require('src.feedback.motion')
local Install = {}
-- A sound cue from the simulation, at a place when it names one.
function Install.cue(g, sound, volume, x, z)
  if x then
    return Audio.playAt(sound, x, z, Context.viewer(g), volume, nil, g.world)
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
Presentation.hook('worldRestored', function(g)
  Audio.clearWorld()
  require('src.audio.world_cues').restored(Audio, g)
  require('src.feedback.world_feedback').restored(g)
end)
Presentation.hook('effects', FX.update)
Presentation.attacher(FeedbackListeners.attach)
Presentation.attacher(require('src.feedback.event_cues').attach)
return Install
