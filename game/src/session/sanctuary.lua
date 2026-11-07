-- The physical place of the trade, shared by the chapel and the proving ground.
local Intent = require('src.player.intent')
local Arena = require('src.world.arena')
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
    and Arena.visible(g.world, p.x, p.z, shrine.x, shrine.z)
end

-- The trade opens wherever the mode allows it.
function Sanctuary.trade(g)
  if not Capabilities.canTrade(g) or g.state ~= 'playing' then
    return false
  end
  g.state = 'shop'
  Intent.clear(g)
  g.view.presentationPrevious = nil
  Presentation.capture(g, false)
  return true
end

function Sanctuary.closeTrade(g)
  if g.state ~= 'shop' then
    return false
  end
  g.state = 'playing'
  Presentation.capture(g, true)
  return true
end

function Sanctuary.openShop(g)
  return Sanctuary.near(g) and Sanctuary.trade(g)
end

return Sanctuary
