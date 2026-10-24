-- Application commands route session operations through mode contracts.
-- Navigation owns temporary visits; this module owns input/UI aftermath.
local Modes = require('src.run.modes')
local Navigation = require('src.app.navigation')
local UI = require('src.ui.interface')
local Audio = require('src.audio.audio')
local Intent = require('src.player.intent')

local Commands = {}
local handlers = {}
local immediateSettings = {
  fullscreen = true,
  mute = true,
  motion = true,
  hints = true,
  sens_down = true,
  sens_up = true,
  fov_down = true,
  fov_up = true,
  music_down = true,
  music_up = true,
}

-- The test field temporarily owns a different session. Keep return routing here,
-- never in combat code, so its enemies and inventory cannot leak into a run.
-- What the catalogue does to the field session is a session command
-- (Game:act 'catalog'), so the command journal replays it.
local function fieldCommand(app, id)
  local game = app.game
  if id == 'field_start' or id == 'field_open' or id == 'field_skirmish' then
    if game.mode ~= 'field' then
      Navigation.enter(app, 'field')
    else
      game:act('catalog', 'field_open')
    end
    if id == 'field_skirmish' then
      app.game:act('catalog', 'field_skirmish')
    end
    app.input:reset(true)
    app.accumulator, UI.focus = 0, 1
    return true
  elseif id == 'field_leave' or (id == 'menu' and Navigation.previous(app)) then
    if not Navigation.back(app) then
      app:reset(false)
    end
    app.game.view.presentationPrevious = nil
    app.input:reset(true)
    app.accumulator, UI.focus = 0, 1
    love.mouse.setRelativeMode(false)
    return true
  elseif game.mode == 'field' and id == 'restart' then
    game:act('catalog', 'field_reset')
    app.input:reset(true)
    UI.focus = 1
    return true
  elseif game:act('catalog', id) then
    app.input:reset(true)
    app.accumulator = 0
    return true
  end
  return false
end

handlers.continue = function(app)
  if not app.game.availableSave then
    return
  end
  local saved = app.game.availableSave
  Navigation.replace(app, saved.mode or app.game.mode, saved.map)
  Modes.act(app.game, 'load', saved)
  app.input.suppressFire = true
end

local function start(app, id)
  local game = app.game
  if Modes.act(game, 'newRequiresConfirmation', id) then
    game.view.confirmReturn = game.state
    game.state, UI.focus = 'confirm_new', 1
    love.mouse.setRelativeMode(false)
  else
    app:reset(true)
  end
end
-- 0.22: the expedition is closed; 'start' (menu SPACE / ENTER) opens a
-- skirmish on the proving ground. restart keeps its expedition meaning for
-- the library code and old saves, unreachable from the menu.
handlers.start = function(app)
  fieldCommand(app, 'field_skirmish')
end
handlers.restart = start
handlers.new_confirm = function(app)
  app:reset(true)
end
handlers.new_cancel = function(app)
  app.game.state = app.game.view.confirmReturn or 'menu'
  UI.focus = 1
end
-- What retry, ready, leaving the shop and buying mean is the mode's
-- (run/modes.lua: Modes.act), issued through the session (Game:act) so the
-- command journal records them.
handlers.retry = function(app)
  app.game:act('retry')
  app.input:reset(true)
  UI.focus = 1
end
handlers.ready = function(app)
  if app.game:act('ready') then
    app.input:reset(true)
  end
end
handlers.shop_back = function(app)
  app.game:act('closeShop')
  require('src.ui.descent').resetShop(app.game)
  app.input.suppressFire = true
end
handlers.shop_prev = function(app)
  require('src.ui.descent').turnShop(app.game, -1)
end
handlers.shop_next = function(app)
  require('src.ui.descent').turnShop(app.game, 1)
end
local function shopWeapon(app, id)
  local slot = tonumber(id:match('%d+$'))
  if slot > require('src.content.weapons').count(app.game) then
    return
  end
  app.game:switchWeapon(slot)
  app.input.suppressFire = true
end
for slot = 1, 9 do
  handlers['shop_weapon_' .. slot] = shopWeapon
end

handlers.resume = function(app)
  if app.game.state == 'settings' then
    app.game.state = 'menu'
  else
    app.game.state = 'playing'
    app.input.suppressFire, app.input.pendingDash = true, false
    love.mouse.setRelativeMode(true)
  end
end
handlers.menu = function(app)
  app:reset(false)
  love.mouse.setRelativeMode(false)
end
handlers.settings = function(app)
  app.game.state = 'settings'
end
handlers.help = function(app)
  local game = app.game
  require('src.ui.screens.help').reset(game)
  UI.focus = 1
  game.help, game.map = true, false
  if game.state == 'playing' then
    game.state = 'paused'
    app.input.pendingDash = false
    love.mouse.setRelativeMode(false)
  end
end
handlers.help_back = function(app)
  app.game.help = false
  require('src.ui.screens.help').reset(app.game)
end
handlers.help_prev = function(app)
  require('src.ui.screens.help').turn(app.game, -1)
end
handlers.help_next = function(app)
  require('src.ui.screens.help').turn(app.game, 1)
end
handlers.map = function(app)
  app.game.map = false
  app.input.suppressFire = true
  love.mouse.setRelativeMode(true)
end
handlers.quit = function()
  love.event.quit()
end
handlers.fullscreen = function()
  love.window.setFullscreen(not love.window.getFullscreen(), 'desktop')
end
handlers.mute = function(app)
  Audio.toggle()
  app.settings.muted = Audio.muted
end
handlers.motion = function(app)
  app.settings.motion = not app.settings.motion
  app.game.view.motion = app.settings.motion
  if not app.settings.motion then
    require('src.player.feel').clearMotion(app.game)
  end
end
handlers.hints = function(app)
  app.settings.hints = not app.settings.hints
end

local function sensitivity(app, id)
  app.settings.sensitivity =
    math.max(0.2, math.min(3, app.settings.sensitivity + (id == 'sens_up' and 0.1 or -0.1)))
end
handlers.sens_down, handlers.sens_up = sensitivity, sensitivity
local function fov(app, id)
  app.settings.fov = math.max(85, math.min(115, app.settings.fov + (id == 'fov_up' and 5 or -5)))
  app.game.view.fov = app.settings.fov
end
handlers.fov_down, handlers.fov_up = fov, fov
local function music(app, id)
  app.settings.music =
    math.max(0, math.min(1, app.settings.music + (id == 'music_up' and 0.1 or -0.1)))
  require('src.audio.soundscape').music = app.settings.music
end
handlers.music_down, handlers.music_up = music, music

-- Shared dispatch policy applies equally to mouse, keyboard, and menu commands.
-- Add a handler here without extending a long sequence of unrelated branches.
function Commands.dispatch(app, id)
  if not id then
    return
  end
  if app.game and not immediateSettings[id] then
    Intent.clear(app.game)
  end
  if fieldCommand(app, id) then
    return
  end
  local handler = handlers[id]
  if handler then
    handler(app, id)
  elseif id:sub(1, 4) == 'buy_' then
    app.game:act('buy', id:sub(5))
  end
  app:saveSettings()
end

return Commands
