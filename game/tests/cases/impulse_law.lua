-- 0.20 one law of impulse and guard for every body (src/combat/rules.lua):
-- the formula decides, never the weapon's name.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, check)
  local A = setmetatable(require('tests.support.v033_encounters').content(), {
    __index = require('src.content.enemies'),
  })
  local Rules = require('src.combat.rules')
  local Damage = require('src.combat.damage')
  local Weapons = require('src.content.weapons')
  local X = require('src.combat.explosives')
  local T = require('src.content.tuning')
  local D = A.defaults
  local near = Fixtures.within(1e-6)
  local function fresh()
    return Fixtures.arena(G)
  end
  local function speed(e)
    return math.sqrt((e.pushX or 0) ^ 2 + (e.pushZ or 0) ^ 2)
  end
  -- One saturating impulse law; 20 pellets still throw harder than 9.
  local v44, v108, v240 = Rules.shove(44, 1), Rules.shove(108, 1), Rules.shove(240, 1)
  check(
    'impulse law saturates softly: more impulse always throws further, never past vmax',
    v44 < v108 and v108 < v240 and v240 < D.impulse.vmax and v108 / v240 < 0.8
  )
  check(
    'the same impulse moves a twice heavier body half as fast',
    near(Rules.shove(120, 2), Rules.shove(120, 1) / 2)
  )
  local g = fresh()
  local thrown9, thrown20 = g:spawn('imp', 16, 21), g:spawn('imp', 18, 21)
  thrown9.hp, thrown20.hp = 5000, 5000
  Rules.react(g, thrown9, 108, true, nil, 0)
  Rules.react(g, thrown20, 240, true, nil, 0)
  check(
    'a point-blank volley throws harder than nine pellets',
    speed(thrown20) > speed(thrown9) * 1.2
  )
  -- The player obeys the same law with the knight's mass.
  g = fresh()
  local p = g.player
  p.armor = 0
  g:damagePlayer(28, 16, 23, { base = 28, impact = 160 })
  check(
    'the player is shoved by the same impulse law as every demon',
    near(
      math.abs(p.pushZ),
      Rules.shove(160, require('src.content.characters').standard().body.mass),
      1e-6
    )
  )
  -- The Judge breaks a guard more than it throws a body (push 25, impact 44).
  local judge = Weapons.attack(g, 2)
  local imp = { armorRating = 0, zones = D.zones }
  local _, _, guardHit, pushHit = Damage.resolve(judge, imp, 5, 'torso')
  check(
    'the Judge separates guard damage from physical push',
    near(guardHit, 44) and near(pushHit, 25)
  )
  -- 0.24 balance tiers: a light falter below twice the guard, a heavy stagger
  -- above it; every balance time divided by the body's stability.
  local S = D.stagger
  local t36, heavy36 = Rules.staggerTime(36, 36)
  local t71 = Rules.staggerTime(71, 36)
  local t72, heavy72 = Rules.staggerTime(72, 36)
  check(
    'a barely broken guard falters briefly, a crushed one staggers longest',
    near(t36, S.light.base)
      and not heavy36
      and Rules.staggerTime(44, 36) < t71
      and heavy72
      and t72 > t71 + 0.05
      and near(Rules.staggerTime(240, 36), S.heavy.max)
  )
  check(
    'the same overshoot staggers a heavier body shorter (stability sqrt(mass))',
    near(Rules.staggerTime(80, 36, A.armored.body), Rules.staggerTime(80, 36) / math.sqrt(1.4))
      and near(Rules.stability(g:spawn('boss', 10, 10)), A.boss.body.stability)
  )
  g = fresh()
  local light = g:spawn('imp', 16, 21)
  light.hp = 5000
  Rules.react(g, light, 44, false, nil, 0)
  check(
    'a revolver blow staggers the thrall by its overshoot, not by a weapon flag',
    near(light.stun, Rules.staggerTime(44, 36)) and Rules.has(light, 'staggered')
  )
  -- Guard recovery: nothing during the delay, then a share of the guard per second.
  local guard = g:spawn('buer', 18, 21)
  guard.poise, guard.guardQuiet = 30, 0
  Rules.recover(guard, 1.0, A.buer.body)
  local held = guard.poise
  Rules.recover(guard, 0.7, A.buer.body)
  check(
    'guard does not recover during the delay, then at regenRate of the guard',
    near(held, 30) and near(guard.poise, 30 - D.regenRate * A.buer.body.poise * 0.5, 1e-6)
  )
  -- Bosses falter: the attack is delayed, not cancelled; armour is exposed.
  g = fresh()
  local boss = g:spawn('furfur', 16, 20)
  boss.ai, boss.windup, boss.windupDuration = 'windup', 0.5, 0.9
  local before = Damage.resolve({ base = 100 }, boss, 1)
  Rules.react(g, boss, 450, true, nil, 0)
  local after = Damage.resolve({ base = 100 }, boss, 1)
  check(
    'a broken boss guard falters without cancelling the committed attack',
    boss.stun >= S.light.base / A.furfur.body.stability - 1e-9
      and boss.ai == 'windup'
      and boss.windup == 0.5
      and boss.staggerLock == D.bossLock
  )
  check(
    'a faltering boss is exposed: half armour for a while',
    Rules.has(boss, 'exposed') and after > before
  )
  -- Hit zones: legs take less wound, more guard, the same push; and cripple.
  local torso = { Damage.resolve(Weapons.attack(g, 1), imp, 3, 'torso') }
  local legs = { Damage.resolve(Weapons.attack(g, 1), imp, 3, 'lower') }
  check(
    'a leg hit wounds less, unbalances more and pushes the same',
    near(legs[1], torso[1] * 0.8) and near(legs[3], torso[3] * 1.35) and near(legs[4], torso[4])
  )
  g = fresh()
  local limp = g:spawn('imp', 16, 21)
  limp.hp = 5000
  Rules.react(g, limp, 20, true, nil, 0, { lower = 20 })
  check(
    'a strong leg blow cripples the body',
    Rules.has(limp, 'crippled') and Rules.speedScale(limp) < 0.7
  )
  -- Counter-hit: a blow meeting the body's own lunge counts x1.5 on the guard.
  local plain, countered = g:spawn('imp', 14, 21), g:spawn('imp', 18, 21)
  check(
    'a counter-hit breaks a guard that the same blow alone would not',
    not Rules.guard(plain, 30) and Rules.guard(countered, 30, { counter = true })
  )
  -- Domino: a body thrown into another faster than the slam speed hurts it.
  g = fresh()
  local thrown, struck = g:spawn('imp', 14, 21), g:spawn('imp', 14.6, 21)
  thrown.pushX, thrown.pushZ = 9, 0
  local hp = struck.hp
  check(
    'a thrown body hurts the body it strikes (domino)',
    Rules.collide(g, thrown, struck) and struck.hp < hp
  )
  -- Iron Thrall: armour stops the wound of a Judge body shot, not of a head shot.
  local iron = { armorRating = 60, zones = D.zones }
  local body, headShot =
    Damage.resolve(judge, iron, 8, 'torso'), Damage.resolve(judge, iron, 8, 'head')
  local woundAt = A.armored.body.woundAt * A.armored.body.hp
  check(
    'the Iron Thrall is wounded by a Judge head shot, never by a body shot (clear margin)',
    body < woundAt - 5 and headShot >= woundAt
  )
  -- One world gravity: the powder charge falls like everything else.
  g = fresh()
  g.player.abilityState.powder.uses = 1
  g.run = nil
  g:cast(1)
  local c = g.charges[1]
  check(
    'the powder charge uses world gravity with a throw scaled to keep its reach',
    c
      and near(
        math.sqrt(c.vx ^ 2 + c.vz ^ 2 + (c.vy - 2.2 * math.sqrt(T.gravity / 12)) ^ 2),
        8 * math.sqrt(T.gravity / 12),
        1e-6
      )
  )
  -- Directional influence: steering against a shove brakes it faster.
  local function shoved(input)
    local t = fresh()
    t.player.pushX, t.player.pushZ = 0, 4
    for _ = 1, 12 do
      t:update(1 / 120, input)
    end
    return t.player.pushZ
  end
  check(
    'steering against a shove brakes it faster (DI)',
    shoved({ forward = 1 }) < shoved({}) * 0.97
  )
  -- 0.20 visibility: the rules show themselves.
  local Anim = require('src.enemies.animation')
  local Weight = require('src.feedback.weight')
  local function lunge(crippledFor)
    local t = fresh()
    local e = t:spawn('imp', 16, 15)
    e.awake, e.visible = true, true
    if crippledFor then
      Rules.addCondition(e, 'crippled', crippledFor)
    end
    e.ai, e.phase, e.attackKind, e.aimX, e.aimZ = 'strike', 0, 'claw', 16, 25
    e.attackSpec, e.lungeX, e.lungeZ, e.attackCount = A.imp.attacks[1], 0, 1, 1
    local z = e.z
    for _ = 1, 24 do
      e.phase = e.phase + 1 / 120
      require('src.enemies.actions').strike(t, e, 1 / 120, t.player)
    end
    return e.z - z
  end
  check('a crippled thrall lunges shorter', lunge(5) < lunge(nil) * 0.8 and lunge(nil) > 0.5)
  g = fresh()
  boss = g:spawn('boss', 16, 20)
  Rules.react(g, boss, A.boss.body.poise + 100, true, nil, 0)
  local falterFrame = Anim.pose(g, boss)
  check('a faltering boss starts its painted exhaustion', falterFrame == 24 and boss.stun > 0)
  g = fresh()
  Weight.confirm(g, { kills = 0, headHits = 0 }, { { counter = true, staggered = true } })
  local counterText = g.view.feedback
  Weight.confirm(g, { kills = 0, headHits = 0 }, { { falter = true, staggered = true } })
  check(
    'counter-hits and boss falters are named on screen',
    counterText == 'COUNTER' and g.view.feedback == 'FALTER  /  EXPOSED'
  )
  g = fresh()
  g.player.armor = 0
  g:damagePlayer(28, 16, 23, { base = 28, impact = 160 })
  for _ = 1, 12 do
    g:update(1 / 120, {})
  end
  check('a broken player guard drops the gun out of the aim', (g.view.weaponLower or 0) > 5)
  -- 0.20 durability: the glass-cannon acolyte dies to a Judge head shot only.
  local acolyte = { armorRating = 0, zones = D.zones }
  check(
    'the Star Acolyte falls to one Judge head shot but not to a body shot',
    Damage.resolve(judge, acolyte, 8, 'head') >= A.stolas.body.hp
      and Damage.resolve(judge, acolyte, 8, 'torso') < A.stolas.body.hp
  )
  -- 0.24 momentum adds on every body, but never past the single-blow ceiling.
  local body = { pushX = 0, pushZ = 0 }
  Rules.addPush(body, 1, 0, 2, 1)
  Rules.addPush(body, 1, 0, 2, 1)
  check('two blows in a row throw twice as fast as one', near(body.pushX, 4))
  for _ = 1, 20 do
    Rules.addPush(body, 1, 0, 3, 1)
  end
  check('stacked blows never exceed vmax / mass', near(body.pushX, D.impulse.vmax / 1))
  local knight = require('src.content.characters').standard().body
  check(
    'the knight reads its i-frames, dodge i-frames and drag from its body data',
    require('src.content.characters').standard().body == knight
      and knight.iframes > 0
      and knight.rollIframes > 0
      and knight.drag > knight.airDrag
      and D.drag > knight.drag
  )
end
return Tests
