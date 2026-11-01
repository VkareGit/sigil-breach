-- Malformed data must be refused intact, before construction or resource use.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(Game)
  local Schema = require('src.core.schema')
  local Conditions = require('src.content.conditions')
  local Rules = require('src.combat.rules')
  local Weapons = require('src.content.weapons')
  local Delivery = require('src.content.defs.delivery')
  local Executors = require('src.combat.weapon_delivery')
  local Contracts = require('src.session.content_contracts')
  local Creature = require('src.content.defs.creature')
  local Archetypes = require('src.content.enemies')
  local AI = require('src.enemies.ai')
  local Target = require('src.enemies.target')
  local Kinds = require('src.combat.action_kinds')
  local lines = {}
  local check = Fixtures.checker(lines, 'foundation contracts: ', 'foundation contracts: ')
  local item = Schema:new('item', { value = { type = 'number', required = true } })
  local list = Schema:new('list', { items = { type = 'table', list = item } })
  for name, values in pairs({
    hole = { [1] = { value = 1 }, [3] = { value = 3 } },
    label = { { value = 1 }, typo = { value = 2 } },
    scalar = { { value = 1 }, 7 },
    zero = { [0] = { value = 0 }, [1] = { value = 1 } },
  }) do
    check(
      'list refuses ' .. name .. ' instead of erasing it',
      not pcall(list.build, list, { items = values })
    )
  end
  check(
    'valid and empty lists retain their explicit content',
    #list:build({ items = { { value = 2 } } }).items == 1 and #list:build({ items = {} }).items == 0
  )
  local parent = { items = { { value = 1 }, { value = 2 } }, record = { keep = true } }
  local cleared = Schema.inherit(parent, { items = {}, record = {} })
  check(
    'an explicit empty variant list clears inherited content without clearing record defaults',
    #cleared.items == 0 and cleared.record.keep and #parent.items == 2
  )
  local malformed = Schema.inherit(parent, { items = { [2] = { value = 3 } } })
  check(
    'a sparse variant list is refused instead of being repaired by inherited entries',
    malformed.items[1] == nil and not pcall(list.build, list, { items = malformed.items })
  )
  local Maps = require('src.content.maps.index')
  local map = Maps:get(Maps.default)
  local world = Game.new('floor').world
  check(
    'instance construction copies populated map arrays rather than inheriting an empty override',
    #world.gates == #map.gates and #world.gates > 0 and #world.zones == #map.zones
  )
  local gateX = map.gates[1].x
  world.gates[1].x = gateX + 1
  check('the copied map arrays remain instance-owned', map.gates[1].x == gateX)
  local ok, problem = xpcall(function()
    local creatureId, behaviorId = 'fixture_ai_contract', 'fixture_ai_behavior'
    Archetypes.creatures[#Archetypes.creatures + 1] = creatureId
    local function creature(move)
      local definition = Creature.define({
        extends = Archetypes.imp,
        id = creatureId,
        kind = 'imp',
        variant = creatureId,
        move = move,
      })
      Archetypes[creatureId] = definition
      return definition
    end
    for _, field in ipairs({ 'style', 'targeting' }) do
      creature({ [field] = 'missing_ai_behavior' })
      local created, message = pcall(Game.new, 'floor')
      check(
        'unknown ' .. field .. ' is rejected at composition before starting a world',
        not created and tostring(message):find('missing_ai_behavior', 1, true)
      )
    end
    AI.styles[behaviorId], Target.strategies[behaviorId] = {}, {}
    for _, field in ipairs({ 'style', 'targeting' }) do
      local definition = creature({ [field] = behaviorId })
      check(
        'noncallable ' .. field .. ' is rejected at composition',
        not pcall(Contracts.creature, definition)
      )
    end
    local moved, targeted = 0, 0
    AI.styles[behaviorId] = function()
      moved = moved + 1
    end
    Target.strategies[behaviorId] = function(g)
      targeted = targeted + 1
      return g.player
    end
    creature({ style = behaviorId, targeting = behaviorId })
    local scene = Fixtures.arena(Game)
    local demon = scene:spawn(creatureId, 16, 20)
    demon.awake, demon.memory, demon.spawnAge, demon.attack = true, 30, 1, 30
    AI.update(scene, 1 / 120)
    check(
      'new movement and targeting strategies execute through the unchanged AI',
      moved > 0 and targeted > 0 and demon.target == scene.player.id
    )
    AI.styles[behaviorId], Target.strategies[behaviorId] = nil, nil
    Archetypes[creatureId] = nil
    table.remove(Archetypes.creatures)

    local body = {}
    check(
      'unknown condition is refused before creating state',
      not pcall(Rules.addCondition, body, 'missing_condition', 1) and body.conditions == nil
    )
    Conditions.register('fixture_slow', { speed = 0.5, recovery = 0.25 })
    Rules.addCondition(body, 'fixture_slow', 0.4)
    check(
      'new condition registered after Rules import affects both scales',
      Rules.speedScale(body) == 0.5 and Rules.recoveryScale(body) == 0.25
    )
    local original = Conditions.get('fixture_slow')
    check(
      'invalid condition replacement preserves the old definition',
      not pcall(Conditions.register, 'fixture_slow', { speed = -1 })
        and Conditions.get('fixture_slow') == original
    )
    Rules.tick(body, 0.4)
    check(
      'new condition expires through the shared clock',
      Rules.speedScale(body) == 1 and Rules.recoveryScale(body) == 1
    )
    check(
      'invalid executor registration changes no registry entry',
      not pcall(Kinds.register, Kinds, 'missing_delivery', { cast = function() end })
        and not Kinds:has('missing_delivery')
    )
    Delivery.defineKind('fixture_transport', {})
    local weapon = Weapons.define({
      extends = Weapons.get('judge'),
      id = 'fixture_contract_gun',
      delivery = { kind = 'fixture_transport' },
    })
    check(
      'valid data without an executor is refused before a world is created',
      not pcall(Game.new, 'floor')
    )
    Executors:register('fixture_transport', { fire = function() end })
    check(
      'registered executor completes the same data without changing Game',
      pcall(Contracts.weapon, weapon)
    )
    local bad = Schema.copy(weapon)
    bad.reload = { mechanism = 'missing_reload' }
    check(
      'unknown reload mechanism is detected at the composition boundary',
      not pcall(Contracts.weapon, bad)
    )
    bad = Schema.copy(weapon)
    bad.art = 'not_loaded_in_headless_simulation'
    check(
      'simulation composition does not require a GPU art resource',
      pcall(Contracts.weapon, bad)
    )
  end, debug.traceback)
  Conditions.unregister('fixture_slow')
  Weapons.registry:unregister('fixture_contract_gun')
  Executors:unregister('fixture_transport')
  Delivery.kinds:unregister('fixture_transport')
  AI.styles.fixture_ai_behavior, Target.strategies.fixture_ai_behavior = nil, nil
  Archetypes.fixture_ai_contract = nil
  for i = #Archetypes.creatures, 1, -1 do
    if Archetypes.creatures[i] == 'fixture_ai_contract' then
      table.remove(Archetypes.creatures, i)
    end
  end
  require('src.session.snapshot').invalidateDefinitions()
  assert(ok, problem)
  return lines
end
return Tests
