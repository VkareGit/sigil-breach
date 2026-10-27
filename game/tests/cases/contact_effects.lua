-- Optional status payloads follow actual contacts and survive the same
-- transport, cancellation, snapshot and journal paths as ordinary damage.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(Game)
  local Weapons = require('src.content.weapons')
  local Modes = require('src.run.modes')
  local Schema = require('src.core.schema')
  local Snapshot = require('src.session.snapshot')
  local Integrity = require('src.session.integrity')
  local Serialize = require('src.core.serialize')
  local Journal = require('src.session.journal')
  local Effects = require('src.combat.effects')
  local Packet = require('src.content.defs.packet')
  local lines = {}
  local check = Fixtures.checker(lines, 'contact effects: ', 'contact effects: ')
  local near = Fixtures.within(1e-7)
  local function tick(g, count)
    for _ = 1, count do
      g:update(1 / 120, {})
    end
  end
  local binding = {
    id = 'fixture_burn',
    kind = 'periodic',
    duration = 0.6,
    interval = 0.2,
    packet = { base = 6, impact = 0, damageType = 'fire' },
  }
  local function create(id, delivery)
    return Weapons.define({
      extends = Weapons.get('judge'),
      id = id,
      capacity = 8,
      delivery = delivery,
      fire = { pellets = 3, spread = 0 },
      attack = { base = 2, impact = 0, push = 0, effects = { binding }, pierce = nil },
    })
  end
  local modeId = 'effect_probe'
  local ok, problem = xpcall(function()
    -- Switching to finite delivery requires explicitly removing inherited pierce.
    local direct = create('effect_hitscan', { kind = 'hitscan' })
    local finiteDef = Schema.copy(direct)
    finiteDef.id, finiteDef.attack.pierce = 'effect_missile', nil
    finiteDef.delivery = { kind = 'projectile', speed = 60, radius = 0.025 }
    Weapons.define(finiteDef)
    local bad = Schema.copy(direct)
    bad.id, bad.attack.effects[1].interval = 'effect_invalid', 0
    check(
      'zero pulse interval fails before registration',
      not pcall(Weapons.define, bad) and not Weapons.registry:has('effect_invalid')
    )
    bad = Schema.copy(direct)
    bad.id, bad.attack.effects[1].packet.impact = 'effect_invalid', 1
    check('health exposure cannot silently drop an authored shove', not pcall(Weapons.define, bad))
    bad = Schema.copy(direct)
    bad.id, bad.attack.effects[1].kind = 'effect_invalid', 'missing_effect'
    check('unknown effect behaviour fails before registration', not pcall(Weapons.define, bad))
    Modes:register(modeId, {
      session = { world = 'classic', map = require('src.content.maps.index').default },
      init = function(g)
        g.player.x, g.player.z, g.player.yaw, g.player.pitch = 16, 25, math.pi, 0
        g.player.armor = 0
        Weapons.give(g, 'effect_hitscan')
        Weapons.give(g, 'effect_missile')
        g.player.weapon = 3
        local enemy = g:spawn('imp', 16, 21)
        enemy.dummy, enemy.hp, enemy.maxHp, enemy.armorRating = true, 500, 500, 0
        enemy.resistances = { fire = 0.5 }
      end,
      start = function(g)
        g.state = 'playing'
      end,
      progress = function() end,
      cancelEffect = function(g)
        return Effects.cancel(g.enemies[1], 'fixture_burn')
      end,
    })
    Snapshot.invalidateDefinitions()
    local function fresh()
      local g = Game.new(modeId)
      g.testing = true
      g:start()
      return g, g.enemies[1]
    end
    local g, enemy = fresh()
    local applied, pulses = 0, 0
    g.bus:on('sim', 'EffectApplied', function()
      applied = applied + 1
    end)
    g.bus:on('sim', 'EffectPulse', function()
      pulses = pulses + 1
    end)
    check(
      'real hitscan discharge applies one effect after pellet aggregation',
      g:shoot() and applied == 1 and #enemy.effectState == 1
    )
    local afterContact = enemy.hp
    tick(g, 73)
    check(
      'three pulses respect fire resistance and expiry exactly',
      pulses == 3 and near(afterContact - enemy.hp, 9) and enemy.effectState == nil
    )

    g, enemy = fresh()
    g:shoot()
    tick(g, 12)
    local timer = enemy.effectState[1].untilPulse
    Effects.apply(g, enemy, direct.attack.effects, 'weapon')
    check(
      'refresh retains one instance and its pulse phase',
      #enemy.effectState == 1 and near(enemy.effectState[1].untilPulse, timer)
    )
    check(
      'explicit cancellation removes the pending effect',
      g:act('cancelEffect') and enemy.effectState == nil
    )
    afterContact = enemy.hp
    tick(g, 90)
    check('cancelled effect produces no later damage', near(afterContact, enemy.hp))

    g, enemy = fresh()
    g:shoot()
    tick(g, 12)
    local saved = Snapshot.capture(g)
    tick(g, 80)
    local expected = Integrity.capture(g)
    Snapshot.restore(g, saved)
    tick(g, 80)
    check(
      'mid-effect memento retains cadence and exact outcome',
      not Integrity.difference(expected, Integrity.capture(g))
    )
    g, enemy = fresh()
    g:shoot()
    enemy.effectState = Serialize.decode(Serialize.encode(enemy.effectState))
    afterContact = enemy.hp
    tick(g, 73)
    check('effect clocks and payload are plain serializable data', near(afterContact - enemy.hp, 9))

    g, enemy = fresh()
    g:shoot()
    local kills = require('src.session.stats').total(g, 'kills')
    g:damageEnemy(enemy, enemy.hp, 'fixture')
    tick(g, 120)
    check(
      'target death clears exposure and cannot award a second kill',
      enemy.effectState == nil and require('src.session.stats').total(g, 'kills') == kills + 1
    )
    g, enemy = fresh()
    local packet = Packet.schema:build({ base = 1, impact = 0, effects = { Schema.copy(binding) } })
    packet.effects[1].cancelOnSourceDeath = true
    g:damagePlayer(packet, enemy.x, enemy.z, nil, enemy)
    afterContact = g.player.hp
    g:damageEnemy(enemy, enemy.hp, 'fixture')
    tick(g, 90)
    check(
      'owner-bound exposure cancels when its source dies',
      g.player.effectState == nil and near(afterContact, g.player.hp)
    )

    g, enemy = fresh()
    g:switchWeapon(4)
    g.player.cooldown = 0
    local journal = Journal.record(g)
    g:shoot()
    check(
      'finite rounds carry effects without applying them at the muzzle',
      #g.bullets == 3 and enemy.effectState == nil
    )
    g:switchWeapon(1)
    tick(g, 110)
    Journal.stop(g)
    local repeatSession = fresh()
    repeatSession:switchWeapon(4)
    repeatSession.player.cooldown = 0
    Journal.replay(repeatSession, Journal.decode(Journal.encode(journal)))
    check(
      'in-flight effects retain their weapon and replay after swapping',
      enemy.hp < 500
        and not Integrity.difference(Integrity.capture(g), Integrity.capture(repeatSession))
    )
    g, enemy = fresh()
    g:shoot()
    g:damagePlayer(packet, enemy.x, enemy.z, nil, enemy)
    require('src.session.encounter').clearWorld(g)
    check(
      'full encounter reset removes ongoing knight effects',
      g.player.effectState == nil and #g.enemies == 0
    )
  end, debug.traceback)
  Modes:unregister(modeId)
  for _, id in ipairs({ 'effect_hitscan', 'effect_missile', 'effect_invalid' }) do
    Weapons.registry:unregister(id)
  end
  Snapshot.invalidateDefinitions()
  assert(ok, problem)
  return lines
end
return Tests
