local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, renderer)
  local lines = {}
  local check = Fixtures.checker(lines, 'v15 ', '')
  require('tests.cases.body_physics').run(G, check)
  require('tests.cases.input_feel').run(G, check)
  require('tests.cases.visual_readability').run(check)
  require('tests.cases.app').run(G, renderer, check)
  local output = require('qa.output').directory()
  require('tests.cases.enemy_durability').report(output)
  return lines
end
return Tests
