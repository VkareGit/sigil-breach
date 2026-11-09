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
  local pool = require('tests.support.pool_attack')
  local fan, claw = A.boss.attacks[1], A.imp.attacks[1]
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
  -- A creature is one package (PLAN F4): a directory of its own under
  -- content/creatures, its definition the package's init.lua.
  local loose = {}
  for _, id in ipairs(A.creatures) do
    if not love.filesystem.getInfo('src/content/creatures/' .. id .. '/init.lua', 'file') then
      loose[#loose + 1] = id
    end
  end
  check('every creature is a package of its own: ' .. table.concat(loose, ', '), #loose == 0)
  -- Its atlas sheet and anatomy live in its package (PLAN F4); the atlas
  -- lists only name them.
  local outside = {}
  for _, module in ipairs(require('src.content.art.sheets.index')) do
    if not module:match('^src%.content%.creatures%.[%w_]+%.sheet$') then
      outside[#outside + 1] = module
    end
  end
  for _, module in pairs(require('src.content.art.anatomy.index')) do
    if not module:match('^src%.content%.creatures%.[%w_]+%.anatomy$') then
      outside[#outside + 1] = module
    end
  end
  check(
    'every atlas sheet and anatomy is in its creature package: ' .. table.concat(outside, ', '),
    #outside == 0
  )
  -- Its voices and its audio profile live in its package too (PLAN F4); the
  -- shared banks of content/sounds hold no creature's own voices.
  local unvoiced = {}
  for _, id in ipairs(A.creatures) do
    for _, part in ipairs({ 'audio', 'voices' }) do
      local path = 'src/content/creatures/' .. id .. '/' .. part .. '.lua'
      if not love.filesystem.getInfo(path, 'file') then
        unvoiced[#unvoiced + 1] = id .. '/' .. part
      end
    end
  end
  check(
    'every creature keeps its voices and audio profile in its package: '
      .. table.concat(unvoiced, ', '),
    #unvoiced == 0
  )
  -- And its words: the shared text table names no creature's own key.
  local shared = love.filesystem.read('src/content/text.lua')
  local unworded = {}
  for _, id in ipairs(A.creatures) do
    if
      not love.filesystem.getInfo('src/content/creatures/' .. id .. '/words.lua', 'file')
      or shared:find("'creature_" .. id, 1, true)
    then
      unworded[#unworded + 1] = id
    end
  end
  check(
    'every creature keeps its words in its package: ' .. table.concat(unworded, ', '),
    #unworded == 0
  )
  -- A body's standing is its tier, not a boss flag (PLAN G5): an elite and a
  -- true boss share the elite's rules, and an older save names its elites.
  local BodySchema = require('src.content.defs.body')
  local Rules = require('src.combat.rules')
  local tiered = Rules.elite
    and Rules.elite({ kind = 'furfur' })
    and Rules.elite({ kind = 'boss' })
    and not Rules.elite({ kind = 'imp' })
  local pools = require('src.storage.save').section('pools')
  local Tree = require('src.core.data_tree')
  local stood = pools.migrations[10]
    and Tree.decode(pools.migrations[10]({
      pools = Tree.encode({ enemies = { { id = 3, boss = true }, { id = 4, boss = false } } }),
    }).pools).enemies
  check(
    'a body stands on its tier, and an older save names its elites',
    tiered
      and stood
      and stood[1].tier == 'elite'
      and stood[1].boss == nil
      and stood[2].tier == 'common'
      and BodySchema.fields.boss == nil
      and BodySchema.fields.tier ~= nil
  )
  -- Every sigil names a kind of effect the fight knows (PLAN G2).
  local SigilRules = require('src.content.sigils')
  local SigilKinds = require('src.combat.sigil_kinds')
  local unknown = {}
  for _, id in ipairs(SigilRules.order) do
    if not SigilKinds:has(SigilRules[id].effect or '') then
      unknown[#unknown + 1] = id
    end
  end
  check('every sigil names a known kind of effect: ' .. table.concat(unknown, ', '), #unknown == 0)
  -- A fight saved before definitions had names in their lists (pools before
  -- 7) named attacks by places that changed since (PLAN G1): it is not read,
  -- the pilgrimage resumes its field without it, and no frozen copies of old
  -- attacks are kept for it.
  local poolsSection = require('src.storage.save').section('pools')
  check(
    'a fight saved before attacks had names is never resumed as another attack',
    not pcall(poolsSection.migrations[6], { pools = {} })
      and love.filesystem.getInfo('src/content/migrations') == nil
  )
  -- The state of a committed attack belongs to its kind (PLAN F3): a save
  -- from before keeps it on the body, and loading moves it to e.act.
  local Tree = require('src.core.data_tree')
  local section = require('src.storage.save').section('pools')
  local body = { id = 7, attackSpec = A.furfur.attacks[1], turnsLeft = 2, turnAt = 0.4, hp = 9 }
  local idle = { id = 8, hp = 9 }
  local moved = Tree.decode(
    section.migrations[7]({ pools = Tree.encode({ enemies = { body, idle } }) }).pools
  ).enemies
  check(
    'an older save moves an attack in progress into its own state',
    section.version >= 8
      and moved[1].act
      and moved[1].act.turnsLeft == 2
      and moved[1].act.turnAt == 0.4
      and moved[1].turnsLeft == nil
      and moved[1].attackSpec == A.furfur.attacks[1]
      and moved[2].act == nil
  )
  -- What an attack marked on the ground, and how it lets go, are its kind's
  -- (PLAN F3): the registry of kinds names no kind's own state.
  local ActionKinds = require('src.combat.action_kinds')
  local Components = require('src.session.components')
  local lightning
  for _, atk in ipairs(A.furfur.attacks) do
    if atk.id == 'lightning' then
      lightning = atk
    end
  end
  local mark = {}
  local caster = { attackSpec = lightning, act = { mark = mark } }
  ActionKinds.abandon(caster)
  local fallen = { attackSpec = lightning, act = { mark = {} } }
  ActionKinds.forget(fallen)
  check(
    'a broken strike cancels the place it marked, and a fallen caster lets go of it',
    mark.cancelled == true
      and caster.act.mark == nil
      and fallen.act.mark == nil
      and Components.schemas.attacker.pendingHazard == nil
  )
  local marked = Tree.decode(section.migrations[8]({
    pools = Tree.encode({
      enemies = { { id = 9, attackSpec = lightning, act = {}, pendingHazard = { life = 1 } } },
    }),
  }).pools).enemies[1]
  check(
    'an older save moves a marked strike into its own state',
    section.version >= 9 and marked.pendingHazard == nil and marked.act.mark.life == 1
  )
  -- A save names a definition in a list by its id, not by its place (PLAN
  -- G1): content may grow and reorder without a fight resuming another blow.
  local attacks = A.boss.attacks
  local kept = attacks[3]
  local saved = Tree.encode({ spec = kept })
  table.insert(attacks, 1, { id = 'trial-before' })
  Tree.invalidate()
  local grew, after = pcall(Tree.decode, saved)
  table.remove(attacks, 1)
  Tree.invalidate()
  check(
    'a saved attack is the same attack after another is added before it',
    grew and after.spec == kept
  )
  saved = Tree.encode({ spec = kept })
  local gone = table.remove(attacks, 3)
  Tree.invalidate()
  local read = pcall(Tree.decode, saved)
  table.insert(attacks, 3, gone)
  Tree.invalidate()
  check('an attack its creature no longer has is never read as another one', not read)
  local named = section.migrations[9]({
    pools = {
      ['$id'] = 1,
      ['$v'] = {
        enemies = {
          ['$id'] = 2,
          ['$v'] = {
            {
              ['$id'] = 3,
              ['$v'] = {
                id = 4,
                attackSpec = { ['$def'] = { 'src.content.creatures.boss', 'attacks', 3 } },
              },
            },
          },
        },
      },
    },
  }).pools
  local step = named['$v'].enemies['$v'][1]['$v'].attackSpec['$def'][3]
  check(
    'a save from before names its attacks when it is read',
    section.version >= 10
      and type(step) == 'table'
      and step['$key'] == kept.id
      and Tree.decode(named).enemies[1].attackSpec == kept
  )
  -- A kind upgrades its own state (PLAN F3): the save records the version of
  -- every kind that has one, and an older state is brought up by its kind.
  local charge = ActionKinds:get(A.furfur.attacks[1].kind)
  charge.version = 2
  charge.migrations = {
    [1] = function(state)
      state.turnsLeft = state.turnsLeft + 1
    end,
  }
  local versions = ActionKinds.versions()
  local restored = section.unpack({
    pools = Tree.encode({
      knights = { { id = 1 } },
      enemies = { { id = 2, attackSpec = A.furfur.attacks[1], act = { turnsLeft = 2 } } },
    }),
    controlled = 1,
  })
  local current = section.unpack({
    pools = Tree.encode({
      knights = { { id = 1 } },
      enemies = { { id = 2, attackSpec = A.furfur.attacks[1], act = { turnsLeft = 2 } } },
    }),
    controlled = 1,
    kinds = versions,
  })
  charge.version, charge.migrations = nil, nil
  check(
    'a kind brings the state of an older save up to its own version',
    versions[A.furfur.attacks[1].kind] == 2
      and restored.pools.enemies[1].act.turnsLeft == 3
      and current.pools.enemies[1].act.turnsLeft == 2
      and ActionKinds.versions()[A.furfur.attacks[1].kind] == nil
  )
  return lines
end
return Tests
