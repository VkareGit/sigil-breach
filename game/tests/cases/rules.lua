-- The rules of the world (src/combat/rules.lua) and data-defined archetypes.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, check)
  local A = require('src.content.enemies')
  local Rules = require('src.combat.rules')
  local Damage = require('src.combat.damage')
  local AI = require('src.enemies.ai')
  local T = require('src.content.tuning')
  local near = Fixtures.within(1e-6)
  -- Classic arena: no wave director, so a quiet test field never 'finishes'.
  local function fresh()
    return Fixtures.arena(G)
  end
  -- Every archetype is equipped from data, the armoured variant included.
  local g = fresh()
  local ok = true
  for _, id in ipairs({ 'imp', 'armored', 'stolas', 'buer', 'boss', 'furfur' }) do
    local e = g:spawn(id, 16, 20)
    local def = Rules.archetype(e)
    local b = def.body
    ok = ok
      and e.hp == b.hp
      and e.maxHp == b.hp
      and (e.armorRating or 0) == b.armor
      and e.speed == def.move.speed
  end
  check('every creature body, speed and armour come from its archetype data', ok)
  -- A demon that did not exist in code: data alone gives it a body and an attack.
  -- 0.24: through the creature definition (defaults, validation, packets).
  A.wraith = require('src.content.defs.creature').define({
    id = 'wraith',
    kind = 'stolas',
    -- A new creature names its look: the owl's sheet, a pale portal.
    appearance = { atlas = 'stolas', portal = { 0.7, 0.7, 0.8 } },
    name = 'Próbny Upiór',
    souls = 1,
    body = {
      hp = 40,
      immune = { fire = true },
      poise = 20,
      woundAt = 0.5,
      blood = { 0.2, 0.2, 0.2 },
    },
    move = { speed = 2, ideal = 5 },
    attacks = {
      require('src.content.defs.action').bolt({
        id = 'wail',
        range = 12,
        windup = 0.3,
        speed = 6,
        height = 1.3,
        color = { 0.5, 0.5, 0.6 },
        packet = { base = 9, impact = 30, damageType = 'astral' },
      }),
    },
  })
  g = fresh()
  local w = g:spawn('wraith', 16, 20)
  w.awake = true
  w.attack = 0
  w.visible = true
  for _ = 1, 120 do
    g:update(1 / 120, {})
  end
  local bolt = g.bullets[1]
  check(
    'a data-only archetype winds up and fires its own damage packet',
    w.attackKind == 'wail' and bolt ~= nil and bolt.packet == A.wraith.attacks[1].packet
  )
  check(
    'a data-only archetype is immune to its declared damage type',
    Damage.resolve({ base = 50, damageType = 'fire' }, w, 1) == 0
      and Damage.resolve({ base = 50 }, w, 1) > 0
  )
  A.wraith = nil
  -- Immunity keeps the shove; soak and armour per location follow the data.
  local _, _, impulse = Damage.resolve(
    { base = 50, impact = 40, damageType = 'fire' },
    { immune = { fire = true } },
    1
  )
  check('immunity removes the wound but keeps the shove of the blow', near(impulse, 40))
  local plain = Damage.resolve({ base = 12 }, {}, 1)
  local soaked, absorbed = Damage.resolve({ base = 12 }, { soak = 5 }, 1)
  check(
    'flat soak removes the same amount from every hit',
    near(plain - soaked, 5) and near(absorbed, 5)
  )
  local head = Damage.resolve(
    { base = 70 },
    { armorRating = 0, locationArmor = { head = 100 } },
    1,
    'head'
  )
  local body = Damage.resolve(
    { base = 70 },
    { armorRating = 0, locationArmor = { head = 100 } },
    1,
    'torso'
  )
  check('armour per hit location protects only that location', near(head, 35) and near(body, 70))
  local all = true
  for _, id in ipairs({ 'imp', 'stolas', 'buer' }) do
    all = all and (A[id].body.soak or 0) == 0 and A[id].body.locationArmor == nil
  end
  check('current archetypes keep the calibrated 0.13 damage (no soak, one rating)', all)
  check(
    'the iron thrall is open at the legs',
    A.armored.body.locationArmor.lower < A.armored.body.armor
  )
  -- 0.24 boss weak points: the torso keeps the old rating (body shots are
  -- unchanged), the bare skull carries none, the legs carry more.
  local points = true
  for _, id in ipairs({ 'boss', 'furfur' }) do
    local b = A[id].body
    points = points
      and (b.soak or 0) == 0
      and b.locationArmor.torso == b.armor
      and b.locationArmor.head == 0
      and b.locationArmor.lower > b.armor
  end
  check('bosses have a bare-skull weak point and keep their body rating', points)
  -- Major wound: one hit removing a large share of the body breaks the guard.
  g = fresh()
  local e = g:spawn('buer', 16, 20)
  e.staggerLock = 5
  e.windup = 0.5
  e.ai = 'windup'
  local hp = e.hp
  g:damageEnemy(e, 60, 'test')
  Rules.react(g, e, 10, false, { e.x, 1.2, e.z }, hp - e.hp)
  check(
    'a major wound breaks the guard even under a stagger lock',
    Rules.has(e, 'wounded') and e.stun >= 0.55 and e.ai == 'hurt' and e.windup == 0
  )
  check('a wounded creature moves slower', Rules.speedScale(e) < 1)
  g = fresh()
  local boss = g:spawn('boss', 16, 20)
  boss.windup = 0.5
  boss.ai = 'windup'
  hp = boss.hp
  g:damageEnemy(boss, 300, 'test')
  Rules.react(g, boss, 10, false, { boss.x, 1.2, boss.z }, hp - boss.hp)
  check(
    'a boss cannot be broken by one wound',
    not Rules.has(boss, 'wounded') and boss.ai == 'windup'
  )
  -- The player obeys the same rules.
  g = fresh()
  local p = g.player
  p.armor = 0
  g:damagePlayer(28, 16, 23, { base = 28, impact = 160 })
  check(
    'a heavy blow shoves and staggers the player',
    Rules.has(p, 'staggered') and (p.pushZ or 0) > 1 and near(p.hp, 72)
  )
  check(
    'a stagger flashes the frame and shakes harder than a plain hit',
    (g.view.staggerFlash or 0) > 0 and g.view.shake >= 0.16
  )
  local slow = Rules.speedScale(p)
  for _ = 1, 60 do
    g:update(1 / 120, {})
  end
  local claw = A.imp.attacks[1].packet
  local q = fresh().player
  q.armor = 0
  local g2 = fresh()
  q = g2.player
  q.armor = 0
  g2:damagePlayer(claw.base, 16, 23, claw)
  check(
    'one light claw shoves but does not stagger the player',
    not Rules.has(q, 'staggered') and (q.pushZ or 0) > 0
  )
  q.invuln = 0
  g2:damagePlayer(claw.base, 16, 23, claw)
  check('a second quick claw breaks the player guard', Rules.has(q, 'staggered'))
  check(
    'the player stagger slows movement and then wears off',
    slow < 1 and not Rules.has(p, 'staggered')
  )
  g = fresh()
  p = g.player
  p.armor = 0
  p.resist = { astral = 0.5 }
  g:damagePlayer(20, 16, 23, { base = 20, impact = 0, damageType = 'astral' })
  check('player resistance uses the same damage type rule', near(p.hp, 90))
  g = fresh()
  p = g.player
  p.armor = 0
  g:damagePlayer(15, 16, 23)
  check(
    'legacy numeric damage still works without a packet and without shove',
    near(p.hp, 85) and (p.pushZ or 0) == 0
  )
  -- Plague pools poison the guard: conditions are shared state with durations.
  g = fresh()
  p = g.player
  p.armor = 100
  AI.hazard(g, p.x, p.z, 0, 1.5, 2, A.buer.attacks[1].pool)
  p.dash = 0
  for _ = 1, 24 do
    g:update(1 / 120, {})
  end
  local poisonedDash = p.dash
  local poisoned = Rules.has(p, 'poisoned')
  check('a plague pool applies the poisoned condition', poisoned)
  -- The pool's first pulse lands after this tick's recovery; every later tick is halved.
  check(
    'poison halves the dash recovery',
    near(
      poisonedDash,
      (1 + 23 * 0.5) / 120 * require('src.content.characters').standard().movement.dashRecharge,
      1e-3
    )
  )
  -- Shotgun calibration is unchanged by the refactor (0.13 measurement at 8 m).
  check(
    'archetype data keeps the imp, armoured and boss masses of 0.13',
    A.imp.body.mass == 1 and A.armored.body.mass == 1.4 and near(A.boss.body.mass, 1 / 0.12)
  )
end
return Tests
