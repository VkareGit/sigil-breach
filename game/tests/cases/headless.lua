-- F1: the simulation runs without any presentation. With every presentation
-- hook and listener removed, and graphics, audio and the mouse made to fail
-- when touched, a drill fight gives the same digest as with them.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
local function forbidden(name)
  return setmetatable({}, {
    __index = function(_, key)
      error('headless simulation touched love.' .. name .. '.' .. tostring(key), 2)
    end,
  })
end
function Tests.run(G)
  local lines = {}
  local check = Fixtures.checker(lines, 'headless: ', 'headless: ')
  local Golden = require('qa.golden')
  local Drill = require('qa.scenarios.drill')
  local Presentation = require('src.session.presentation')
  local seconds = 12
  local presented = Golden.digest(Drill.run(G, nil, seconds))
  local hooks, attachers = Presentation.hooks, Presentation.attachers
  local graphics, audio, mouse = love.graphics, love.audio, love.mouse
  Presentation.hooks, Presentation.attachers = {}, {}
  love.graphics, love.audio, love.mouse =
    forbidden('graphics'), forbidden('audio'), forbidden('mouse')
  local ok, result = pcall(function()
    return Drill.run(G, nil, seconds)
  end)
  love.graphics, love.audio, love.mouse = graphics, audio, mouse
  Presentation.hooks, Presentation.attachers = hooks, attachers
  assert(ok, 'FAIL headless: ' .. tostring(result))
  check('the simulation runs with no presentation loaded', ok)
  check('and reproduces the presented fight bit for bit', ok and Golden.digest(result) == presented)
  check(
    'no particles, trails or sounds were made without a presentation',
    ok and #result.view.particles == 0
  )
  return lines
end
return Tests
