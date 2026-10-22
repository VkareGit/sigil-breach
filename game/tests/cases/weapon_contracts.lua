local Tests = {}
function Tests.run(G)
  local lines = {}
  local Fixtures = require('tests.support.fixtures')
  local check = Fixtures.checker(lines, 'weapon contracts: ', 'weapon contracts: ')
  local Weapons = require('src.content.weapons')
  local Definition = require('src.content.defs.weapon')
  local Delivery = require('src.combat.weapon_delivery')
  local Schema = require('src.core.schema')
  local B = require('src.combat.ballistics')
  local parent = Weapons.get('exorcist')
  check(
    'invalid flash fails in the definition, not in the drawing callback',
    not pcall(Definition.define, { extends = parent, id = 'bad_flash', fire = { flash = { -1 } } })
  )
  local partial = Definition.define({
    extends = Weapons.get('judge'),
    id = 'partial',
    fire = { rounds = 2, pellets = 2 },
  })
  check(
    'a multi-round variant has safe partial-discharge captions',
    partial.hud.partial == 'PARTIAL DISCHARGE' and partial.hud.partialShort == 'PARTIAL'
  )
  for _, mod in ipairs({
    { spread = 'bad' },
    { scale = { impact = 'bad' } },
    { set = { unknown = 1 } },
    { scale = { damageType = 2 } },
    { set = { falloffEnd = 0 } },
    { scale = { base = math.huge } },
  }) do
    local ok =
      pcall(Weapons.define, { extends = parent, id = 'bad_modifier', glyphs = { trial = mod } })
    check(
      'bad modifier is rejected before entering the weapon registry',
      not ok and not Weapons.registry:has('bad_modifier')
    )
  end
  local finite = Definition.define({
    extends = parent,
    id = 'finite',
    delivery = { kind = 'projectile', speed = 12 },
  })
  local instant =
    Definition.define({ extends = finite, id = 'instant', delivery = { kind = 'hitscan' } })
  local slower = Definition.define({ extends = finite, id = 'slower', delivery = { speed = 6 } })
  check(
    'changing delivery kind replaces incompatible inherited fields',
    instant.delivery.kind == 'hitscan' and not instant.delivery.speed
  )
  check(
    'a variant keeps the parent illustration unless it names another',
    finite.art == 'exorcist' and instant.art == 'exorcist'
  )
  check(
    'tuning the same delivery inherits its kind and other fields',
    slower.delivery.kind == 'projectile'
      and slower.delivery.speed == 6
      and slower.delivery.radius == finite.delivery.radius
  )
  for _, count in ipairs({ 1, 2, 3, 9, 21, 24, 63, 128 }) do
    local x, y, bounded = 0, 0, true
    for index = 1, count do
      local px, py = B.pellet(index, 7, count)
      x, y = x + px, y + py
      bounded = bounded
        and px == px
        and py == py
        and math.abs(px) <= require('src.content.tuning').pelletSpread
        and math.abs(py) <= require('src.content.tuning').pelletVerticalSpread
    end
    check(
      count .. ' pellets are finite, centred and inside the cone',
      bounded and math.abs(x) < 1e-8 and math.abs(y) < 1e-8
    )
  end
  local id = 'trial_contract'
  local ok, reason = pcall(function()
    Weapons.define({ extends = parent, id = id, mechanism = 'missing' })
    local g = Fixtures.arena(G)
    Weapons.give(g, id)
    g.weapon, g.cooldown, g.reload = 3, 0, 1
    local state = Weapons.state(g)
    local spent = state.mag
    local fired, errorText = pcall(g.shoot, g)
    check(
      'missing mechanism fails before ammo or reload changes',
      not fired
        and tostring(errorText):find('unknown reload mechanism', 1, true)
        and state.mag == spent
        and g.reload == 1
        and g.shots == 0
    )
    Weapons.registry:unregister(id)
    local def = Weapons.define({
      extends = parent,
      id = id,
      delivery = { kind = 'projectile', speed = 20 },
      fire = { pellets = 24, autoReload = false },
    })
    g = Fixtures.arena(G)
    Weapons.give(g, id)
    g.weapon, g.cooldown = 3, 0
    check(
      '24 physical projectiles launch as a complete discharge',
      g:shoot() and #g.bullets == 24 and Weapons.state(g).mag == 0
    )
    local handler = Delivery:unregister('projectile')
    local missingOk, missingReason = pcall(function()
      g = Fixtures.arena(G)
      Weapons.give(g, id)
      g.weapon, g.cooldown, g.reload = 3, 0, 1
      local fired = pcall(g.shoot, g)
      check(
        'missing executor fails before cancelling a reload',
        not fired and g.reload == 1 and Weapons.state(g).mag == def.capacity and #g.bullets == 0
      )
    end)
    Delivery:register('projectile', handler)
    assert(missingOk, missingReason)
  end)
  Weapons.registry:unregister(id)
  require('src.session.snapshot').invalidateDefinitions()
  assert(ok, reason)
  return lines
end
return Tests
