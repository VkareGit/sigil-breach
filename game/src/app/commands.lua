-- Application commands route session operations through mode contracts.
-- Navigation owns temporary visits; this module owns input/UI aftermath.
local Soundscape = require('src.audio.soundscape')
local Weapons = require('src.content.weapons')
local Chapel = require('src.ui.chapel')
local Help = require('src.ui.screens.help')
local Modes = require('src.session.modes')
local Navigation = require('src.app.navigation')
local UI = require('src.ui.interface')
local Audio = require('src.audio.audio')
local Intent = require('src.player.intent')
local Release = require('src.app.release')
local Settings = require('src.content.settings')
local Sets = require('src.content.sound_sets')
local Text = require('src.content.text')

local Commands = {}
local handlers = {}
local function playable(mode)
  return Release.playableModes[mode] == true
end
local immediateSettings = {
  fullscreen = true,
  mute = true,
  motion = true,
  hints = true,
  render_scale = true,
  sound_set = true,
  sens_down = true,
  sens_up = true,
  fov_down = true,
  fov_up = true,
  music_down = true,
  music_up = true,
  master_down = true,
  master_up = true,
  effects_down = true,
  effects_up = true,
  ambience_down = true,
  ambience_up = true,
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

local function start(app, id)
  local game = app.game
  if not playable(game.mode) then
    return
  end
  if Modes.act(game, 'newRequiresConfirmation', id) then
    game.view.confirmReturn = game.state
    game.state, UI.focus = 'confirm_new', 1
    love.mouse.setRelativeMode(false)
  else
    Navigation.replace(app, game.mode, game.world.mapId):start()
  end
end
-- 'start' (menu SPACE / ENTER) walks into the chapel, from the last fire if there is one.
handlers.start = function(app)
  Navigation.replace(app, 'pilgrimage'):start()
  love.mouse.setRelativeMode(true)
end
-- The next save slot: the menu stands on what that slot holds.
handlers.save_slot = function(app)
  app:useSlot(app.settings.slot + 1)
  app:saveSettings()
  app:reset(false)
end
handlers.restart = start
handlers.new_confirm = function(app)
  if playable(app.game.mode) then
    Modes.act(app.game, 'forget')
    Navigation.replace(app, app.game.mode, app.game.world.mapId):start()
  end
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
  Chapel.resetShop(app.game)
  app.input.suppressFire = true
end
handlers.shop_prev = function(app)
  Chapel.turnShop(app.game, -1)
end
handlers.shop_next = function(app)
  Chapel.turnShop(app.game, 1)
end
for _, station in ipairs({ 'arsenal', 'vows', 'sigils' }) do
  handlers['shop_station_' .. station] = function(app)
    require('src.ui.fire_shop').select(app.game, station)
    UI.focus = 1
  end
end
-- A card per weapon sold at a fire, however many: the id names the weapon.
local function shopCard(app, id)
  local weapon = id:sub(#'shop_card_' + 1)
  if Weapons.has(weapon) and Weapons.get(weapon).shop then
    require('src.ui.fire_shop').select(app.game, 'arsenal', weapon)
    UI.focus = 1
  end
end
local function shopWeapon(app, id)
  local slot = tonumber(id:match('%d+$'))
  if slot > Weapons.count(app.game) then
    return
  end
  app.game:switchWeapon(slot)
  app.input.suppressFire = true
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
  Help.reset(game)
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
  Help.reset(app.game)
end
handlers.help_prev = function(app)
  Help.turn(app.game, -1)
end
handlers.help_next = function(app)
  Help.turn(app.game, 1)
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
    require('src.feedback.motion').clearAll(app.game)
  end
end
handlers.hints = function(app)
  app.settings.hints = not app.settings.hints
end
-- The owner's A/B of the sounds (0.43, D02): F7 goes round the sets and says which one plays.
handlers.sound_set = function(app)
  local order = Sets.order
  local now = Audio.set
  for index, set in ipairs(order) do
    if set == now then
      app.settings.soundSet = Audio.useSet(order[index % #order + 1])
      break
    end
  end
  if app.game then
    app.game:notify(
      Text.get('sound_set_notice', { name = Text.get(Sets.names[app.settings.soundSet]) }),
      2
    )
  end
end
handlers.render_scale = function(app)
  local choices = Settings.renderScale.choices
  for index, scale in ipairs(choices) do
    if scale == app.settings.renderScale then
      app.settings.renderScale = choices[index % #choices + 1]
      app.game.view.renderScale = app.settings.renderScale
      return
    end
  end
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
-- The four levels (0.45, owner D17) step by a tenth; each takes effect at once.
local function level(app, id)
  local which, way = id:match('^(%a+)_(%a+)$')
  app.settings[which] = Settings.stepLevel(app.settings[which], way == 'up')
  Soundscape.music = app.settings.music
  Audio.levels.master = app.settings.master
  Audio.levels.effects = app.settings.effects
  Audio.levels.ambience = app.settings.ambience
  Audio.applyMaster()
end
for _, which in ipairs({ 'master', 'effects', 'music', 'ambience' }) do
  handlers[which .. '_down'], handlers[which .. '_up'] = level, level
end

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
  -- A weapon tab and a shop card per weapon, however many: the id names it.
  local handler = handlers[id]
    or (id:match('^shop_weapon_%d+$') and shopWeapon)
    or (id:match('^shop_card_') and shopCard)
  if handler then
    handler(app, id)
  elseif id:sub(1, 7) == 'remove_' then
    app.game:act('removeSigil', id:sub(8))
  elseif id:sub(1, 4) == 'buy_' then
    app.game:act('buy', id:sub(5))
  end
  app:saveSettings()
end

return Commands
