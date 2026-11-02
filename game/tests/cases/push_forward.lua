-- 0.24 push-forward loop, perfect dodge, pacing director, posture by health,
-- fire, boss weak points and the measurements of real play.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, check)
  local A = setmetatable(require('tests.support.v033_encounters').content(), {
    __index = require('src.content.enemies'),
  })
  local Rules = require('src.combat.rules')
  local Damage = require('src.combat.damage')
  local Telemetry = require('src.combat.telemetry')
  local D = A.defaults
  local near = Fixtures.within(1e-6)
  local function fresh()
    return Fixtures.arena(G)
  end
  -- Break kill: killing a demon off balance heals by a share of its guard.
  local g = fresh()
  g.player.hp = 50
  local broken, steady = g:spawn('imp', 16, 22), g:spawn('imp', 14, 22)
  broken.stun = 0.2
  g:damageEnemy(broken, 500, 'weapon')
  local afterBreak = g.player.hp
  g:damageEnemy(steady, 500, 'weapon')
  check(
    'a demon killed off balance heals the knight; an unbroken one does not',
    near(afterBreak, 50 + D.breakKill.heal * A.imp.body.poise)
      and near(g.player.hp, afterBreak)
      and Telemetry.get(g).breakKills == 1
  )
  -- Perfect dodge: a blow landing during the dodge refunds it, freezes the
  -- demons a beat and returns the attacker's own blow to its guard.
  g = fresh()
  local p = g.player
  local attacker = g:spawn('imp', 16, 24)
  attacker.hp = 5000
  local standard = require('src.content.characters').standard()
  p.resources.stamina = 50
  g:dash(1, 0)
  local breath = p.resources.stamina
  local packet = A.imp.attacks[1].packet
  g:damagePlayer(packet.base, attacker.x, attacker.z, packet, attacker)
  local rule = standard.body.perfectDodge
  local measure = standard.resources.stamina.max
  check(
    'a blow during the dodge is a perfect dodge: no harm, breath back, attacker staggered',
    near(p.hp, 100)
      and near(
        p.resources.stamina,
        math.min(measure, breath + standard.body.rollStamina * rule.refund)
      )
      and g.impactSlow >= rule.freeze
      and attacker.ai == 'hurt'
      and Telemetry.get(g).perfectDodges == 1
  )
  local again = p.resources.stamina
  g:damagePlayer(packet.base, attacker.x, attacker.z, packet, attacker)
  check(
    'one perfect dodge per dodge',
    near(p.resources.stamina, again) and Telemetry.get(g).perfectDodges == 1
  )
  -- Posture by health: a wounded body recovers its guard slower.
  g = fresh()
  local whole, hurt = g:spawn('buer', 12, 20), g:spawn('buer', 20, 20)
  hurt.hp = hurt.maxHp / 2
  for _, e in ipairs({ whole, hurt }) do
    e.poise, e.guardQuiet = 40, 10
    Rules.recover(e, 0.5, A.buer.body)
  end
  local fullRate = (40 - whole.poise) / 0.5
  local halfRate = (40 - hurt.poise) / 0.5
  check(
    'a body at half health recovers its guard at (1 - s) + s / 2 of the rate',
    near(halfRate / fullRate, (1 - D.regenHealthShare) + D.regenHealthShare * 0.5)
  )
  -- Fire meets no armour rating; an ash lord resists it.
  local fire = { base = 100, damageType = 'fire' }
  local iron = { armorRating = 60, zones = D.zones }
  local margrave = { armorRating = 30, resistances = A.boss.body.resist }
  check(
    'fire ignores the iron rating; the Margrave resists fire',
    near(Damage.resolve(fire, iron, 1, 'torso'), 100)
      and near(Damage.resolve(fire, margrave, 1, 'torso'), 100 * (1 - A.boss.body.resist.fire))
  )
  -- Boss weak point: the bare skull carries no armour.
  local boss = { armorRating = 30, locationArmor = A.boss.body.locationArmor }
  check(
    'a Margrave head shot meets no armour, a body shot the old rating',
    Damage.resolve({ base = 100 }, boss, 1, 'head')
        > Damage.resolve({ base = 100 }, boss, 1, 'torso')
      and near(Damage.resolve({ base = 100 }, boss, 1, 'torso'), 100 * 100 / 130)
  )
  -- Furfur's charge can drive the knight into stone (wall slam speed).
  check(
    "Furfur's charge throws the knight past the wall-slam speed",
    Rules.shove(
      A.furfur.attacks[2].packet.push,
      require('src.content.characters').standard().body.mass
    ) > D.slamSpeed
  )
  -- Measurements: control uptime is the stunned share of demon lifetime.
  g = fresh()
  Telemetry.reset(g)
  local a, b = g:spawn('imp', 12, 18), g:spawn('imp', 20, 18)
  a.stun, a.dummy, b.dummy = 10, nil, nil
  a.spawnAge, b.spawnAge = 1, 1
  Telemetry.tick(g, 1)
  check('control uptime counts the stunned share of demon lifetime', near(Telemetry.uptime(g), 0.5))
end
return Tests
