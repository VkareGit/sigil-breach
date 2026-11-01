local Context = require('src.session.context')
local Pools = require('src.session.world')
local UI = require('src.ui.interface')
local Intent = require('src.player.intent')
local Screens = require('src.app.screens')
local Bindings = require('src.app.bindings')
local FieldTools = require('src.app.field_tools')
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
local function held(self, name)
  if self.device and self.device.held then
    local value = self.device.held(name)
    return type(value) == 'number' and value or (value and 1 or 0)
  end
  return love.keyboard.isDown(unpack(Bindings.held[name])) and 1 or 0
end

-- A device owns its observation and buffered edges; binding it does not
-- transfer session control. Omitted actor/device retain the single-player API.
function Input.new(actor, device)
  return setmetatable({
    actor = actor,
    device = device,
    pendingDash = false,
    pendingSlide = false,
    suppressFire = false,
  }, Input)
end
function Input:actorOf(game)
  if self.actor ~= nil then
    local id = type(self.actor) == 'table' and self.actor.id or self.actor
    return Pools.get(game, id)
  end
  return Context.actor(game)
end
-- Public game commands cross the journal boundary: pass an actor id, never
-- a mutable body. Preserve the legacy argument count for the default device.
-- A missing binding refuses the command rather than meaning "controlled".
function Input:invoke(game, name, ...)
  local actor = self:actorOf(game)
  if not actor then
    return false
  end
  if self.actor == nil and Context.isControlled(game, actor) then
    return game[name](game, ...)
  end
  local arguments, count = { ... }, select('#', ...)
  arguments[count + 1] = actor.id
  return game[name](game, unpack(arguments, 1, count + 1))
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
    if self.actor then
      Observation.invalidateActor(game, self:actorOf(game))
    else
      Observation.invalidate(game)
    end
    local actor = self:actorOf(game)
    if actor then
      Intent.clear(game, actor)
    end
  end
  self.observation, self.observationOwner, self.observations = nil, nil, nil
end
-- The view shown is observed for the knight it is shown to (plan v11 E4: one
-- observation per actor, by its shooter; default the controlled knight); a
-- command takes its actor's own.
function Input:present(game, shown, actor)
  if
    game.state == 'playing'
    and not game.map
    and not game.help
    and (actor or self:actorOf(game))
  then
    local observation = Observation.capture(shown, game, actor or self:actorOf(game))
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
  actor = actor or (game and self:actorOf(game))
  if game and actor and self.observationOwner == game and self.observations then
    local observation = Observation.mine(game, self.observations, actor)
    return observation and Observation.command(observation, game, actor)
  end
end
function Input:sample(game)
  local mouseDown
  if self.device and self.device.mouseDown then
    mouseDown = self.device.mouseDown()
  else
    mouseDown = love.mouse.isDown(1)
  end
  if not mouseDown then
    self.suppressFire = false
  end
  local sample = {
    forward = held(self, 'forward') - held(self, 'back'),
    strafe = held(self, 'right') - held(self, 'left'),
    turn = held(self, 'turnRight') - held(self, 'turnLeft'),
    shoot = mouseDown and not self.suppressFire,
    altFire = false,
    fireCommand = mouseDown and not self.suppressFire and self:command(game) or nil,
    dash = self.pendingDash,
    slide = self.pendingSlide,
    jump = held(self, 'jump') == 1,
  }
  local actor = game and self:actorOf(game)
  if self.actor then
    return { actors = actor and { [actor.id] = sample } or {} }
  end
  return sample
end

function Input:consumeEdges(sample)
  self.pendingDash, self.pendingSlide = false, false
  if sample.actors then
    for _, state in pairs(sample.actors) do
      state.dash, state.slide = false, false
    end
  else
    sample.dash, sample.slide = false, false
  end
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
    local actor = self:actorOf(game)
    if not actor then
      return
    end
    self:invoke(game, 'look', dx * turn, -dy * turn)
    local view = Context.view(game, actor)
    if view then
      view.swayX = math.max(-0.18, math.min(0.18, view.swayX - dx * 0.0009))
      view.swayY = math.max(-0.14, math.min(0.14, view.swayY + dy * 0.0009))
    end
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
  if FieldTools.key(app, key) then
    return
  end
  if key == 'escape' or key == 'tab' or key == 'f1' then
    self.pendingSlide = false
    local actor = self:actorOf(game)
    if actor then
      Intent.clear(game, actor)
    end
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
function gameplay.jump(self, _, game, isrepeat)
  if not isrepeat then
    Intent.queue(game, 'jump', nil, self:actorOf(game))
  end
end
function gameplay.interact(self, _, game)
  if self:actorOf(game) ~= Context.actor(game) then
    return
  end
  if game:interact() and game.state == 'shop' then
    local actor = self:actorOf(game)
    if actor then
      Intent.clear(game, actor)
    end
    UI.focus = 1
    self:reset(true)
  end
end
function gameplay.reload(self, _, game)
  self:invoke(game, 'reloadGun')
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
  if not self:actorOf(game) then
    return
  end
  local action = keyAction[key]
  if action then
    gameplay[action](self, app, game, isrepeat)
  elseif abilitySlot[key] then
    -- An ability slot of the loadout (a slot with no ability does nothing).
    self:invoke(game, 'cast', abilitySlot[key])
  elseif key:match('^[1-9]$') then
    -- A slot of the loadout (a key past the last slot does nothing).
    self:invoke(game, 'switchWeapon', tonumber(key))
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
  elseif not self.suppressFire and self:actorOf(game) then
    local command = self:command(game)
    if not self:invoke(game, 'shoot', command) then
      Intent.queue(game, 'fire', command, self:actorOf(game))
    end
  end
end

function Input:wheelmoved(app, x, y)
  local game = app.game
  if game and game.state == 'playing' and not game.map and y ~= 0 and self:actorOf(game) then
    local actor = self:actorOf(game)
    self:invoke(game, 'switchWeapon', require('src.content.weapons').nextSlot(game, actor))
  end
end

function Input:focus(app, focused)
  local game = app.game
  if not focused and game and game.state == 'playing' and not app:has('--screenshot') then
    self:forget(game)
    self.suppressFire = true
    local actor = self:actorOf(game)
    if actor then
      Intent.clear(game, actor)
    end
    game.map = false
    self.pendingDash, self.pendingSlide = false, false
    UI.focus = 1
    game.state = 'paused'
    love.mouse.setRelativeMode(false)
  end
end

return Input
