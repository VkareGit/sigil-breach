-- Shared physical sanctuary, independent of expedition progression. The test
-- field can exercise its shop without importing (or owning) an expedition.
local World = require('src.world.arena')
local Presentation = require('src.session.presentation')
local Maps = require('src.content.maps.index')
local Tuning = require('src.content.tuning')
local Capabilities = require('src.session.capabilities')
local Roles = require('src.core.roles')
-- The Ember of the default map (static readers); a session's own is at(g).
local Sanctuary = {}
function Sanctuary.at(g)
  return g.world.ember
end

-- The knight stands within reach of the Ember and sees it.
function Sanctuary.near(g)
  local p, shrine = Roles.controlled(g), Sanctuary.at(g)
  if not shrine then
    return false
  end
  local dx, dz = p.x - shrine.x, p.z - shrine.z
  return math.sqrt(dx * dx + dz * dz) < Tuning.reach.ember
    and World.visible(g.world, p.x, p.z, shrine.x, shrine.z)
end

function Sanctuary.openShop(g)
  if not Capabilities.canTrade(g) or g.state ~= 'playing' or not Sanctuary.near(g) then
    return false
  end
  g.state = 'shop'
  require('src.player.intent').clear(g)
  g.view.presentationPrevious = nil
  Presentation.capture(g, false)
  return true
end

return Sanctuary
