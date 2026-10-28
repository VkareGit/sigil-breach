-- 0.21 challenge as physics and data: wave tiers, walking acceleration, the
-- thrall's leap, predictive aim, evasion and hyperarmour. Telegraphs never
-- shorten and every demon stays slower than the player.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, check)
  local A = require('src.content.enemies')
  local Rules = require('src.combat.rules')
  local Attacks = require('src.enemies.actions')
  local AI = require('src.enemies.ai')
  local T = require('src.content.tuning')
  local D = A.defaults
  local near = Fixtures.within(1e-6)
  local function fresh(tier)
    local g = Fixtures.arena(G)
    g.tier = tier
    return g
  end
  -- Tiers.
  local g = fresh(1)
  local base = g:spawn('imp', 16, 20)
  g = fresh(3)
  local t3 = g:spawn('imp', 16, 20)
  check(
    'tier 1 is the calibrated archetype; tier 3 is faster, tougher and more aggressive',
    base.maxHp == A.imp.body.hp
      and base.tierSpeed == 1
      and t3.maxHp > base.maxHp
      and near(t3.tierSpeed, 1 + 2 * D.tiers.speed)
      and t3.tierPace > 1
      and Rules.maxAttackers(t3) == 3
      and Rules.maxAttackers(base) == 2
  )
  local claw = A.imp.attacks[1].packet
  check(
    'tier damage scales a cached copy of the packet, never the shared data',
    Rules.packet(base, claw) == claw
      and near(Rules.packet(t3, claw).base, claw.base * (1 + 2 * D.tiers.damage))
      and Rules.packet(t3, claw) == Rules.packet(t3, claw)
      and claw.base == 20
  )
  local ok = true
  for _, id in ipairs({ 'imp', 'armored', 'stolas', 'buer', 'boss', 'furfur' }) do
    local top = A[id].move.speed * (1 + 4 * D.tiers.speed)
    ok = ok and top < T.moveSpeed
  end
  check('every demon at the highest tier is still slower than the player', ok)
  -- Skill choice: claw close, leap at mid range, nothing in the gap or at rest.
  g = fresh(1)
  local imp = g:spawn('imp', 16, 20)
  check(
    'the thrall claws close, leaps at mid range and waits in between',
    Attacks.choose(imp, 1.5, 0).id == 'claw'
      and Attacks.choose(imp, 5, 0).id == 'leap'
      and Attacks.choose(imp, 2.3, 0) == nil
  )
  imp.restUntil = { leap = 10 }
  check('a skill on its own cooldown is not chosen', Attacks.choose(imp, 5, 1) == nil)
  -- The leap: ballistic flight under world gravity onto the committed point.
  local function leap(dodge)
    local t = fresh(1)
    local e = t:spawn('imp', 16, 20)
    local p = t.player
    p.armor = 0
    e.awake, e.visible, e.spawnAge = true, true, 1
    Attacks.begin(t, e, 5, A.imp.attacks[2])
    local aimX, aimZ = e.aimX, e.aimZ
    if dodge then
      p.x = p.x + 2
    end
    e.windup = 0
    e.ai, e.phase = 'strike', 0
    Attacks.execute(t, e)
    local flight = 0
    for _ = 1, 240 do
      e.phase = e.phase + 1 / 120
      Attacks.strike(t, e, 1 / 120, p)
      if e.leaping then
        flight = flight + 1 / 120
      end
      if e.ai ~= 'strike' then
        break
      end
    end
    return t, e, aimX, aimZ, flight
  end
  local lg, le, ax, az, flight = leap(false)
  local expected = 2 * math.sqrt(2 * T.gravity * A.imp.attacks[2].height) / T.gravity
  check(
    'a low leap stops at the occupied aim point without overlapping the knight',
    near(le.x, ax, 0.05)
      and near(az - le.z, Rules.playerBody().radius + Rules.radius(le), 0.05)
      and near(flight, expected, 2 / 120)
  )
  check('a player on the landing point is struck', lg.player.hp < 100)
  local dg, de, dx, dz = leap(true)
  check('stepping out of the marked landing point dodges the leap', dg.player.hp == 100)
  check(
    'an unobstructed leap still reaches the committed point',
    near(de.x, dx, 0.05) and near(de.z, dz, 0.05)
  )
  -- The leap predicts where a moving player will be at landing (crouch + flight).
  g = fresh(1)
  local hunter = g:spawn('imp', 16, 20)
  g.player.vx, g.player.vz = 3, 0
  Attacks.begin(g, hunter, 5, A.imp.attacks[2])
  local flightTime = 2 * math.sqrt(2 * T.gravity * A.imp.attacks[2].height) / T.gravity
  check(
    'a tier 1 leap leads a moving player by its share of crouch and flight',
    near(
      hunter.aimX - g.player.x,
      3 * (hunter.windup + flightTime) * A.imp.attacks[2].leadShare,
      1e-6
    )
  ) -- Shot out of the sky: a broken guard in the air falls and lands knocked down.
  g = fresh(1)
  local flyer = g:spawn('imp', 16, 20)
  flyer.awake, flyer.visible = true, true
  Attacks.begin(g, flyer, 5, A.imp.attacks[2])
  flyer.windup, flyer.ai, flyer.phase = 0, 'strike', 0
  Attacks.execute(g, flyer)
  for _ = 1, 12 do
    flyer.phase = flyer.phase + 1 / 120
    Attacks.strike(g, flyer, 1 / 120, g.player)
  end
  local airborne = flyer.leapY and flyer.leapY > 0
  Rules.react(g, flyer, 60, true, nil, 0, { counter = true })
  local landed = false
  for _ = 1, 120 do
    AI.update(g, 1 / 120, g.player)
    if flyer.leapY == nil then
      landed = true
      break
    end
  end
  check(
    'a thrall shot out of its leap falls and lands knocked down',
    airborne and flyer.ai == 'hurt' and landed and flyer.stun > 0.2
  )
  -- Predictive aim exists at tier one, with unchanged readable windups.
  local function aim(tier)
    local t = fresh(tier)
    local s = t:spawn('stolas', 16, 17)
    t.player.vx, t.player.vz = 2, 0
    Attacks.begin(t, s, 8, A.stolas.attacks[1])
    return s.aimX - t.player.x, s.windupDuration
  end
  local lead1, windup1 = aim(1)
  local lead3, windup3 = aim(3)
  check(
    'acolytes lead observed movement at both tier one and tier three',
    lead1 > 1.5 and lead3 >= lead1
  )
  check('tiers never shorten a telegraph', near(windup1, windup3))
  -- Evasion: an aimed-at acolyte sidesteps once, then waits even at tier one.
  local function aimedAt(tier)
    local t = fresh(tier)
    local s = t:spawn('stolas', 16, 17)
    s.awake, s.visible, s.memory, s.attack, s.spawnAge = true, true, 5, 99, 1
    t.player.yaw = math.atan2(s.x - t.player.x, s.z - t.player.z)
    local x = s.x
    for _ = 1, 30 do
      AI.update(t, 1 / 120, t.player)
    end
    return math.abs(s.x - x), s.evades or 0
  end
  local moved1, ev1 = aimedAt(1)
  local moved2, ev2 = aimedAt(2)
  check(
    'acolytes sidestep out of the aim line once per cooldown, including tier one',
    ev1 == 1 and ev2 == 1 and moved1 > 1.0 and moved2 > 1.0
  )
  -- Hyperarmour: the iron thrall's guard doubles while it attacks.
  g = fresh(1)
  local iron, steady = g:spawn('armored', 14, 20), g:spawn('armored', 18, 20)
  iron.ai, iron.attackSpec = 'windup', A.armored.attacks[1]
  steady.ai = 'move'
  check(
    'an attacking iron thrall shrugs off a blow that staggers it at rest',
    not Rules.guard(iron, 50) and Rules.guard(steady, 50)
  )
  -- Walking acceleration: from rest, heavier bodies need longer.
  local function start(kind)
    local t = fresh(1)
    local e = t:spawn(kind, 16, 10)
    e.awake, e.visible, e.memory, e.attack, e.spawnAge = true, true, 5, 99, 1
    t.player.x, t.player.z = 16, 27
    for _ = 1, 6 do
      AI.update(t, 1 / 120, t.player)
    end
    return e.walkSpeed or 0
  end
  local light, heavy = start('imp'), start('armored')
  check(
    'demons accelerate into their stride; the heavier iron thrall later',
    light > 0.3
      and light < A.imp.move.speed * 0.6
      and heavy / A.armored.move.speed < light / A.imp.move.speed
  )
  -- Trip: a leg blow on a rushing body takes its legs away.
  g = fresh(1)
  local runner, walker = g:spawn('imp', 14, 20), g:spawn('imp', 18, 20)
  runner.hp, walker.hp = 5000, 5000
  runner.ai, runner.attackSpec, runner.phase = 'strike', A.imp.attacks[1], 0.05
  -- 0.24: rushing means the attack is moving the body (its rush velocity).
  runner.rushVX, runner.rushVZ = 0, A.imp.attacks[1].lungeSpeed
  walker.ai = 'move'
  local tripped = Rules.react(g, runner, 20, false, nil, 0, { lower = 50 })
  local walking = Rules.react(g, walker, 20, false, nil, 0, { lower = 50 })
  check(
    'a leg shot trips a lunging thrall (knocked down), not a walking one',
    tripped.tripped and runner.ai == 'hurt' and runner.stun >= D.knockdown and not walking.tripped
  )
  local furfur = g:spawn('furfur', 16, 14)
  furfur.ai, furfur.attackSpec, furfur.phase, furfur.chargeTime =
    'strike', A.furfur.attacks[2], 0.2, 0.8
  furfur.rushVX, furfur.rushVZ = 0, A.furfur.attacks[2].speed
  local stopped = Rules.react(g, furfur, 20, false, nil, 0, { lower = 60 })
  check(
    "a leg shot stops a boss's charge short without cancelling its guard rules",
    stopped.tripped
      and furfur.chargeTime <= 0.2
      and furfur.stun >= D.knockdown / A.furfur.body.stability - 1e-9
  )
  -- A counter that breaks the guard knocks down; a major wound holds the body.
  local leaper = g:spawn('imp', 12, 18)
  leaper.hp = 5000
  Rules.guard(leaper, 30, { counter = true })
  check(
    'a guard-breaking counter knocks the body down',
    leaper.stun >= D.knockdown and leaper.knockedDown
  )
  local hurt = g:spawn('imp', 20, 18)
  local hp0 = hurt.hp
  g:damageEnemy(hurt, 60, 'test')
  local wounded = Rules.react(g, hurt, 10, false, nil, hp0 - hurt.hp)
  check(
    'a major wound holds the struck body a beat (victim hit-stop)',
    wounded.wounded and hurt.hitPause >= D.woundPause
  )
end
return Tests
