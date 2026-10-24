local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, renderer)
  local Application = require('src.app.application')
  local Navigation = require('src.app.navigation')
  local Gallery = require('src.render.gallery')
  local Integrity = require('src.session.integrity')
  local UI = require('src.ui.interface')
  local Skin = require('src.ui.skin')
  local lines = {}
  local check = Fixtures.checker(lines, 'gallery loading: ', 'gallery loading: ')
  -- The fixture adds an existing PNG outside the production gallery cache.
  local board = {
    group = 'FIXTURE',
    name = 'Existing painted leap',
    path = require('src.content.ability_art').leap.path,
  }
  Gallery.boards[#Gallery.boards + 1] = board
  local originalImage, originalAudit = love.graphics.newImage, Skin.forceAudit
  local calls, paths = 0, {}
  local ok, problem = xpcall(function()
    love.graphics.newImage = function(...)
      calls = calls + 1
      if type((...)) == 'string' then
        paths[#paths + 1] = (...)
      end
      return originalImage(...)
    end
    local app = Application.new()
    app.qa = require('qa.runtime').new({ '--selftest' })
    app.qa.isolated, app.renderer = true, renderer
    app:reset(false)
    app:draw()
    calls = 0
    local previous = app.game
    local beforeReturn = Integrity.capture(previous)
    app:action('field_start')
    check(
      'first field waits behind an explicit loading boundary',
      app.loading and Navigation.previous(app) == previous
    )
    local loadingGame = app.game
    local initial = Integrity.capture(loadingGame)
    local total = app.loading.total
    app.input.sample = function()
      error('input sampled during loading')
    end
    app:update(0.1)
    check(
      'no image or simulation work precedes the first loading display',
      calls == 0 and not Integrity.difference(initial, Integrity.capture(loadingGame))
    )
    local rejected = app:action('field_close')
    check('commands cannot enter play behind the loading page', rejected == false and app.loading)
    app:action('loading_cancel')
    check(
      'cancel returns the exact previous session and clears field routing',
      app.game == previous
        and not app.loading
        and not Navigation.previous(app)
        and not Integrity.difference(beforeReturn, Integrity.capture(previous))
    )
    app:action('field_start')
    loadingGame = app.game
    initial = Integrity.capture(loadingGame)
    Skin.forceAudit = true
    local failures = Skin.auditFailureCount or 0
    for _, size in ipairs({
      { 960, 540 },
      { 1024, 768 },
      { 1280, 720 },
      { 1720, 720 },
      { 1920, 1080 },
    }) do
      local capture = love.graphics.newCanvas(size[1], size[2])
      love.graphics.setCanvas(capture)
      require('src.ui.loading').draw(UI, total, total, size[1], size[2])
      love.graphics.setCanvas()
      if size[1] == 1280 or size[1] == 1024 or size[1] == 1920 then
        local pixels = capture:newImageData()
        local png = pixels:encode('png')
        local path = require('qa.output').path('loading-' .. size[1] .. 'x' .. size[2] .. '.png')
        local file = assert(io.open(path, 'wb'))
        file:write(png:getString())
        file:close()
        png:release()
        pixels:release()
      end
      capture:release()
    end
    check('bitmap progress fits five physical viewports', (Skin.auditFailureCount or 0) == failures)
    local beforePreload = calls
    local steps = 0
    while app.loading do
      app:draw()
      check('loading never publishes a world shot observation', app.input.observation == nil)
      local before = calls
      app:update(0.1)
      steps = steps + 1
      check('preload step creates at most one image ' .. steps, calls - before == 1)
      check(
        'loading step leaves all simulation clocks and totals unchanged ' .. steps,
        not Integrity.difference(initial, Integrity.capture(loadingGame))
      )
      assert(steps <= total, 'preload did not converge')
    end
    check(
      'finite preload fills the shared cache exactly once',
      steps == total and Gallery.pending(renderer) == 0
    )
    app:update(0.1)
    check(
      'loading wall-clock delta is discarded before play',
      not Integrity.difference(initial, Integrity.capture(loadingGame))
    )
    app:action('field_leave')
    app:action('field_start')
    check(
      'second entry has zero loading steps and preserves return routing',
      not app.loading and Navigation.previous(app) == previous
    )
    local beforeDraw = calls
    paths = {}
    app:draw()
    check(
      'rendering the fully prepared gallery loads no more PNGs',
      Gallery.preloadStep(renderer) == 0 and #paths == 0 and beforeDraw == beforePreload + total
    )
    app:action('field_leave')
    check(
      'return session remains untouched by loading and field visits',
      app.game == previous and not Integrity.difference(beforeReturn, Integrity.capture(previous))
    )
    -- A transient native failure must remain visible, suspend simulation,
    -- permit cancel, and retry the same source on the next entry.
    local retryBoard =
      { group = 'FIXTURE', name = 'Recoverable source', path = 'assets/art/sigils/stolas-1904.png' }
    Gallery.boards[#Gallery.boards + 1] = retryBoard
    local imageBeforeFailure = love.graphics.newImage
    local attempts = 0
    love.graphics.newImage = function(path, ...)
      if path == retryBoard.path then
        attempts = attempts + 1
        if attempts == 1 then
          error('controlled gallery decode failure')
        end
      end
      return imageBeforeFailure(path, ...)
    end
    app:action('field_start')
    local failedState = Integrity.capture(app.game)
    app:draw()
    app:update(1 / 60)
    check(
      'failed preparation exposes an error and leaves simulation untouched',
      app.loading
        and app.loading.error
        and attempts == 1
        and not Integrity.difference(failedState, Integrity.capture(app.game))
    )
    app:update(1 / 60)
    check('failed preparation does not busy-retry behind the error screen', attempts == 1)
    app:action('loading_cancel')
    check(
      'failed preparation can return to its exact previous session',
      app.game == previous and not app.loading
    )
    app:action('field_start')
    require('qa.tooling').advanceUntil('gallery recovery', function()
      return not app.loading
    end, function(dt)
      app:draw()
      app:update(dt)
    end, 1 / 60, 5)
    check(
      'reentry retries the failed source and completes loading',
      attempts == 2 and Gallery.pending(renderer) == 0
    )
    app:action('field_leave')
    love.graphics.newImage = imageBeforeFailure
    table.remove(Gallery.boards)
  end, debug.traceback)
  love.graphics.newImage, Skin.forceAudit = originalImage, originalAudit
  table.remove(Gallery.boards)
  assert(ok, problem)
  return lines
end
return Tests
