-- Temporary visits own a stack of complete sessions; returning never copies
-- inventory or enemies between them. Application:adopt remains the sole switch.
local Game = require('src.session.game')
local Modes = require('src.run.modes')
local UI = require('src.ui.interface')
local Navigation = {}

local function settleInput(app)
  app.input:reset(true)
  app.accumulator, UI.focus = 0, 1
end
function Navigation.previous(app)
  local stack = app.navigation
  return stack and stack[#stack] or nil
end
function Navigation.clear(app)
  app.navigation = nil
end
function Navigation.replace(app, modeId, mapId)
  local session = Game.new(modeId, mapId)
  Navigation.clear(app)
  app:adopt(session)
  settleInput(app)
  return session
end
function Navigation.enter(app, modeId, mapId)
  -- Resolve and construct before changing the stack: an invalid target cannot
  -- consume the return destination or detach the current session.
  local nextSession = Game.new(modeId, mapId)
  local previous = app.game
  if previous then
    Modes.act(nextSession, 'visit', previous)
    app.navigation = app.navigation or {}
    app.navigation[#app.navigation + 1] = previous
  end
  app:adopt(nextSession)
  settleInput(app)
  return nextSession
end
function Navigation.back(app)
  local previous = Navigation.previous(app)
  if not previous then
    return false
  end
  table.remove(app.navigation)
  if #app.navigation == 0 then
    Navigation.clear(app)
  end
  app:adopt(previous)
  if previous.state == 'playing' then
    previous.state = 'paused'
  end
  previous.view.presentationPrevious = nil
  settleInput(app)
  love.mouse.setRelativeMode(false)
  return true
end
return Navigation
