local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, renderer)
  -- Rules proven on the encounters they were tuned for (tests/support/v033_encounters.lua).
  G = require('tests.support.v033_encounters').game(G)
  local lines = {}
  local check = Fixtures.checker(lines, 'v10 ', '')
  require('tests.cases.movement').run(G, check)
  require('tests.cases.ordnance').run(check)
  require('tests.cases.combat').run(check)
  require('tests.cases.enemies').run(check)
  return lines
end
return Tests
