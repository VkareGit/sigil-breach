-- Runtime and QA decode the same voice once, before any playback pool uses it.
local Synth = require('src.audio.synth')
local VoiceData = {}
function VoiceData.render(name, recipe, rate)
  if recipe.path then
    local data = love.sound.newSoundData(recipe.path)
    assert(
      data:getChannelCount() == 1 and data:getSampleRate() == rate,
      name .. ': recorded cues must be mono at the runtime rate'
    )
    return data
  end
  return Synth.effect(recipe.duration, rate, Synth.seed(name), recipe.voice or recipe.make(rate))
end
return VoiceData
