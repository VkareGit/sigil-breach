local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G)
  local lines = {}
  local check = Fixtures.checker(lines, 'impact origin: ', 'impact origin: ')
  local near = Fixtures.within(1e-7)
  local Rules = require('src.combat.rules')
  local X = require('src.combat.explosives')
  local Field = require('src.run.test_field')
  local function fixture(playerX)
    local g = Field.new(G)
    g.ephemeral = true
    Field.close(g)
    g.player.x, g.player.z = playerX, 26
    g.enemies = {}
    local e = g:spawn('imp', 16, 22)
    e.hp, e.maxHp, e.armorRating = 1000, 1000, 0
    return g, e
  end
  local g, e = fixture(10)
  Rules.react(g, e, 40, true, nil, 10, { direction = { 0, 1 }, push = 30 })
  local other, target = fixture(22)
  Rules.react(other, target, 40, true, nil, 10, { direction = { 0, 4 }, push = 30 })
  check(
    'incoming direction is independent of the current player location',
    near(e.pushX or 0, target.pushX or 0) and near(e.pushZ or 0, target.pushZ or 0)
  )
  -- Query the actual velocity field used by the body response, not a UI receipt.
  check('the impulse travels away from its source', (e.pushZ or 0) > 0 and near(e.pushX or 0, 0))
  g, e = fixture(10)
  X.explode(
    g,
    { action = require('src.content.abilities'):get('powder').action, x = 16, y = 1, z = 21 }
  )
  other, target = fixture(22)
  X.explode(
    other,
    { action = require('src.content.abilities'):get('powder').action, x = 16, y = 1, z = 21 }
  )
  check(
    'a grenade behind a demon pushes it forward even after the thrower moves',
    (e.pushZ or 0) > 0
      and near(e.pushX or 0, 0)
      and near(e.pushZ or 0, target.pushZ or 0)
      and near(e.hp, target.hp)
  )
  g, e = fixture(10)
  Rules.react(g, e, 40, true, nil, 10, { direction = { 0, 0 }, push = 30 })
  check(
    'a vertical impulse has no invented horizontal direction',
    near(e.pushX or 0, 0) and near(e.pushZ or 0, 0)
  )
  g, e = fixture(10)
  X.explode(
    g,
    { action = require('src.content.abilities'):get('powder').action, x = 16, y = 1, z = 21 }
  )
  other, target = fixture(10)
  target.leapY = 5
  X.explode(
    other,
    { action = require('src.content.abilities'):get('powder').action, x = 16, y = 1, z = 21 }
  )
  check(
    'a physical leap lifts the blast anchor outside the same explosion',
    e.hp < 1000 and target.hp == 1000 and other.explosionReport.targets == 0
  )
  other, target = fixture(10)
  target.leapY = 1
  X.explode(
    other,
    { action = require('src.content.abilities'):get('powder').action, x = 16, y = 1, z = 21 }
  )
  check(
    'partial leap height uses three-dimensional falloff rather than ground distance',
    target.hp > e.hp and target.hp < 1000
  )
  return lines
end
return Tests
