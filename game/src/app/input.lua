local UI = require('src.ui.interface')
local Intent = require('src.player.intent')
local Screens = require('src.app.screens')
local Bindings = require('src.app.bindings')
local Tuning = require('src.content.tuning')
local Observation = require('src.combat.observation')
local Queries = require('src.run.queries')

local Input = {}
Input.__index = Input
-- Every key of play names one action or one ability slot (app/bindings.lua).
local keyAction, abilitySlot = {}, {}
for action, keys in pairs(Bindings.actions) do
  for _, key in ipairs(keys) do
    assert(not keyAction[key], 'key bound twice: ' .. key)
    keyAction[key] = action
  end
end
for slot, key in ipairs(Bindings.abilities) do
  assert(not keyAction[key] and not abilitySlot[key], 'key bound twice: ' .. key)
  abilitySlot[key] = slot
end
local function held(name)
  return love.keyboard.isDown(unpack(Bindings.held[name])) and 1 or 0
end

function Input.new()
  return setmetatable({ pendingDash = false, pendingSlide = false, suppressFire = false }, Input)
end

-- Physical button suppression is separate from buffered gameplay intent:
-- holding the click that selected a menu entry must not fire on entering play.
function Input:reset(suppressFire)
  self:forget(self.observationOwner)
  self.pendingDash = false
  self.pendingSlide = false
  self.suppressFire = suppressFire
end

function Input:forget(game)
  if game then
    Observation.invalidate(game)
    Intent.clear(game)
  end
  self.observation, self.observationOwner, self.observations = nil, nil, nil
end
-- The view shown is observed for the knight it is shown to (plan v11 E4: one
-- observation per actor, by its shooter; default the controlled knight); a
-- command takes its actor's own.
function Input:present(game, shown, actor)
  if game.state == 'playing' and not game.map and not game.help then
    local observation = Observation.capture(shown, game, actor)
    if self.observationOwner ~= game then
      self.observations = {}
    end
    self.observations = self.observations or {}
    self.observations[observation.shooter or false] = observation
    self.observation = observation
    self.observationOwner = game
  elseif self.observationOwner then
    self:forget(game)
  end
end
function Input:command(game, actor)
  if game and self.observationOwner == game and self.observations then
    local observation = Observation.mine(game, self.observations, actor)
    return observation and Observation.command(observation, game, actor)
  end
end
function Input:sample(game)
  local mouseDown = love.mouse.isDown(1)
  if not mouseDown then
    self.suppressFire = false
  end
  return {
    forward = held('forward') - held('back'),
    strafe = held('right') - held('left'),
    turn = held('turnRight') - held('turnLeft'),
    shoot = mouseDown and not self.suppressFire,
    fireCommand = mouseDown and not self.suppressFire and self:command(game) or nil,
    dash = self.pendingDash,
    slide = self.pendingSlide,
    jump = held('jump') == 1,
  }
end

function Input:consumeEdges(sample)
  self.pendingDash, self.pendingSlide = false, false
  sample.dash, sample.slide = false, false
end

function Input:mousemoved(app, x, y, dx, dy)
  local w, h = love.graphics.getDimensions()
  UI.hover(UI.toLogical(x, y, w, h))
  local game = app.game
  if
    game
    and game.state == 'playing'
    and not game.map
    and not game.help
    and love.mouse.getRelativeMode()
  then
    -- One sensitivity for both axes (0.25, D6): radians per mouse count.
    local turn = Tuning.camera.mouse * app.settings.sensitivity
    game:look(dx * turn, -dy * turn)
    game.view.swayX = math.max(-0.18, math.min(0.18, game.view.swayX - dx * 0.0009))
    game.view.swayY = math.max(-0.14, math.min(0.14, game.view.swayY + dy * 0.0009))
  end
end

function Input:keypressed(app, key, scancode, isrepeat)
  local game = app.game
  if not game then
    return
  end
  if key == 'f2' then
    app:action(
      Queries.field(game) and game.state == 'field_catalog' and 'field_close' or 'field_open'
    )
    return
  end
  if key == 'escape' or key == 'tab' or key == 'f1' then
    self.pendingSlide = false
    Intent.clear(game)
  end
  if key == 'f11' then
    app:action('fullscreen')
    return
  end
  if key == 'm' then
    app:action('mute')
    return
  end
  if key == 'f9' then
    app:report()
    return
  end
  if key == 'f12' then
    love.graphics.captureScreenshot('screenshot-' .. os.time() .. '.png')
    game:notify(require('src.content.text').get('screenshot_saved'), 2)
    return
  end
  if key == 'f1' then
    app:action(game.help and 'help_back' or 'help')
    return
  end
  if game.help then
    if key == 'escape' then
      app:action('help_back')
    elseif Screens.navigation[key] then
      UI.navigate(game, app.settings, Screens.navigation[key])
    elseif key == 'return' then
      app:action(UI.selected(game, app.settings))
    end
    return
  end
  if game.map then
    if key == 'tab' or key == 'escape' or key == 'return' then
      app:action('map')
    end
    return
  end

  local screen = Screens:find(game.state)
  if not screen then
    return
  end
  local command = screen.keys[key]
  if command then
    app:action(command)
    return
  end
  if screen.gameplay then
    self:gameplayKey(app, key, isrepeat)
    return
  end
  if Screens.navigation[key] then
    UI.navigate(game, app.settings, Screens.navigation[key])
  elseif key == 'return' then
    app:action(UI.selected(game, app.settings))
  end
end

-- What each action of play does (its keys: app/bindings.lua).
local gameplay = {}
function gameplay.ready(_, app, game)
  if Queries.run(game) then
    app:action('ready')
  end
end
function gameplay.pause(self, _, game)
  self:forget(game)
  self.suppressFire = true
  game.state = 'paused'
  UI.focus = 1
  self.pendingDash = false
  love.mouse.setRelativeMode(false)
end
function gameplay.dash(self)
  self.pendingDash = true
end
function gameplay.slide(self)
  self.pendingSlide = true
end
function gameplay.jump(_, _, game, isrepeat)
  if not isrepeat then
    Intent.queue(game, 'jump')
  end
end
function gameplay.interact(self, _, game)
  if game:interact() and game.state == 'shop' then
    Intent.clear(game)
    UI.focus = 1
    self:reset(true)
  end
end
function gameplay.reload(_, _, game)
  game:reloadGun()
end
function gameplay.map(self, _, game)
  self:forget(game)
  self.suppressFire = true
  game.map = true
  self.pendingDash = false
  love.mouse.setRelativeMode(false)
end
function Input:gameplayKey(app, key, isrepeat)
  local game = app.game
  local action = keyAction[key]
  if action then
    gameplay[action](self, app, game, isrepeat)
  elseif abilitySlot[key] then
    -- An ability slot of the loadout (a slot with no ability does nothing).
    game:cast(abilitySlot[key])
  elseif key:match('^[1-9]$') then
    -- A slot of the loadout (a key past the last slot does nothing).
    game:switchWeapon(tonumber(key))
  end
end

function Input:mousepressed(app, x, y, button)
  local game = app.game
  if button ~= 1 or not game then
    return
  end
  local w, h = love.graphics.getDimensions()
  x, y = UI.toLogical(x, y, w, h)
  if game.state ~= 'playing' or game.map or game.help then
    app:action(UI.actionAt(game, app.settings, x, y))
  elseif not self.suppressFire then
    local command = self:command(game)
    if not game:shoot(command) then
      Intent.queue(game, 'fire', command)
    end
  end
end

function Input:wheelmoved(app, x, y)
  local game = app.game
  if game and game.state == 'playing' and not game.map and y ~= 0 then
    game:switchWeapon(require('src.content.weapons').nextSlot(game))
  end
end

function Input:focus(app, focused)
  local game = app.game
  if not focused and game and game.state == 'playing' and not app:has('--screenshot') then
    self:forget(game)
    self.suppressFire = true
    Intent.clear(game)
    game.map = false
    self.pendingDash, self.pendingSlide = false, false
    UI.focus = 1
    game.state = 'paused'
    love.mouse.setRelativeMode(false)
  end
end

return Input
