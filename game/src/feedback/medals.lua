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
function Medals.show(g, id)
  local view = g.view
  if (view.medalTimer or 0) <= 0 or rankOf(id) >= rankOf(view.medal) then
    view.medal, view.medalTimer = id, K.medalTime
  end
end
-- A rung of the ladder: it rises with the chain.
function Medals.chain(g, step)
  Medals.show(g, step.id)
  A.play('multikill', 0.2 + step.count * 0.06)
end
return Medals
