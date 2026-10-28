local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(get, settings, output, getLoading)
  local U = require('src.ui.interface')
  local lines = {}
  local check = Fixtures.checker(lines, '', '')
  local function settle()
    local steps = 0
    while getLoading and getLoading() do
      assert(not getLoading().error, getLoading().error)
      assert(steps < 500, 'controller loading did not converge')
      love.draw()
      love.update(0)
      steps = steps + 1
    end
  end
  local function draw()
    local w, h = love.graphics.getDimensions()
    U.draw(get(), w, h, settings)
  end
  local function key(k)
    love.keypressed(k, k)
    settle()
    draw()
  end
  local function click(id)
    local w, h = love.graphics.getDimensions()
    local scale, ox, oy = U.viewport(w, h)
    for _, b in ipairs(U.controls(get(), settings)) do
      if b.id == id then
        love.mousepressed(ox + (b.x + b.w / 2) * scale, oy + (b.y + b.h / 2) * scale, 1)
        settle()
        draw()
        return
      end
    end
    error('button missing: ' .. id)
  end
  -- 0.22: the expedition is closed; the menu opens only the proving ground.
  -- (Its controller flow — shop, map, continue, retry — returns with the mode.)
  get().availableSave = nil
  U.useMouse = false
  draw()
  local ids = {}
  for _, b in ipairs(U.controls(get(), settings)) do
    ids[b.id] = true
  end
  check(
    'the menu offers the proving ground and no expedition',
    ids.field_skirmish and ids.field_start and not ids.start and not ids.continue
  )
  key('return')
  -- Every real transition completes its visible preparation with zero delta;
  -- control tests must not bypass the loader or advance combat while waiting.
  check(
    'Enter opens a skirmish through the real controller',
    get().state == 'playing' and get().testField and get().testField.skirmish
  )
  key('escape')
  check('Escape pauses the skirmish', get().state == 'paused')
  click('field_leave')
  check('the pause menu leads back to the main menu', get().state == 'menu' and not get().testField)
  key('space')
  check(
    'Space also opens a skirmish from the menu',
    get().state == 'playing' and get().testField and get().testField.skirmish
  )
  key('escape')
  click('field_leave')
  for _, line in ipairs(require('tests.cases.test_field_input').run(get, settings, settle)) do
    lines[#lines + 1] = line
  end
  for _, line in ipairs(require('tests.cases.input_lifecycle').run(get, settings, settle)) do
    lines[#lines + 1] = line
  end
  lines[#lines + 1] = '\n'
    .. #lines
    .. ' controller checks. Real love.keypressed/love.mousepressed callbacks, actual saves in isolated QA identity.'
  lines[#lines + 1] = 'Save directory used by this test: ' .. love.filesystem.getSaveDirectory()
  lines[#lines + 1] = require('qa.output').receipt()
  local file = assert(io.open(output or require('qa.output').path('input-results.txt'), 'w'))
  file:write(table.concat(lines, '\n'))
  file:close()
  print(table.concat(lines, '\n'))
  love.mouse.setRelativeMode(false)
end
return Tests
