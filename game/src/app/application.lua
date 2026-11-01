local Context = require('src.session.context')
local FieldTools = require('src.app.field_tools')
local Game = require('src.session.game')
local Renderer = require('src.render.renderer')
local UI = require('src.ui.interface')
local Audio = require('src.audio.audio')
local Presentation = require('src.render.presentation')
local Sanctuary = require('src.session.sanctuary')
local Preferences = require('src.storage.preferences')
local QA = require('src.app.runtime')
local LoadPlan = require('src.app.load_plan')
local Loading = require('src.ui.loading')
local Input = require('src.app.input')
local Commands = require('src.app.commands')
local Navigation = require('src.app.navigation')
local Queries = require('src.run.queries')
local SessionReport = require('src.app.session_report')
local Pools = require('src.session.world')
-- The presentation plugs itself into the simulation's hooks (sound, effects,
-- feel, listeners); the simulation never requires it.
require('src.feedback.install')

local Application = {}
Application.__index = Application
local fixedStep = require('src.core.rate').step

-- One owner for session replacement, preferences, renderer, and frame timing.
-- Gameplay modules never need a reference to the application or its callbacks.
function Application.new()
  return setmetatable({
    settings = Preferences.decode(),
    qa = QA.new(),
    input = Input.new(),
    accumulator = 0,
    screenshotCaptured = false,
    sessionOptions = require('src.app.release').sessionOptions,
    sessionMaps = require('src.app.release').sessionMaps,
  }, Application)
end

function Application:has(flag)
  return self.qa:has(flag)
end

-- Collect the garbage of loading or of a left session now, at a transition,
-- instead of in one long pause during play; then keep the collector's steps
-- small (content/tuning.lua: collector).
function Application.settle()
  local pacing = require('src.content.tuning').collector
  collectgarbage('collect')
  collectgarbage('setpause', pacing.pause)
  collectgarbage('setstepmul', pacing.stepmul)
end

function Application:applySettings()
  self.game.view.motion = self.settings.motion
  self.game.view.fov = self.settings.fov
end

-- Make a session the active one (a new game, the proving ground, the way
-- back): settings, its journal with --record (every command of the session,
-- a bug report that replays exactly: session/journal.lua), and the garbage
-- of the one before collected now.
function Application:adopt(game)
  if self.renderer then
    require('src.render.gallery').forgetWorld(self.renderer)
  end
  self.loading = nil
  self.discardLoadingDelta = nil
  self.input:forget(self.game)
  self.input:forget(game)
  self.game = game
  -- In play particles vary from run to run (seeded from the clock, as before);
  -- QA keeps the session's fixed presentation seed so its captures repeat
  -- (feedback/transients.lua). The simulation's stream is never touched.
  if not (self.qa.capture or self.qa.isolated) and game.rng then
    game.rng.present:seed(os.time())
  end
  self:applySettings()
  local tools = Queries.tools(game)
  if tools and tools.gallery and self.renderer then
    local jobs = require('src.render.gallery').loadingJobs(self.renderer)
    if self.renderer.prepareWorld then
      for _, job in ipairs(require('src.render.kit.halls').loadingJobs(self.renderer, game.world)) do
        jobs[#jobs + 1] = job
      end
      jobs[#jobs + 1] = {
        label = 'loading_world',
        run = function(checkpoint)
          self.renderer:prepareWorld(game, checkpoint)
        end,
      }
    end
    if #jobs > 0 then
      self.loading = LoadPlan.new('loading_gallery', jobs)
      self.loading.kind = 'transition'
      self.accumulator = 0
      self.input:reset(true)
      love.mouse.setRelativeMode(false)
    end
  end
  if self:has('--record') then
    self.journals = self.journals or setmetatable({}, { __mode = 'k' })
    self.journals[game] = self.journals[game]
      or require('src.session.journal').record(game, nil, function()
        game:notify(require('src.content.text').get('recording_full'), 8)
      end)
    self.journal = self.journals[game]
  end
  Application.settle()
end

function Application:reset(start)
  Navigation.clear(self)
  self:adopt(Game.new(self.qa:session()))
  self.input:reset(love.mouse.isDown(1))
  self.accumulator = 0
  UI.focus = 1
  if start then
    self.game:start()
  end
end

-- Write the journal of the active session (with --record) to the save folder.
function Application:writeJournal(game)
  local journal = game and self.journals and self.journals[game]
  if not game then
    journal = self.journal
  end
  if not journal then
    return false
  end
  local name = 'journal-' .. os.time() .. '.txt'
  local Journal = require('src.session.journal')
  Journal.whenComplete(journal, function(completed)
    love.filesystem.write(name, Journal.encode(completed))
  end)
  return name
end
-- F9: the session's measurements to telemetry.txt (src/app/session_report.lua;
-- with --record the journal follows each entry), and where the file is.
function Application:report()
  if SessionReport.write(self.game, 'F9') then
    self.game:notify(
      require('src.content.text').get('telemetry_saved', { path = SessionReport.path() }),
      4
    )
    return true
  end
  return false
end
function Application:saveSettings()
  if not self.qa.isolated then
    Preferences.save(self.settings)
  end
end

function Application:action(id)
  if self.loading then
    if self.loading.kind == 'startup' then
      if id == 'loading_retry' and self.loading.error then
        self:discardStartup()
        self:beginStartup()
        return true
      elseif id == 'loading_cancel' then
        self:quit()
        love.event.quit()
        return true
      end
      return false
    end
    if id ~= 'loading_cancel' and id ~= 'field_leave' then
      return false
    end
    self.loading:cancel()
    self.loading = nil
    id = 'field_leave'
  end
  local before = self.game
  local state, map, help = before and before.state, before and before.map, before and before.help
  local result = Commands.dispatch(self, id)
  if
    self.game ~= before
    or (self.game and (self.game.state ~= state or self.game.map ~= map or self.game.help ~= help))
  then
    self.input:forget(self.game)
  end
  return result
end

function Application:load(arguments)
  self.qa = QA.new(arguments)
  -- Isolation must precede every preferences/save access, including QA fixtures.
  self.qa:prepare()
  if self.qa:runEarly() then
    return
  end
  if self:has('--ui-test') then
    love.window.setTitle(require('src.app.release').title .. ' [QA]')
  end
  love.graphics.setDefaultFilter('nearest', 'nearest')
  love.math.setRandomSeed(os.time())
  self.settings = Preferences.read()
  self.bootstrap = Loading.bootstrap(UI)
  self.ownsPresentation = true
  self:beginStartup()
end

-- Jobs are providers, not special cases in the frame loop. A yielded checkpoint
-- may resume only after the progress page has been submitted for display.
function Application:beginStartup()
  self.loading = LoadPlan.new('loading_sigil', {
    {
      label = 'loading_sound',
      run = function(checkpoint)
        Audio.init(checkpoint)
        Audio.muted = self.settings.muted or self.qa.capture
        require('src.audio.soundscape').music = self.settings.music
        love.audio.setVolume(Audio.muted and 0 or 0.7)
      end,
    },
    {
      label = 'loading_interface',
      run = function(checkpoint)
        UI.init(checkpoint)
      end,
    },
    {
      label = 'loading_world',
      run = function(checkpoint)
        require('src.enemies.art_contract').validateAll()
        checkpoint('art contracts')
        self.renderer = Renderer.new(checkpoint)
        self.renderer:resize(love.graphics.getDimensions())
      end,
    },
  })
  self.loading.kind = 'startup'
  self.accumulator = 0
  self.input:reset(true)
  love.mouse.setRelativeMode(false)
end

-- Covers constructors interrupted before they can return their renderer.
-- Dropping the worker frees its scopes; globals release explicitly. Bootstrap
-- fonts have their own small scope and remain available for the retry screen.
function Application:discardStartup()
  if self.loading then
    self.loading:cancel()
  end
  self.loading = nil
  if self.renderer then
    self.renderer:release()
    self.renderer = nil
  end
  require('src.render.weapon').release()
  UI.release()
  Audio.release()
  Application.settle()
end

function Application:finishStartup()
  Loading.releaseBootstrap(self.bootstrap)
  self.bootstrap = nil
  -- With --record, the journal of the session follows each telemetry entry.
  SessionReport.afterWrite = function(g)
    if self.journals and self.journals[g] then
      self:writeJournal(g)
    end
  end
  self:reset(false)
  if self.qa.capture then
    Audio.muted = true
    love.audio.stop()
    love.audio.setVolume(0)
  end
  if
    self.qa:run(
      Game,
      self.renderer,
      function()
        return self.game
      end,
      self.settings,
      function()
        return self.loading
      end
    )
  then
    return
  end
  if self:has('--ui-test') and self:has('--shop') then
    self.game:start()
    Sanctuary.openShop(self.game)
  end
  if self:has('--screenshot') then
    local game = self.game
    game:start()
    love.mouse.setRelativeMode(false)
    Context.actor(game).x, Context.actor(game).z, Context.actor(game).pitch = 16, 25.5, 0.04
    game.view.messageTimer = 0
    local first = Pools.of(game, 'enemies')[1]
    first.z, first.awake = 21.6, false
  end
end

function Application:update(dt)
  if self.loading then
    local plan = self.loading
    local done = plan:step()
    if plan.error then
      -- No one is there to press retry: the health check fails instead of waiting.
      assert(not self:has('--package-smoke'), plan.error)
      self.lastLoadError = plan.error
      self.input:forget(self.game)
      love.mouse.setRelativeMode(false)
    elseif done then
      self.loading = nil
      if plan.kind == 'startup' then
        self.lastStartupReport = plan
        self:finishStartup()
      else
        if plan.focused == false and self.game.state == 'playing' then
          self.game.state = 'paused'
        end
        self.input:forget(self.game)
        self.input:reset(true)
        self.accumulator, UI.focus = 0, 1
        self.discardLoadingDelta = true
        love.mouse.setRelativeMode(self.game.state == 'playing')
      end
    end
    return
  end
  if not self.game then
    return
  end
  if self.discardLoadingDelta then
    self.discardLoadingDelta = nil
    return
  end
  local input = self.input:sample(self.game)
  self.accumulator = math.min(0.20, self.accumulator + FieldTools.time(self, dt))
  while self.accumulator >= fixedStep do
    -- Only the last tick's starting pose can be interpolated for this draw.
    -- Earlier captures were immediately replaced without being presented.
    -- Input observations still describe the last displayed frame; these
    -- temporary motion samples never supply authoritative shot geometry.
    if self.accumulator - fixedStep < fixedStep then
      Presentation.capture(self.game)
    end
    self.game:update(fixedStep, input)
    -- Held controls repeat; dash and slide edges belong to one simulation tick.
    self.input:consumeEdges(input)
    self.accumulator = self.accumulator - fixedStep
  end
  if self:has('--screenshot') and self.game.time > 0.1 then
    self.game.state = 'paused'
  end
end

function Application:draw()
  local game = self.game
  local w, h = love.graphics.getDimensions()
  if self.loading then
    Loading.draw(
      self.bootstrap or UI,
      self.loading.remaining,
      self.loading.total,
      w,
      h,
      self.loading.error,
      self.loading.stage or self.loading.label,
      self.loading.kind == 'startup'
    )
    self.loading.shown = true
    return
  end
  if not game then
    return
  end
  local shown = Presentation.sample(game, self.accumulator * 120)
  self.renderer:draw(shown, w, h)
  if self:has('--screenshot') then
    local previous = game.state
    game.state = 'playing'
    UI.draw(shown, w, h, self.settings)
    game.state = previous
  else
    UI.draw(shown, w, h, self.settings)
  end
  -- Commit only a view that was actually submitted for display. This plain
  -- geometry belongs to the input adapter, never to mutable gameplay/view.
  self.input:present(game, shown)
  if self:has('--screenshot') and not self.screenshotCaptured and game.time > 0.1 then
    self.screenshotCaptured = true
    love.graphics.captureScreenshot(function(data)
      local file = io.open(self.qa.output .. '/gameplay.png', 'wb')
      if file then
        file:write(data:encode('png'):getString())
        file:close()
      end
      love.event.quit()
    end)
  end
end

function Application:resize(w, h)
  if self.renderer then
    self.renderer:resize(w, h)
  end
end

function Application:quit()
  love.mouse.setRelativeMode(false)
  self:saveSettings()
  if self.ownsPresentation then
    if self.loading then
      self.loading:cancel()
      self.loading = nil
    end
    Loading.releaseBootstrap(self.bootstrap)
    self.bootstrap = nil
    if self.renderer then
      self.renderer:release()
      self.renderer = nil
    end
    require('src.render.weapon').release()
    UI.shutdown()
    Audio.release()
    self.ownsPresentation = false
    Application.settle()
  end
end

function Application:errorhandler(message)
  local err = tostring(message) .. '\n' .. debug.traceback()
  local file = io.open('sigil-error.log', 'w')
  if file then
    file:write(err)
    file:close()
  end
  print(err)
  if self.qa.capture then
    return function()
      return 1
    end
  end
  love.mouse.setRelativeMode(false)
  return function()
    love.event.pump()
    for event, key in love.event.poll() do
      if event == 'quit' or (event == 'keypressed' and key == 'escape') then
        return 1
      end
    end
    love.graphics.reset()
    love.graphics.clear(0.04, 0.05, 0.06)
    love.graphics.setColor(1, 0.7, 0.5)
    love.graphics.printf(
      'SIGIL: BREACH — prototype error\n\n' .. err,
      30,
      30,
      love.graphics.getWidth() - 60
    )
    love.graphics.present()
    love.timer.sleep(0.1)
  end
end

return Application
