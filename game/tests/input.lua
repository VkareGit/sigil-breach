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
  -- The menu walks into the chapel; the proving ground stands beside it.
  -- The menu session read the disk before this test began: a run stopped half way leaves a save.
  require('src.run.pilgrimage').forget(get())
  get().run.saved, get().availableSave = false, nil
  U.useMouse = false
  draw()
  local ids = {}
  for _, b in ipairs(U.controls(get(), settings)) do
    ids[b.id] = true
  end
  check(
    'the menu offers the chapel and the proving ground',
    ids.start and ids.field_skirmish and ids.field_start and not ids.restart
  )
  local carried = get().run.slot
  for step = 1, 3 do
    click('save_slot')
    check(
      'the menu moves to slot ' .. step,
      get().state == 'menu' and get().run.slot ~= carried or step == 3
    )
  end
  check('and comes round to the first', get().run.slot == carried)
  key('return')
  -- Every real transition completes its visible preparation with zero delta;
  -- control tests must not bypass the loader or advance combat while waiting.
  check(
    'Enter walks into the chapel through the real controller',
    get().state == 'playing' and get().mode == 'pilgrimage'
  )
  key('e')
  check('E rests at the first fire', get().state == 'shop')
  click('shop_back')
  check('the fire is left', get().state == 'playing')
  local body = require('src.session.world').of(get(), 'enemies')[1]
  get():damageEnemy(body, body.hp + 1, 'weapon', nil, get().player.id)
  check('a kill waits for a quiet moment to be saved', get().run.dirty)
  key('escape')
  check('Escape pauses the way', get().state == 'paused')
  -- The first frame after a load is discarded.
  love.update(1 / 120)
  love.update(1 / 120)
  check('and a paused game has saved it', not get().run.dirty)
  click('menu')
  check('the pause menu leads back to the main menu', get().state == 'menu')
  check('a rest is kept for the next visit', get().run.saved)
  check('the menu now continues', U.controls(get(), settings)[1].id == 'start')
  key('space')
  check('Space also walks in', get().state == 'playing' and get().mode == 'pilgrimage')
  -- The way moving onto another world passes through the loading page and comes back.
  get().world = require('src.world.arena').new('proving')
  love.update(1 / 120)
  love.update(1 / 120)
  check('a new world goes through the loading page', getLoading ~= nil and getLoading() ~= nil)
  settle()
  love.update(1 / 120)
  draw()
  check('and is played on', get().state == 'playing')
  key('escape')
  click('menu')
  click('restart')
  check('a new game asks first', get().state == 'confirm_new')
  click('new_confirm')
  check('and begins from nothing', get().state == 'playing' and not get().run.saved)
  key('escape')
  click('menu')
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
