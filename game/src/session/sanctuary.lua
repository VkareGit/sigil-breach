-- Shared physical sanctuary, independent of expedition progression. The test
-- field can exercise its shop without importing (or owning) an expedition.
local World = require('src.world.arena')
local Presentation = require('src.session.presentation')
local Maps = require('src.content.maps.index')
local Tuning = require('src.content.tuning')
-- The Ember of the default map (static readers); a session's own is at(g).
local Sanctuary = { shrine = Maps:get(Maps.default).ember }
function Sanctuary.at(g)
  return g.world and g.world.ember or Sanctuary.shrine
end

-- The knight stands within reach of the Ember and sees it.
function Sanctuary.near(g)
  local p, shrine = g.player, Sanctuary.at(g)
  local dx, dz = p.x - shrine.x, p.z - shrine.z
  return math.sqrt(dx * dx + dz * dz) < Tuning.reach.ember
    and World.visible(g.world, p.x, p.z, shrine.x, shrine.z)
end

function Sanctuary.openShop(g)
  if g.run.phase ~= 'preparing' or g.state ~= 'playing' or not Sanctuary.near(g) then
    return false
  end
  g.state = 'shop'
  g.fireBuffer = 0
  g.view.presentationPrevious = nil
  Presentation.capture(g, false)
  return true
end

return Sanctuary
