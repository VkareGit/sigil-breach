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
  Fixtures.words({
    trial_firearm = 'TRIAL FIREARM',
    trial_firearm_kind = 'CARBINE',
    trial_firearm_tab = 'FIRE TEST',
    trial_firearm_draw = 'trial firearm',
    trial_fourth_tab = 'FOURTH',
  })
  local def = Weapons.define({
    extends = parent,
    id = id,
    name = 'trial_firearm',
    art = 'judge',
    hud = {
      title = 'trial_firearm',
      kind = 'trial_firearm_kind',
      tab = 'trial_firearm_tab',
      draw = 'trial_firearm_draw',
    },
    ammo = { kind = 'magazine', capacity = 4, startReserve = 8, maxReserve = 16, packSize = 4 },
    cycle = 0.3,
    range = 12,
    reload = { mechanism = 'cylinder' },
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
    bad.id = 'trial_invalid'
    bad.attack.pierce = { bodies = 1.5, retain = 0.5, armorCost = 0, minRetain = 0.1 }
    check(
      'a fractional count of pierced bodies fails on a finite round too',
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
      g.player.cooldown, g.elapsed = 0, 1
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
        and g.player.hits == 1
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
    many.player.weapon, many.player.cooldown = 4, 0
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
    check('several finite pellets count as a single successful trigger pull', many.player.hits == 1)
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
    local run = Fixtures.started(G)
    Weapons.give(run, id)
    run:switchWeapon(3)
    run.player.cooldown = 0
    Weapons.state(run).mag = 0
    check('existing reload mechanism works for the new delivery', run:reloadGun())
    for _ = 1, 400 do
      run:update(1 / 120, {})
    end
    check(
      'reload fills its own capacity from its reserve',
      Weapons.state(run).mag == 4 and Weapons.state(run).reserve == 4
    )
    local loaded = run
    loaded.player.weapon = 3
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
    check(
      'painted UI bounds remain valid with a third weapon',
      (Skin.auditFailureCount or 0) == auditBefore
    )
    check(
      'renderer uses the declared hands and animation atlas',
      require('src.render.weapon_art').idOf(loaded) == 'judge'
        and require('src.render.weapon_art').frame(loaded) >= 1
    )
    local fourth =
      Weapons.define({ extends = def, id = 'trial_fourth', hud = { tab = 'trial_fourth_tab' } })
    Snapshot.invalidateDefinitions()
    require('tests.cases.content_schema').run(G, check)
    local classic = setup()
    Weapons.give(classic, fourth.id)
    classic:shoot()
    for _, slot in ipairs({ 3, 4 }) do
      classic.player.weapon = slot
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
  -- A tube filled round by round (PLAN Z9): its mechanism is data and its stages a reload
  -- stage kind, entries of registries only. A pull between rounds stops the reload and fires
  -- what went in; the reload ends when it is full; a save in the middle goes on the same.
  local Reloads = require('src.content.reloads')
  local Reload = require('src.combat.reload')
  local Save = require('src.storage.save')
  local DataReader = require('src.core.data_reader')
  local cylinder = Reloads:get('cylinder')
  local tube = 'trial_tube'
  local tubeOK, tubeProblem = pcall(function()
    Reloads:register(tube, {
      duration = 1.6,
      stages = {
        { at = 0.3, name = 'round', kind = 'round' },
        { at = 0.6, name = 'round', kind = 'round' },
        { at = 0.9, name = 'round', kind = 'round' },
        { at = 1.2, name = 'round', kind = 'round' },
      },
      resume = {},
      interruptBefore = 1.6,
      labels = { { math.huge, 'reload_load' } },
      sounds = { round = cylinder.sounds.load },
      voices = { round = cylinder.voices.load },
    })
    Weapons.define({
      extends = Weapons.get('judge'),
      id = tube,
      ammo = { kind = 'magazine', capacity = 4, startReserve = 8, maxReserve = 16, packSize = 4 },
      reload = { mechanism = tube, speed = 1 },
      fire = { autoReload = false },
    })
    Snapshot.invalidateDefinitions()
    local function armed()
      local g = Fixtures.started(G)
      g:switchWeapon(Weapons.give(g, tube))
      g.player.cooldown = 0
      Weapons.state(g).mag = 0
      return g
    end
    local function run(g, seconds)
      for _ = 1, math.floor(seconds * 120 + 0.5) do
        g:update(1 / 120, {})
      end
    end
    local g = armed()
    local heard = {}
    g.bus:on('sim', 'ReloadStage', function(event)
      heard[#heard + 1] = event
    end)
    check('a tube starts its reload', g:reloadGun())
    run(g, 0.35)
    check(
      'its first round goes in alone',
      Weapons.state(g).mag == 1 and #heard == 1 and heard[1].stage == 'round'
    )
    g.player.cooldown = 0
    check(
      'a pull between rounds stops the reload and fires the round in it',
      g:shoot() and Weapons.state(g).mag == 0 and Reload.left(g) == 0
    )
    check('it is filled again round by round', g:reloadGun())
    run(g, 1.25)
    check(
      'and the reload ends when it is full, before its timeline',
      Weapons.state(g).mag == 4
        and Weapons.state(g).reserve == 3
        and Reload.left(g) == 0
        and heard[#heard].finished == true
    )
    -- Saved in the middle of its reload and taken up in a fresh session.
    local played, saved = armed(), armed()
    played:reloadGun()
    saved:reloadGun()
    run(played, 0.65)
    run(saved, 0.65)
    local section = Save.section('pools')
    local text = Serialize.encode(section.pack(saved))
    local again = Fixtures.started(G)
    section.restore(again, section.unpack(assert(DataReader.decode(text, Save.limits))))
    check(
      'a save in the middle of a reload keeps it',
      Reload.left(again) == Reload.left(played) and Weapons.state(again).mag == 2
    )
    run(played, 0.7)
    run(again, 0.7)
    check(
      'and it goes on the same',
      Weapons.state(again).mag == Weapons.state(played).mag
        and Weapons.state(again).mag == 4
        and Reload.left(again) == 0
    )
  end)
  Weapons.registry:unregister(tube)
  Reloads:unregister(tube)
  Snapshot.invalidateDefinitions()
  check(
    'a tube filled round by round holds' .. (tubeOK and '' or ': ' .. tostring(tubeProblem)),
    tubeOK
  )
  return lines
end
return Tests
