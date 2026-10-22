-- Prove a new transport and damage type through real firing, painted contacts,
-- HUD, rendering, reload, checkpoint and replay. No production gun is added.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, renderer)
  local lines = {}
  local check = Fixtures.checker(lines, 'weapon extension: ', 'weapon extension: ')
  local Weapons = require('src.content.weapons')
  local Schema = require('src.core.schema')
  local Snapshot = require('src.session.snapshot')
  local Journal = require('src.session.journal')
  local Serialize = require('src.core.serialize')
  local Skin = require('src.ui.skin')
  local UI = require('src.ui.interface')
  local parent = Weapons.get('exorcist')
  local before = Serialize.encode(parent)
  local id = 'trial_firearm'
  local def = Weapons.define({
    extends = parent,
    id = id,
    name = 'TRIAL FIREARM',
    art = 'judge',
    hud = { title = 'TRIAL FIREARM', kind = 'CARBINE', tab = 'FIRE TEST', draw = 'trial firearm' },
    capacity = 4,
    startReserve = 8,
    maxReserve = 16,
    packSize = 4,
    cycle = 0.3,
    range = 12,
    mechanism = 'cylinder',
    fire = { rounds = 1, pellets = 1, heavy = false, autoReload = false, ejects = false },
    delivery = { kind = 'projectile', speed = 18, radius = 0.025, color = { 0.7, 0.2, 0.08 } },
    attack = {
      base = 40,
      impact = 10,
      push = 2,
      damageType = 'fire',
      falloffStart = 1,
      falloffEnd = 12,
      minPower = 0.25,
    },
  })
  Snapshot.invalidateDefinitions()
  local originalText = Skin.text
  local ok, reason = pcall(function()
    check(
      'variant inherits independently and never mutates the parent',
      def.fire.sound == parent.fire.sound
        and def.fire ~= parent.fire
        and def.weight ~= parent.weight
        and Serialize.encode(parent) == before
    )
    local bad = Schema.copy(def)
    bad.id, bad.delivery.kind = 'trial_invalid', 'unknown'
    local accepted = pcall(Weapons.define, bad)
    check(
      'unknown delivery is rejected before registration',
      not accepted and not Weapons.registry:has(bad.id)
    )
    bad = Schema.copy(def)
    bad.id, bad.fire.pellets = 'trial_invalid', 0.5
    check(
      'fractional projectiles cannot silently round a discharge',
      not pcall(Weapons.define, bad)
    )
    bad = Schema.copy(def)
    bad.id, bad.attack.pierce = 'trial_invalid', Weapons.get('judge').attack.pierce
    check(
      'unsupported finite penetration fails explicitly instead of being ignored',
      not pcall(Weapons.define, bad)
    )
    local unarmed = Fixtures.arena(G)
    local oldLoadout = Serialize.encode(unarmed.player.loadout)
    check(
      'giving an unknown gun cannot corrupt the loadout',
      not pcall(Weapons.give, unarmed, 'missing_gun')
        and Serialize.encode(unarmed.player.loadout) == oldLoadout
    )
    local function setup(resistance)
      local g = Fixtures.arena(G)
      local slot = Weapons.give(g, id)
      g:switchWeapon(slot)
      g.cooldown, g.elapsed = 0, 1
      local e = g:spawn('imp', 16, 21)
      e.dummy, e.hp, e.maxHp, e.armorRating = true, 1000, 1000, 0
      e.resistances = { fire = resistance or 0 }
      return g, e
    end
    local g, e = setup(0.5)
    local receipt
    g.bus:on('sim', 'VolleyResolved', function(event)
      receipt = event.report
    end)
    local mag = Weapons.state(g).mag
    check(
      'finite delivery spends one round and does not inflict an instant wound',
      g:shoot() and Weapons.state(g).mag == mag - 1 and #g.bullets == 1 and e.hp == 1000
    )
    local missile = g.bullets[1]
    check(
      'missile carries the inherited attack, its own radius and finite range',
      missile.packet.damageType == 'fire'
        and missile.radius == 0.025
        and missile.life == def.range / def.delivery.speed
    )
    g:switchWeapon(1)
    for _ = 1, 60 do
      g:update(1 / 120, {})
    end
    check(
      'later contact keeps the firing weapon after swapping',
      e.hp < 1000 and receipt and receipt.weapon == 3 and receipt.weaponName == def.name
    )
    check(
      'damage receipt names actual painted part and surface',
      receipt.contacts[1].shapeId
        and receipt.contacts[1].material
        and receipt.contacts[1].distance > 2
        and receipt.healthDamage > 0
        and g.hits == 1
    )
    local plain, flesh = setup(0)
    plain:shoot()
    for _ = 1, 60 do
      plain:update(1 / 120, {})
    end
    check(
      'fire resistance halves the actual delivered wound',
      math.abs((1000 - flesh.hp) * 0.5 - (1000 - e.hp)) < 1e-6
    )
    local blocked, untouched = setup()
    blocked.world.map[24][16] = 1
    require('src.world.arena').rebuild(blocked.world)
    blocked:shoot()
    for _ = 1, 60 do
      blocked:update(1 / 120, {})
    end
    check(
      'a finite shot cannot cross intervening cover',
      untouched.hp == 1000 and #blocked.bullets == 0
    )
    local limited = setup()
    limited.enemies = {}
    limited:shoot()
    local ranged = limited.bullets[1]
    -- Limit life to simulate the last part of a flight: the sweep must never
    -- advance a full dt past the specified remaining range.
    ranged.life = 0.001
    require('src.combat.projectiles').update(limited, 1 / 30)
    check(
      'range expiry sweeps only the remaining lifetime',
      #limited.bullets == 0 and math.abs(ranged.travelled - 0.018) < 1e-8
    )
    local multi = Weapons.define({ extends = def, id = 'trial_multifire', fire = { pellets = 3 } })
    Snapshot.invalidateDefinitions()
    local many = setup()
    Weapons.give(many, multi.id)
    many.weapon, many.cooldown = 4, 0
    many:shoot()
    local snapshot = Snapshot.capture(many)
    Snapshot.restore(many, snapshot)
    check(
      'snapshot preserves the shared discharge across its finite pellets',
      #many.bullets == 3
        and many.bullets[1].shot == many.bullets[3].shot
        and many.bullets[1].shot.profile == multi
    )
    for _ = 1, 60 do
      many:update(1 / 120, {})
    end
    check('several finite pellets count as a single successful trigger pull', many.hits == 1)
    Weapons.registry:unregister(multi.id)
    local recorded = setup()
    local baseline = Snapshot.capture(recorded)
    local journal = Journal.record(recorded)
    recorded:shoot()
    recorded:switchWeapon(1)
    for _ = 1, 90 do
      recorded:update(1 / 120, {})
    end
    Journal.stop(recorded)
    local replayed = setup()
    Snapshot.restore(replayed, baseline)
    Journal.replay(replayed, assert(Journal.decode(Journal.encode(journal))))
    check(
      'projectile hit receipts and complete state replay after a weapon swap',
      replayed.enemies[1].hp == recorded.enemies[1].hp and #journal.receipts > 0
    )
    local run = Fixtures.expedition(G)
    Weapons.give(run, id)
    run:switchWeapon(3)
    run.cooldown = 0
    Weapons.state(run).mag = 0
    check('existing reload mechanism works for the new delivery', run:reloadGun())
    for _ = 1, 400 do
      run:update(1 / 120, {})
    end
    check(
      'reload fills its own capacity from its reserve',
      Weapons.state(run).mag == 4 and Weapons.state(run).reserve == 4
    )
    local Save, Descent = require('src.storage.run_save'), require('src.run.descent')
    local saved = assert(Save.decode(Save.encode(Descent.snapshot(run), 1)))
    local loaded = Fixtures.expedition(G)
    Descent.load(loaded, saved)
    check(
      'checkpoint reconstructs the third gun and its ammunition',
      loaded.player.loadout[3] == id
        and loaded.player.arsenal[id].mag == 4
        and loaded.player.arsenal[id].reserve == 4
    )
    loaded.weapon = 3
    loaded.view.swapAge = 1
    local labels = {}
    Skin.text = function(t, ...)
      labels[t] = true
      return originalText(t, ...)
    end
    local auditBefore = Skin.auditFailureCount or 0
    renderer:draw(loaded, 1280, 720)
    UI.draw(loaded, 1280, 720)
    Skin.text = originalText
    check('actual HUD renders the third definition in its painted arsenal', labels['3 FIRE TEST'])
    check(
      'painted UI bounds remain valid with a third weapon',
      (Skin.auditFailureCount or 0) == auditBefore
    )
    check(
      'renderer uses the declared hands and animation atlas',
      require('src.render.weapon_art').idOf(loaded) == 'judge'
        and require('src.render.weapon_art').frame(loaded) >= 1
    )
    local fourth = Weapons.define({ extends = def, id = 'trial_fourth', hud = { tab = 'FOURTH' } })
    Snapshot.invalidateDefinitions()
    require('tests.cases.content_schema').run(G, check)
    local classic = setup()
    Weapons.give(classic, fourth.id)
    classic:shoot()
    for _, slot in ipairs({ 3, 4 }) do
      classic.weapon = slot
      labels = {}
      Skin.text = function(t, ...)
        labels[t] = true
        return originalText(t, ...)
      end
      local Integrity = require('src.session.integrity')
      local beforeDraw = Integrity.capture(classic)
      renderer:draw(classic, 1280, 720)
      UI.draw(classic, 1280, 720)
      Skin.text = originalText
      local selected = slot == 3 and '3  FIRE TEST' or '4  FOURTH'
      check('classic HUD renders the selected slot ' .. slot, labels[selected])
      check(
        'full renderer preserves simulation with slot ' .. slot,
        not Integrity.difference(beforeDraw, Integrity.capture(classic))
      )
    end
    Weapons.registry:unregister(fourth.id)
  end)
  Skin.text = originalText
  Weapons.registry:unregister(id)
  Weapons.registry:unregister('trial_multifire')
  Weapons.registry:unregister('trial_fourth')
  Snapshot.invalidateDefinitions()
  assert(ok, reason)
  check(
    'only the two shipped guns remain and their data is unchanged',
    Weapons.count() == 2 and not Weapons.registry:has(id) and Serialize.encode(parent) == before
  )
  return lines
end
return Tests
