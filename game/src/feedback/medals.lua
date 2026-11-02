-- Medals: the deed or the chain the knight just made, named once at the centre of his view. The
-- highest stands until it fades (content/chain.lua).
local A = require('src.audio.audio')
local K = require('src.content.chain')
local Medals = {}
local function rankOf(id)
  if K.medals[id] then
    return K.medals[id].rank
  end
  for _, step in ipairs(K.steps) do
    if step.id == id then
      return step.rank
    end
  end
  return 0
end
-- Every medal has its own sound (audio/medal_voices.lua), heard when it takes the view.
function Medals.show(g, id)
  local view = g.view
  if (view.medalTimer or 0) <= 0 or rankOf(id) >= rankOf(view.medal) then
    if view.medal ~= id or (view.medalTimer or 0) <= 0 then
      A.play('medal_' .. id, K.medalVolume)
    end
    view.medal, view.medalTimer = id, K.medalTime
  end
end
return Medals
