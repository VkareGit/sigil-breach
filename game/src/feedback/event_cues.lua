-- Deeds the simulation announces, heard (PLAN G5): content/event_cues.lua names
-- the sound of each event; the simulation never chooses one.
local Audio = require('src.audio.audio')
local Cues = require('src.content.event_cues')
local M = {}
function M.attach(g)
  local bus = g.bus
  if not bus then
    return
  end
  local names = {}
  for name in pairs(Cues) do
    names[#names + 1] = name
  end
  table.sort(names)
  for _, name in ipairs(names) do
    local cue = Cues[name]
    bus:on('present', name, function(e)
      if not cue.presented or e.presented then
        Audio.play(cue.sound, cue.volume)
      end
    end)
  end
end
return M
