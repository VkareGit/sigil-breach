-- Medals: the deed or the chain the knight just made, named once at the centre of his view. The
-- highest stands until it fades (content/chain.lua).
local Audio = require('src.audio.audio')
local Honours = require('src.content.chain')
local Medals = {}
local function rankOf(id)
  if Honours.medals[id] then
    return Honours.medals[id].rank
  end
  for _, step in ipairs(Honours.steps) do
    if step.id == id then
      return step.rank
    end
  end
  return 0
end
-- Every medal has its own sound (content/sounds/medals.lua), heard when it takes the view.
function Medals.show(g, id)
  local view = g.view
  if view.medalTimer <= 0 or rankOf(id) >= rankOf(view.medal) then
    if view.medal ~= id or view.medalTimer <= 0 then
      Audio.play('medal_' .. id, Honours.medalVolume)
    end
    view.medal, view.medalTimer = id, Honours.medalTime
  end
end
return Medals
