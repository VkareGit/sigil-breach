-- Extension fixture called while extension.lua has its test-only spark
-- registered. Equipment stays data: slots, saves, casting and physical throws.
local Fixtures = require('tests.support.fixtures')
local Abilities = require('src.content.abilities')
local Save = require('src.storage.run_save')
local Run = require('src.run.descent')
local Action = require('src.content.defs.action')
local Schema = require('src.core.schema')
local Tests = {}

function Tests.run(G, check, spark)
  local run = Fixtures.expedition(G)
  Abilities.give(run, spark.id)
  local uses, slots = Abilities.inventory(run)
  run.run.checkpoint.abilities, run.run.checkpoint.abilityLoadout = uses, slots
  -- The current loadout differs from its checkpoint, and its first slot is
  -- not powder. Neither a sorted dictionary nor defaults can recover it.
  run.player.abilities = { spark.id, 'powder' }
  run.player.abilityState[spark.id].uses = 1
  run.player.abilityState.powder.uses = 0
  local snapshot = Run.snapshot(run)
  -- As 0.32 wrote it: the adapter reads SIGIL08 into the same checkpoint.
  local encoded = require('tests.support.legacy_save').encode08(snapshot, 7)
  local saved = assert(Save.decode(encoded))
  local restored = Fixtures.expedition(G)
  Run.load(restored, saved)
  check(
    'equipment save restores chosen slots and remaining uses, including zero',
    saved.version == 'SIGIL08'
      and table.concat(restored.player.abilities, ',') == 'trial_spark,powder'
      and restored.player.abilityState[spark.id].uses == 1
      and restored.player.abilityState.powder.uses == 0
  )
  local defeated = assert(Save.decode(encoded))
  defeated.phase = 'defeated'
  local retried = Fixtures.expedition(G)
  Run.load(retried, defeated)
  check(
    'a defeated save restores the checkpoint equipment, independently of current slots',
    table.concat(retried.player.abilities, ',') == 'powder,trial_spark'
      and retried.player.abilityState[spark.id].uses == 2
      and retried.player.abilityState.powder.uses == 2
  )

  local payload = assert(encoded:match('^SIGIL08\n%d+\n%d+\n(.*)$'))
  local function withPayload(text, version)
    return (version or 'SIGIL08') .. '\n7\n' .. Save.checksum(text) .. '\n' .. text
  end
  local old = payload:gsub('\nslots=[^\n]*', ''):gsub('\ncheckslots=[^\n]*', '')
  local previous = assert(Save.decode(withPayload(old, 'SIGIL07')))
  local migrated = Fixtures.expedition(G)
  Run.load(migrated, previous)
  check(
    'SIGIL07 keeps uses and migrates unordered equipment with powder on Q',
    table.concat(migrated.player.abilities, ',') == 'powder,trial_spark'
      and migrated.player.abilityState.powder.uses == 0
      and migrated.player.abilityState[spark.id].uses == 1
  )
  local withoutKit = old:gsub('\nkit=[^\n]*', ''):gsub('\ncheckkit=[^\n]*', '')
  local missingOldKit = assert(Save.decode(withPayload(withoutKit, 'SIGIL07')))
  check(
    'old saves without a kit retain their historical powder default',
    table.concat(missingOldKit.inventory.abilityLoadout, ',') == 'powder'
      and missingOldKit.inventory.abilities.powder == Abilities:get('powder').start
  )
  for _, invalid in ipairs({
    'trial_spark,trial_spark',
    'trial_spark,unknown_equipment',
    'trial_spark',
    '',
    'trial_spark,,powder',
  }) do
    local changed = payload:gsub('\nslots=[^\n]*', '\nslots=' .. invalid)
    check(
      'equipment save rejects malformed slots: ' .. invalid,
      not Save.decode(withPayload(changed))
    )
  end
  local missingSlots = payload:gsub('\nslots=[^\n]*', '')
  check('SIGIL08 requires its slot record', not Save.decode(withPayload(missingSlots)))
  local staleKit = payload:gsub('\nkit=[^\n]*', '\nkit=powder:0,removed_equipment:1')
  check(
    'equipment save refuses an unknown saved definition',
    not Save.decode(withPayload(staleKit))
  )
  local duplicateKit = payload:gsub('\nkit=[^\n]*', '\nkit=powder:0,powder:0,trial_spark:1')
  check('equipment save refuses repeated use records', not Save.decode(withPayload(duplicateKit)))
  local staleUses = payload:gsub('\nkit=[^\n]*', '\nkit=powder:0,trial_spark:3')
  check(
    'equipment save refuses uses above the current definition capacity',
    not Save.decode(withPayload(staleUses))
  )
  local empty = Fixtures.expedition(G)
  Abilities.restore(empty, {}, {})
  local emptySave = assert(Save.decode(Save.encode(Run.snapshot(empty), 1)))
  Run.load(empty, emptySave)
  check('an explicitly empty equipment loadout stays empty', #empty.player.abilities == 0)

  -- The journal may begin from a checkpoint. Rebuild that same initial
  -- checkpoint, then replay its commands and compare full simulation state.
  local Journal = require('src.session.journal')
  local Integrity = require('src.session.integrity')
  local function ready()
    local g = Fixtures.expedition(G)
    Run.load(g, assert(Save.decode(encoded)))
    Run.ready(g)
    g.run.phase = 'wave'
    g.run.spawnTimer = 100
    local enemy = g:spawn('imp', g.player.x, g.player.z - 4)
    enemy.awake = false
    g.player.yaw, g.player.pitch = math.pi, 0
    return g, enemy
  end
  local recorded, target = ready()
  local journal = Journal.record(recorded)
  check('restored first-slot equipment casts its own projectile', recorded:cast(1))
  for _ = 1, 30 do
    recorded:update(1 / 120, {})
  end
  Journal.stop(recorded)
  local replayed = ready()
  Journal.replay(replayed, Journal.decode(Journal.encode(journal)))
  check(
    'restored equipment replays its cast, hit and exact final state',
    target.hp < target.maxHp
      and not Integrity.difference(Integrity.capture(recorded), Integrity.capture(replayed))
  )

  -- Definitions fail at authoring time. A missing behaviour also fails before
  -- spending a use, starting a cooldown or creating a projectile.
  for _, change in ipairs({
    { action = { kind = 'missing_kind' } },
    { capacity = 1.5 },
    { start = 0.5 },
    { start = 3 },
  }) do
    local bad = Schema.copy(spark)
    bad.id = 'trial_bad'
    for key, value in pairs(change) do
      bad[key] = value
    end
    check(
      'invalid equipment data is rejected before registration',
      not pcall(Abilities.define, bad)
    )
    check('rejected equipment leaves no registry entry', not Abilities:has('trial_bad'))
  end
  local unsupported = Schema.copy(spark)
  unsupported.id = 'trial_unsupported'
  unsupported.action =
    Action.leap({ id = 'trial_leap', range = 4, windup = 0, packet = { base = 1, impact = 1 } })
  local unsupportedSession = Fixtures.arena(G)
  Abilities.define(unsupported)
  local started, startupError = pcall(Fixtures.arena, G)
  check(
    'a new session rejects equipment without an executable delivery',
    not started and tostring(startupError):find('kind leap cannot be cast', 1, true)
  )
  local slot = Abilities.give(unsupportedSession, unsupported.id)
  local state = unsupportedSession.player.abilityState[unsupported.id]
  local before = state.uses
  local ok, reason = pcall(unsupportedSession.cast, unsupportedSession, slot)
  check(
    'unsupported equipment delivery fails clearly before mutation',
    not ok
      and tostring(reason):find('unsupported delivery kind leap', 1, true)
      and state.uses == before
      and state.readyAt == 0
      and #unsupportedSession.bullets == 0
  )
  Abilities:unregister(unsupported.id)

  -- Two definitions share the throw behaviour without sharing their tuning.
  -- Keep the trial beside two bodies: only one lies inside its small blast.
  local trial = Schema.copy(Abilities:get('powder'))
  Fixtures.words({ trial_charge = 'TRIAL CHARGE', trial_charge_short = 'TRIAL' })
  trial.id, trial.name, trial.tag = 'trial_charge', 'trial_charge', 'trial_charge_short'
  trial.action.id = trial.id
  trial.action.speed, trial.action.lift, trial.action.fuse = 0, 0, 0.12
  trial.action.radius = 1.2
  trial.action.blast.base, trial.action.blast.impact = 20, 0
  trial.action.blast.damageType = 'physical'
  trial.action.blast.falloffStart, trial.action.blast.falloffEnd = 0, 1.2
  trial.action.blast.minPower = 1
  trial.action.selfBlast.base, trial.action.selfBlast.impact = 0, 0
  local invalidThrow = Schema.copy(trial)
  invalidThrow.action.referenceGravity = 0
  check(
    'a throw rejects a zero gravity reference before registration',
    not pcall(Abilities.define, invalidThrow)
  )
  trial = Abilities.define(trial)
  local throwing = Fixtures.arena(G)
  local throwSlot = Abilities.give(throwing, trial.id)
  local near = throwing:spawn('imp', 16, 21.5)
  local far = throwing:spawn('imp', 16, 23.5)
  near.awake, far.awake = false, false
  local nearHealth, farHealth = near.hp, far.hp
  check('a second throw casts through the common caster', throwing:cast(throwSlot))
  local charge = throwing.charges[1]
  check(
    'the second throw carries its own flight and fuse data',
    charge.action == trial.action
      and charge.fuse == 0.12
      and charge.vx == 0
      and charge.vy == 0
      and charge.vz == 0
  )
  charge.x, charge.y, charge.z = 16, 1, 21
  local Snapshot = require('src.session.snapshot')
  Snapshot.invalidateDefinitions()
  local rewind = Snapshot.capture(throwing)
  Snapshot.restore(throwing, rewind)
  near, far = throwing.enemies[1], throwing.enemies[2]
  check(
    'an in-flight throw keeps its definition after snapshot restore',
    throwing.charges[1].action == trial.action
  )
  local Explosives = require('src.combat.explosives')
  Explosives.update(throwing, 0.1)
  check('the second throw waits for its own fuse', #throwing.charges == 1 and near.hp == nearHealth)
  Explosives.update(throwing, 0.02)
  near, far = throwing.enemies[1], throwing.enemies[2]
  check(
    'its own fuse, radius and damage resolve without powder tuning',
    #throwing.charges == 0
      and math.abs(nearHealth - near.hp - 20) < 1e-9
      and far.hp == farHealth
      and throwing.explosionReport.targets == 1
  )
  check('ordinary powder still launches with its original definition', throwing:cast(1))
  check(
    'ordinary powder keeps its original fuse and blast radius',
    throwing.charges[1].action == Abilities:get('powder').action
      and throwing.charges[1].fuse == 1
      and throwing.charges[1].action.radius == 4
  )
  Abilities:unregister(trial.id)
  Snapshot.invalidateDefinitions()
end

return Tests
