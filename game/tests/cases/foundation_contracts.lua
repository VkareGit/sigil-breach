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
  local Cast = require('src.combat.abilities')
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
  local world = Game.new('classic').world
  check(
    'instance construction copies populated map arrays rather than inheriting an empty override',
    #world.gates == #map.gates and #world.gates > 0 and #world.zones == #map.zones
  )
  local gateX = map.gates[1].x
  world.gates[1].x = gateX + 1
  check('the copied map arrays remain instance-owned', map.gates[1].x == gateX)
  local ok, problem = xpcall(function()
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
      not pcall(Cast.register, 'missing_delivery', function() end)
        and not Cast.registry:has('missing_delivery')
    )
    Delivery.defineKind('fixture_transport', {})
    local weapon = Weapons.define({
      extends = Weapons.get('judge'),
      id = 'fixture_contract_gun',
      delivery = { kind = 'fixture_transport' },
    })
    check(
      'valid data without an executor is refused before a world is created',
      not pcall(Game.new, 'classic')
    )
    Executors:register('fixture_transport', { fire = function() end })
    check(
      'registered executor completes the same data without changing Game',
      pcall(Contracts.weapon, weapon)
    )
    local bad = Schema.copy(weapon)
    bad.mechanism = 'missing_reload'
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
  require('src.session.snapshot').invalidateDefinitions()
  assert(ok, problem)
  return lines
end
return Tests
