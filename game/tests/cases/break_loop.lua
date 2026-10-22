-- Plan v5 G5: break it, then finish it. A demon whose guard broke, that fell
-- or took a major wound within the break-kill window heals the knight when
-- it dies, even after it found its feet; later it does not. A round passing
-- a bare skull loses no power to armour.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G)
  local lines = {}
  local check = Fixtures.checker(lines, 'break loop: ', 'break loop: ')
  local Field = require('src.run.test_field')
  local Rules = require('src.combat.rules')
  local Defaults = require('src.content.combat_defaults')
  local Damage = require('src.combat.damage')
  local function field()
    local g = Field.new(G)
    g.testing = true
    Field.close(g)
    g.player.hp = 50
    return g
  end
  local function kill(g, e)
    g:damageEnemy(e, e.hp + 1, 'weapon')
  end
  local window = Defaults.breakKill.window
  local function broken(after)
    local g = field()
    local e = g:spawn('imp', 16, 20)
    e.spawnAge = 1
    Rules.guard(e, Rules.body(e).poise * 3)
    e.stun, e.conditions.staggered = 0, nil
    e.spawnAge = 1 + after
    kill(g, e)
    return g.player.hp > 50
  end
  check(
    'a demon broken within the window heals the knight when it dies on its feet',
    broken(window - 0.1)
  )
  check('a demon broken longer ago does not', not broken(window + 0.1))

  -- A bare skull costs a round no power; armour does.
  local g = field()
  local boss = g:spawn('boss', 16, 20)
  check(
    "a round through the Margrave's skull meets no armour, through his torso it does",
    Damage.rating(boss, 'head') == 0 and Damage.rating(boss, 'torso') > 0
  )
  return lines
end
return Tests
