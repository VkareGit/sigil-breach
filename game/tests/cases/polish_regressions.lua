-- 0.24 review regressions: each check names a defect found in the full review.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, check)
  local A = require('src.content.enemies')
  local Rules = require('src.combat.rules')
  local Damage = require('src.combat.damage')
  local Telemetry = require('src.combat.telemetry')
  local D = A.defaults
  local near = Fixtures.within(1e-6)
  local function fresh()
    return Fixtures.arena(G)
  end
  -- The guard takes nothing during its lock (no pile-up into a heavy stagger).
  local g = fresh()
  local e = g:spawn('imp', 16, 21)
  e.hp = 5000
  Rules.guard(e, 40)
  local locked = e.staggerLock > 0
  Rules.guard(e, 30)
  Rules.guard(e, 30)
  check('blows during the stagger lock do not pile up on the guard', locked and near(e.poise, 0))
  -- Invalid attack data never crashes a shot: always four results.
  local a, b, c, d = Damage.core({ base = 0 / 0 }, {}, 1)
  check('invalid attack data resolves to four zeros', a == 0 and b == 0 and c == 0 and d == 0)
  -- A rush broken by the same blow carries its momentum as a shove.
  g = fresh()
  local runner = g:spawn('imp', 16, 21)
  runner.hp = 5000
  runner.ai, runner.attackSpec, runner.phase = 'strike', A.imp.attacks[1], 0.05
  runner.lungeX, runner.lungeZ, runner.rushScale = 0, 1, 1
  runner.rushVX, runner.rushVZ = 0, A.imp.attacks[1].lungeSpeed
  Rules.react(g, runner, 60, false, nil, 0, { push = 25 })
  check(
    'a broken lunge keeps its momentum up to the shared shove ceiling',
    runner.ai == 'hurt'
      and near(
        runner.pushZ,
        math.min(A.defaults.impulse.vmax, A.imp.attacks[1].lungeSpeed - Rules.shove(25, 1))
      )
      and runner.knockedDown
  )
  -- The knight's own powder charge is never a perfect dodge.
  g = fresh()
  local p = g.player
  g:dash(1, 0)
  local charges = p.dash
  g:damagePlayer(20, p.x + 1, p.z, { base = 20, impact = 100, damageType = 'physical' }, 'self')
  check(
    'dashing through your own blast earns no perfect dodge',
    near(p.dash, charges) and Telemetry.get(g).perfectDodges == 0
  )
  -- A leaper shot out of the air lands knocked down (the painted fall).
  g = fresh()
  local flyer = g:spawn('imp', 16, 20)
  flyer.hp = 5000
  flyer.ai, flyer.stun = 'hurt', 0.1
  flyer.leaping, flyer.leapY, flyer.leapVY, flyer.leapVX, flyer.leapVZ = true, 0.05, -1, 0, 0
  for _ = 1, 12 do
    require('src.enemies.ai').update(g, 1 / 120, g.player)
  end
  check(
    'a body shot out of a leap lands knocked down',
    flyer.leapY == nil and flyer.knockedDown and flyer.stun > 0.2
  )
  -- An interrupted sidestep does not resume after the stagger.
  g = fresh()
  local owl = g:spawn('stolas', 16, 18)
  owl.evadeTime = 0.2
  Rules.interrupt(owl)
  check('a stagger ends a sidestep', owl.evadeTime == 0)
  -- A pickup reports what it really gave, capped by the knight's health.
  g = fresh()
  g.player.hp = A.player.body.hp - 5
  g.pickups = { { x = g.player.x, z = g.player.z, kind = 'health', amount = 25 } }
  require('src.session.interactions').collectSupplies(g)
  check(
    'a health pickup names the health it really restored',
    near(g.player.hp, A.player.body.hp) and g.view.message == '+5 HEALTH'
  )
  -- Resistance bounds are one rule for demons and the knight.
  check(
    'resistances are clamped the same for every body',
    near(Damage.resistance({ fire = 2 }, 'fire'), 0.60)
      and near(Damage.resistance({ fire = -1 }, 'fire'), -0.25)
      and Damage.resistance(nil, 'fire') == 0
  )
  -- The knight's hit volume is one body for claws, bolts and pools.
  check(
    'the knight has one hit volume (radius, height, feet) in its body data',
    A.player.body.radius > 0 and A.player.body.height > 1.5 and A.player.body.feet >= 0
  )
  -- Defaults still describe one stagger lock; bosses lock longer.
  check('a boss guard locks longer than a demon guard', D.bossLock > D.staggerLock)
end
return Tests
