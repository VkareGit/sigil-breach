local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, renderer)
  local lines = {}
  local check = Fixtures.checker(lines, 'v12 ', '')
  require('tests.cases.fresco_enemies').run(check, renderer)
  require('tests.cases.fresco_weapons').run(check)
  require('tests.cases.fresco_scene').run(check, renderer)
  require('tests.cases.fresco_geometry').run(G, check)
  for _, line in ipairs(require('tests.cases.pose_metadata').run(G, renderer)) do
    lines[#lines + 1] = line
  end
  return lines
end
return Tests
