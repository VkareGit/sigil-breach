-- 0.24 counter-hits as a momentum collision and balance tiers by stability
-- (src/combat/rules.lua: R.guard, R.meetRush, R.staggerTime, R.knockDown).
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, check)
  local A = require('src.content.enemies')
  local Rules = require('src.combat.rules')
  local D = A.defaults
  local C = D.counter
  local near = Fixtures.within(1e-6)
  local function fresh()
    return Fixtures.arena(G)
  end
  -- A body rushing straight at the player (who stands at z = 25).
  local function rusher(g, kind, attack, speed)
    local e = g:spawn(kind, 16, 21)
    e.hp = 5000
    e.ai, e.attackSpec, e.attackKind, e.phase = 'strike', attack, attack.id, 0.05
    e.lungeX, e.lungeZ, e.rushScale = 0, 1, 1
    e.rushVX, e.rushVZ = 0, speed
    return e
  end
  local claw = A.imp.attacks[1]
  -- The body's momentum joins the guard damage: impact + k * m * u (capped).
  local g = fresh()
  local lunging = rusher(g, 'imp', claw, claw.lungeSpeed)
  local standing = g:spawn('imp', 12, 21)
  standing.hp = 5000
  local hit = Rules.react(g, lunging, 10, false, nil, 0, { push = 0 })
  Rules.react(g, standing, 10, false, nil, 0, { push = 0 })
  local momentum = math.min(C.cap * 36, C.guardPerMomentum * 1 * claw.lungeSpeed)
  check(
    'a blow into a lunge adds the body momentum to the guard damage',
    hit.counter and near(lunging.poise, 10 + momentum) and near(standing.poise, 10)
  )
  -- A blow from the side of a rush is no counter: no closing speed.
  g = fresh()
  local passing = rusher(g, 'imp', claw, 0)
  passing.rushVX, passing.rushVZ = claw.lungeSpeed, 0
  local side = Rules.react(g, passing, 10, false, nil, 0, { push = 0 })
  check(
    'a rush crossing the line of fire is not a counter',
    not side.counter and near(passing.poise, 10)
  )
  -- Velocities add as vectors: a Judge round slows a lunge, it does not stop it.
  g = fresh()
  local slowed = rusher(g, 'imp', claw, claw.lungeSpeed)
  local result = Rules.react(g, slowed, 10, false, nil, 0, { push = 25 })
  check(
    'a light round slows a lunge by exactly its shove',
    not result.stopped
      and near(slowed.rushScale, (claw.lungeSpeed - Rules.shove(25, 1)) / claw.lungeSpeed)
  )
  -- A blow stronger than the rush reverses it: the rush stops, the body falls.
  g = fresh()
  local limping = rusher(g, 'imp', claw, 2)
  local reversed = Rules.react(g, limping, 10, false, nil, 0, { push = 240 })
  check(
    'a blow that reverses a rush stops it and knocks the body down, thrown back',
    reversed.stopped
      and limping.ai == 'hurt'
      and limping.knockedDown
      and near(limping.stun, D.knockdown)
      and limping.pushZ < 0
      and near(limping.pushZ, 2 - Rules.shove(240, 1))
  )
  -- Heavier rushes carry more momentum: a Judge round breaks the iron
  -- thrall's hyperarmour during its shoulder charge, not during its windup.
  g = fresh()
  local shoulder = A.armored.attacks[2]
  local charging = rusher(g, 'armored', shoulder, shoulder.speed)
  local winding = g:spawn('armored', 12, 21)
  winding.hp, winding.ai, winding.attackSpec = 5000, 'windup', shoulder
  local broke = Rules.react(g, charging, 44, false, nil, 0, { push = 25 })
  local held = Rules.react(g, winding, 44, false, nil, 0, { push = 25 })
  check(
    'a round into a charging iron thrall breaks its hyperarmour; in its windup it does not',
    broke.staggered and broke.counter and not held.staggered and charging.knockedDown
  )
  -- A leap flies on with the vector sum: shot in the face, it lands shorter.
  g = fresh()
  local leap = A.imp.attacks[2]
  local flyer = rusher(g, 'imp', leap, 0)
  flyer.rushVX, flyer.rushVZ = nil, nil
  flyer.leaping, flyer.leapY, flyer.leapVY, flyer.leapVX, flyer.leapVZ = true, 0.5, 1, 0, 8
  Rules.react(g, flyer, 10, false, nil, 0, { push = 108 })
  check(
    'a leaping body adds the shove to its flight velocity',
    near(flyer.leapVZ, 8 - Rules.shove(108, 1)) and near(flyer.leapVX, 0) and near(flyer.leapVY, 1)
  )
  -- Balance tiers: braced feet keep part of a light falter's shove.
  g = fresh()
  local light, heavy = g:spawn('imp', 14, 21), g:spawn('imp', 18, 21)
  light.hp, heavy.hp = 5000, 5000
  local l = Rules.react(g, light, 40, false, nil, 0)
  local h = Rules.react(g, heavy, 80, false, nil, 0)
  check(
    'a light falter is braced (part of the shove), a heavy stagger takes it all',
    l.staggered
      and not l.heavy
      and h.heavy
      and near(math.sqrt(light.pushX ^ 2 + light.pushZ ^ 2), Rules.shove(40, 1) * D.brace)
      and near(math.sqrt(heavy.pushX ^ 2 + heavy.pushZ ^ 2), Rules.shove(80, 1))
      and heavy.stun > light.stun
  )
  -- The knight is always moved by a blow (its brace is 1): feedback first.
  check('the knight does not brace against blows', A.player.body.brace == 1)
  -- Knockdown is divided by stability: bosses regain their feet sooner.
  g = fresh()
  local boss = g:spawn('furfur', 16, 14)
  local imp = g:spawn('imp', 12, 14)
  check(
    'a knockdown lasts knockdown / stability on every body',
    near(Rules.knockDown(imp), D.knockdown)
      and near(Rules.knockDown(boss), D.knockdown / A.furfur.body.stability)
  )
  -- Continuity of the tiers: a heavy stagger never lasts less than a light one.
  local s = D.stagger
  check(
    'the heavy tier starts where the light tier ends or above',
    s.heavy.base >= s.light.base + s.light.gain * s.heavy.from and s.heavy.max >= s.heavy.base
  )
end
return Tests
