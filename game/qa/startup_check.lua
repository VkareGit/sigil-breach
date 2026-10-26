-- Runs in a fresh process, before any application's presentation initialization.
-- Unlike a synchronous constructor benchmark this pumps the shipped draw/update
-- boundary, including failure, retry and cancellation of suspended work.
local Check = {}
function Check.run(output)
  local Application = require('src.app.application')
  local Audio = require('src.audio.audio')
  local Tooling = require('qa.tooling')
  local lines = Tooling.header('Staged application startup', false)
  local check = require('tests.support.fixtures').checker(lines, 'startup: ', 'startup: ')
  local function frame(app)
    love.graphics.clear()
    app:draw()
    love.graphics.present()
    app:update(1 / 60)
  end
  local function pump(app)
    local steps = 0
    while app.loading and not app.loading.error do
      assert(steps < 500, 'startup did not converge within 500 displayed frames')
      frame(app)
      steps = steps + 1
    end
    return steps
  end
  local started = love.timer.getTime()
  local app = Application.new()
  app:load({ '--startup-fixture' })
  check(
    'load returns before audio, interface and renderer jobs',
    app.loading and not app.renderer and not app.game and next(Audio.sources) == nil
  )
  app:update(1 / 60)
  check(
    'first update does no undisplayed heavy work',
    app.loading.steps == 0 and next(Audio.sources) == nil
  )
  app:draw()
  love.graphics.present()
  local firstImage = love.timer.getTime() - started
  pump(app)
  assert(not app.loading, app.loading and app.loading.error)
  check(
    'real staged startup reaches ready menu',
    app.renderer and app.game and app.game.state == 'menu' and not app.bootstrap
  )
  local report = app.lastStartupReport
  check('audio, UI and renderer yield actual intermediate steps', report.steps > 30 and report.done)
  lines[#lines + 1] = string.format(
    'New process load to first displayed loading image: %.3f ms; ready: %.3f ms; slices: %d; largest: %.3f ms',
    firstImage * 1000,
    (love.timer.getTime() - started) * 1000,
    report.steps,
    report.maxStep * 1000
  )
  local costs = {}
  for _, entry in ipairs(report.timings) do
    costs[entry.stage] = (costs[entry.stage] or 0) + entry.seconds
  end
  for _, stage in ipairs({ 'loading_sound', 'loading_interface', 'loading_world' }) do
    lines[#lines + 1] = string.format('%s: %.3f ms of work', stage, costs[stage] * 1000)
  end
  local slowest = {}
  for _, entry in ipairs(report.timings) do
    slowest[#slowest + 1] = entry
  end
  table.sort(slowest, function(a, b)
    return a.seconds > b.seconds
  end)
  for i = 1, math.min(5, #slowest) do
    local entry = slowest[i]
    lines[#lines + 1] = string.format(
      'Slow slice %d: %s / %s: %.3f ms',
      i,
      entry.stage,
      tostring(entry.detail),
      entry.seconds * 1000
    )
  end
  require('qa.cold_field').run(app, output, lines, check)
  app:quit()
  check(
    'quit releases global presentation owners',
    not app.ownsPresentation and next(Audio.sources) == nil
  )

  local originalImage = love.graphics.newImage
  local failurePath = require('assets.fonts.painted-v16.catalog').sizes[11].image
  local attempts = 0
  local failing = Application.new()
  love.graphics.newImage = function(path, ...)
    if path == failurePath then
      attempts = attempts + 1
      error('startup fixture image failure')
    end
    return originalImage(path, ...)
  end
  local ok, problem = xpcall(function()
    failing:load({ '--startup-fixture' })
    pump(failing)
    check(
      'native resource failure stays on visible loading page',
      failing.loading
        and failing.loading.error:find('startup fixture image failure', 1, true)
        and not failing.game
    )
    for _ = 1, 3 do
      frame(failing)
    end
    check(
      'failed startup neither retries nor advances simulation',
      attempts == 1 and not failing.game
    )
    love.graphics.newImage = originalImage
    check(
      'explicit retry starts a fresh plan',
      failing:action('loading_retry') and not failing.loading.error
    )
    pump(failing)
    check(
      'retry completes actual constructors after allocation failure',
      not failing.loading and failing.game and failing.renderer
    )
    failing:quit()
  end, debug.traceback)
  love.graphics.newImage = originalImage
  if not ok then
    failing:quit()
    error(problem)
  end

  local cancelled, quitCalled = Application.new(), false
  cancelled:load({ '--startup-fixture' })
  frame(cancelled)
  local worker = cancelled.loading
  local originalQuit = love.event.quit
  love.event.quit = function()
    quitCalled = true
  end
  local cancelledOK, cancelledProblem = pcall(function()
    cancelled:action('loading_cancel')
  end)
  love.event.quit = originalQuit
  assert(cancelledOK, cancelledProblem)
  check(
    'cancel drops coroutine and releases partially initialized audio',
    quitCalled
      and worker.cancelled
      and not worker.worker
      and not cancelled.loading
      and not cancelled.ownsPresentation
      and next(Audio.sources) == nil
  )
  collectgarbage('collect')
  local baseline = love.graphics.getStats()
  local midway = Application.new()
  midway:load({ '--startup-fixture' })
  for _ = 1, 500 do
    local plan = midway.loading
    local last = plan and plan.timings[#plan.timings]
    if last and last.detail == 'sprite shader' then
      break
    end
    assert(plan and not plan.error, plan and plan.error or 'missing renderer checkpoint')
    frame(midway)
  end
  check(
    'renderer cancellation fixture reaches an incomplete native constructor',
    midway.loading and not midway.renderer and midway.loading.stage == 'loading_world'
  )
  originalQuit = love.event.quit
  love.event.quit = function() end
  local midwayOK, midwayProblem = pcall(function()
    midway:action('loading_cancel')
  end)
  love.event.quit = originalQuit
  assert(midwayOK, midwayProblem)
  collectgarbage('collect')
  local released = love.graphics.getStats()
  check(
    'cancelled renderer and UI leave no additional images or canvases',
    released.images == baseline.images and released.canvases == baseline.canvases
  )
  lines[#lines + 1] =
    'Timings describe this machine/process, not a 16.7 ms guarantee; PNG decode and native upload remain indivisible.'
  Tooling.write(output, 'startup-check.txt', lines, false)
  for _, line in ipairs(lines) do
    print(line)
  end
end
return Check
