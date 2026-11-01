-- Plan v5 G3: the knight and the demons as bodies. Own motion never walks
-- through or pushes a living body; momentum passes by the masses; demons
-- part by their masses; a route out of sight runs straight where it can.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G)
  local lines = {}
  local check = Fixtures.checker(lines, 'bodies: ', 'bodies: ')
  local Field = require('src.run.test_field')
  local Rules = require('src.combat.rules')
  local Contact = require('src.combat.body_contact')
  local AI = require('src.enemies.ai')
  local knightRadius = require('src.content.characters').standard().body.radius
  local function field()
    local g = Field.new(G)
    g.ephemeral = true
    Field.close(g)
    g.player.x, g.player.z, g.player.yaw, g.player.pitch = 16, 26, math.pi, 0
    return g
  end
  local function gap(g, e)
    local d = math.sqrt((g.player.x - e.x) ^ 2 + (g.player.z - e.z) ^ 2)
    return d - knightRadius - Rules.radius(e)
  end

  -- Walking and dodging into a standing demon stop at the contact.
  local g = field()
  local dummy = g:spawn('imp', 16, 24)
  dummy.dummy = true
  local x0, z0 = dummy.x, dummy.z
  for _ = 1, 240 do
    g:update(1 / 120, { forward = 1 })
  end
  local walked = gap(g, dummy)
  g:update(1 / 120, { forward = 1, dash = true })
  for _ = 1, 30 do
    g:update(1 / 120, { forward = 1 })
  end
  check(
    'the knight cannot walk or dodge through a standing demon, nor push it',
    walked > -1e-6 and gap(g, dummy) > -1e-6 and dummy.x == x0 and dummy.z == z0
  )

  -- Demons pressing on the knight never stand inside him.
  g = field()
  local worst = math.huge
  for i = 1, 3 do
    local e = g:spawn('imp', 14 + i * 1.2, 22)
    e.awake, e.memory, e.spawnAge = true, 60, 1
  end
  for _ = 1, 120 * 30 do
    g:update(1 / 120, {})
    for _, e in ipairs(g.enemies) do
      if e.hp > 0 and not e.leaping then
        worst = math.min(worst, gap(g, e))
      end
    end
  end
  check(
    'thirty seconds of pressing demons leave no body inside the knight (worst gap '
      .. string.format('%.4f', worst)
      .. ' m)',
    worst > -1e-6
  )

  -- A shoved body hands its momentum over by the masses.
  g = field()
  local impRadius = require('src.content.enemies').imp.body.radius
  local e = g:spawn('imp', 16, 26 - knightRadius - impRadius + 0.05)
  e.pushX, e.pushZ = 0, 6
  g.player.pushX, g.player.pushZ = 0, 0
  local mk, me = require('src.content.characters').standard().body.mass, Rules.body(e).mass
  local before = me * e.pushZ + mk * g.player.pushZ
  Contact.demons(g)
  local after = me * e.pushZ + mk * g.player.pushZ
  check(
    'a thrown demon hands the knight its momentum, conserved',
    g.player.pushZ > 0 and math.abs(after - before) < 1e-9 and e.pushZ < 6
  )

  -- Demons part by their masses.
  g = field()
  local light = g:spawn('imp', 16, 20)
  local heavy = g:spawn('armored', 16.3, 20)
  local lx, hx = light.x, heavy.x
  AI.separate(g, 1 / 120)
  local lightMove, heavyMove = math.abs(light.x - lx), math.abs(heavy.x - hx)
  check(
    'the lighter body gives way more when demons part (ratio = mass ratio)',
    heavyMove > 0
      and math.abs(lightMove / heavyMove - Rules.body(heavy).mass / Rules.body(light).mass) < 1e-6
  )

  -- Out of sight, a demon goes round a pillar to the knight and finds him.
  g = field()
  g.player.x, g.player.z = 12, 17.6
  local hunter = g:spawn('imp', 12, 22.6)
  hunter.awake, hunter.memory, hunter.spawnAge, hunter.attack = true, 60, 1, 99
  hunter.lastX, hunter.lastZ = g.player.x, g.player.z
  local found
  for step = 1, 120 * 4 do
    g:update(1 / 120, {})
    if not found and gap(g, hunter) < 1.5 then
      found = step / 120
    end
  end
  check('a demon out of sight walks round a pillar to the knight within 4 s', found ~= nil)
  return lines
end
return Tests
