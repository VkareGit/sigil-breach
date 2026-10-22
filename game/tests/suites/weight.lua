local Fixtures = require('tests.support.fixtures')
local T = {}
function T.run(G, renderer)
  local lines = {}
  local check = Fixtures.checker(lines, 'v13 ', '')
  require('tests.cases.weapon_motion').run(G, check)
  require('tests.cases.knight_portrait').run(check)
  require('tests.cases.enemy_idle').run(check, renderer)
  require('tests.cases.lighting').run(G, check, renderer)
  require('tests.cases.movement_impact').run(G, check)
  require('tests.cases.impact_response').run(G, check)
  require('tests.cases.shotgun_core').run(check, renderer)
  require('tests.cases.anatomical_heads').run(check, renderer)
  require('tests.cases.enemy_durability').run(G, check, renderer, require('qa.output').directory())
  require('tests.cases.combat_feel').run(G, check)
  require('tests.cases.rules').run(G, check)
  require('tests.cases.weight').run(G, check)
  require('tests.cases.gallery').run(G, check)
  require('tests.cases.impulse_law').run(G, check)
  require('tests.cases.difficulty').run(G, check)
  require('tests.cases.momentum_counter').run(G, check)
  require('tests.cases.content_schema').run(G, check)
  require('tests.cases.push_forward').run(G, check)
  require('tests.cases.polish_regressions').run(G, check)
  require('tests.cases.stations').run(G, check)
  return lines
end
return T
