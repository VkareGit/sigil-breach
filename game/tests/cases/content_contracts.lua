-- Definition failures must happen before an action can enter a simulation
-- or an equipment id can enter a loadout that the save format cannot retain.
local Tests = {}
function Tests.run()
  local lines = {}
  local check =
    require('tests.support.fixtures').checker(lines, 'content contracts: ', 'content contracts: ')
  local Schema = require('src.core.schema')
  local Registry = require('src.core.registry')
  local Id = require('src.core.id')
  local Action = require('src.content.defs.action')
  local Creature = require('src.content.defs.creature')
  local A = require('src.content.enemies')
  local Abilities = require('src.content.abilities')
  local Ability = require('src.content.defs.ability')
  local Weapons = require('src.content.weapons')
  local Weapon = require('src.content.defs.weapon')
  local function rejects(name, base, mutate, path)
    local def = Schema.copy(base)
    mutate(def)
    local ok, err = pcall(Action.build, def, 'probe')
    check(name, not ok and tostring(err):find(path, 1, true))
  end
  local pool, fan, claw = A.buer.attacks[1], A.boss.attacks[1], A.imp.attacks[1]
  rejects('zero pool pulse cannot reach the hazard loop', pool, function(a)
    a.pool.pulse = 0
  end, '.pool.pulse')
  rejects('zero line pulse cannot reach the hazard loop', fan, function(a)
    a.line.pulse = 0
  end, '.line.pulse')
  rejects('a spit requires its own damage packet', pool, function(a)
    a.bolt.packet = nil
  end, '.bolt.packet')
  for _, active in ipairs({
    { 0.02, 'bad' },
    { 0.02 },
    { 0.02, 0.1, 0.15 },
    { [1] = 0.02, [3] = 0.1 },
    { 0.1, 0.02 },
    { 0.1, 0.1 },
    { 0.02, claw.lungeTime + 0.01 },
    { -0.01, 0.1 },
    { 0.02, math.huge },
  }) do
    rejects('invalid contact window is rejected before melee', claw, function(a)
      a.active = active
    end, '.active')
  end
  rejects('lunge movement fits its strike state', claw, function(a)
    a.duration = 0.1
  end, '.lungeTime')
  rejects('charge requires a nonzero divisor', A.armored.attacks[2], function(a)
    a.speed = 0
  end, '.speed')
  rejects('charge time bounds cannot be reversed', A.armored.attacks[2], function(a)
    a.maxTime = a.minTime / 2
  end, '.maxTime')
  rejects('leap height cannot produce a zero flight time', A.imp.attacks[2], function(a)
    a.height = 0
  end, '.height')
  rejects('projectile RGB is complete before the renderer', pool, function(a)
    a.bolt.color = { 1 }
  end, '.bolt.color')
  rejects('fan count is an integer', fan, function(a)
    a.count = 1.5
  end, '.count')
  rejects('line cadence is an integer', fan, function(a)
    a.line.every = 1.5
  end, '.line.every')
  rejects('range bounds cannot be reversed', claw, function(a)
    a.minRange = a.range + 1
  end, '.minRange')
  local powder = Abilities:get('powder')
  rejects('pool condition names existing shared behavior', pool, function(a)
    a.pool.condition = 'missing_condition'
  end, '.pool.condition')
  local badHands = Schema.copy(powder)
  badHands.id, badHands.hands = 'contract_hands', 'missing'
  local validHands, handsError = pcall(Abilities.define, badHands)
  check(
    'unknown equipment artwork is rejected before registration',
    not validHands
      and tostring(handsError):find('.hands', 1, true)
      and not Abilities:has(badHands.id)
  )
  for _, key in ipairs({ 'blast', 'selfBlast' }) do
    rejects(key .. ' requires an ordered falloff curve', powder.action, function(a)
      a[key].falloffEnd = a[key].falloffStart
    end, '.' .. key)
  end
  local valid = Schema.copy(claw)
  valid.active = { 0, valid.lungeTime }
  check('contact may span exactly the whole lunge', pcall(Action.build, valid))
  check('existing local action names retain hyphens', Action.build(fan).id == 'ember-fan')
  for _, attacks in ipairs({ {}, { claw, claw }, { [2] = claw }, { claw, extra = claw } }) do
    check(
      'creature attacks are nonempty, dense and uniquely named',
      not pcall(Creature.define, { extends = A.imp, attacks = attacks })
    )
  end
  check(
    'evade animation cannot divide by zero',
    not pcall(Creature.define, { extends = A.stolas, move = { evade = { time = 0 } } })
  )

  local checks = 0
  local registry = Registry:new('probe', function()
    checks = checks + 1
  end)
  local accepted = registry:register('accepted', {})
  check(
    'duplicate registration fails before entry callbacks can have side effects',
    not pcall(registry.register, registry, 'accepted', {})
      and checks == 1
      and registry:get('accepted') == accepted
      and #registry:ids() == 1
  )
  local weaponIds, abilityIds =
    table.concat(Weapons.registry:ids(), ','), table.concat(Abilities:ids(), ',')
  for _, id in ipairs({ 'iron-rifle', '', 'with space', 'a:b', 'a,b', 'line\nbreak' }) do
    check(
      'registry rejects unsavable id before entry callbacks',
      not pcall(registry.register, registry, id, {})
        and checks == 1
        and registry:get('accepted') == accepted
        and #registry:ids() == 1
    )
    check(
      'weapon definition rejects unsavable id',
      not pcall(Weapon.define, { extends = Weapons.get('exorcist'), id = id })
    )
    local def = Schema.copy(powder)
    def.id = id
    check('ability definition rejects unsavable id', not pcall(Ability.define, def))
  end
  local invalid = Schema.copy(powder)
  invalid.action = Schema.copy(pool)
  invalid.action.pool.pulse = 0
  check(
    'failed ability replacement preserves its entry and order',
    not pcall(Abilities.define, invalid)
      and Abilities:get('powder') == powder
      and table.concat(Abilities:ids(), ',') == abilityIds
  )
  invalid.id = 'contract_rejected'
  check(
    'failed new ability leaves no partial registration',
    not pcall(Abilities.define, invalid)
      and not Abilities:has(invalid.id)
      and table.concat(Abilities:ids(), ',') == abilityIds
  )
  check(
    'rejected weapon ids leave registration order unchanged',
    table.concat(Weapons.registry:ids(), ',') == weaponIds
  )

  check(
    'temporary content leaves the shipped loadouts and registries unchanged',
    table.concat(Weapons.registry:ids(), ',') == weaponIds
      and table.concat(Abilities:ids(), ',') == abilityIds
      and table.concat(Weapons.defaultLoadout, ',') == 'exorcist,judge'
      and table.concat(Abilities.defaultLoadout, ',') == 'powder'
  )
  return lines
end
return Tests
