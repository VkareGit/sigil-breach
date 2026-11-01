-- 0.22 proving-ground stations: range, physics and wave trial use the real
-- combat, the real spawner and real demons of the chosen tier.
local Tests = {}
function Tests.run(G, check)
  local Field = require('src.run.test_field')
  local W = require('src.world.arena')
  local function field()
    local g = Field.new(G)
    g.ephemeral = true
    return g
  end
  local function tick(g, seconds)
    for _ = 1, math.floor(seconds * 120 + 0.5) do
      g:update(1 / 120, {})
    end
  end
  -- Range: five dummies at measured distances, all in sight, inert, healing.
  local g = field()
  Field.range(g)
  local p = g.player
  local ok, inSight = #g.testField.posts == 5, true
  for i, entry in ipairs(g.testField.posts) do
    local d = math.sqrt((entry.x - p.x) ^ 2 + (entry.z - p.z) ^ 2)
    ok = ok
      and math.abs(d - ({ 4, 8, 12, 16, 20 })[i]) < 1e-6
      and not W.solid(g.world, entry.x, entry.z, 0.3)
    inSight = inSight and W.visible(g.world, p.x, p.z, entry.x, entry.z)
  end
  check('the range stands five dummies at 4, 8, 12, 16 and 20 m', ok and g.state == 'playing')
  check('every range dummy is in sight of the firing line', inSight)
  local dummy = g.testField.posts[1].enemy
  local x, z = dummy.x, dummy.z
  tick(g, 2)
  check(
    'range dummies neither walk nor attack',
    dummy.x == x and dummy.z == z and dummy.ai ~= 'windup' and g.player.hp == 100
  )
  g:damageEnemy(dummy, 30, 'weapon')
  local hurt = dummy.hp < dummy.maxHp
  tick(g, 1 / 120)
  check(
    'a range dummy shows the blow, then heals for the next shot',
    hurt and dummy.hp == dummy.maxHp
  )
  g:damageEnemy(dummy, dummy.maxHp * 3, 'weapon')
  tick(g, 1.6)
  local raised = g.testField.posts[1].enemy
  check(
    'a killed dummy stands up again at its post',
    raised ~= dummy and raised.hp > 0 and raised.dummy
  )
  -- Physics: a domino row, a wall-slam dummy and one live thrall.
  g = field()
  Field.physics(g)
  local live, dummies = 0, 0
  for _, e in ipairs(g.enemies) do
    if e.dummy then
      dummies = dummies + 1
    elseif e.hp > 0 then
      live = live + 1
    end
  end
  check(
    'the physics station sets a domino row, a wall dummy and one live thrall',
    dummies == 4 and live == 1
  )
  g.player.weapon = 1
  g.player.yaw = math.pi
  for _, e in ipairs(g.enemies) do
    if not e.dummy then
      e.hp = 0
    end
  end
  g:shoot()
  tick(g, 0.4)
  check('a volley into the domino row drives bodies into each other', (g.collisions or 0) > 0)
  -- Portals (0.22): the telegraph clock, the colour of what comes, the arrival.
  local Portals = require('src.render.portals')
  local Anim = require('src.enemies.animation')
  check(
    'a portal telegraph runs from opening to arrival and names its demon by colour',
    Portals.progress({ delay = 1.2, maxDelay = 1.2 }) == 0
      and Portals.progress({ delay = 0, maxDelay = 1.2 }) == 1
      and Portals.color('stolas') ~= Portals.color('imp')
      and Portals.color('armored') ~= Portals.color('imp')
  )
  g = field()
  Field.close(g)
  local arrived = g:spawn('imp', 16, 22)
  arrived.spawnAge = 0.1
  local _, sunk = Anim.pose(g, arrived)
  arrived.spawnAge = 1
  local _, standing = Anim.pose(g, arrived)
  check('a demon climbs out of the floor as it arrives', sunk < -0.5 and standing == 0)
end
return Tests
