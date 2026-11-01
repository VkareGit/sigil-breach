-- E10: the session as a memento (capture / restore) and as a journal of
-- commands (record / replay). Both must reproduce the simulation bit for bit.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G)
  local lines = {}
  local check = Fixtures.checker(lines, 'replay: ', 'replay: ')
  local Golden = require('qa.golden')
  local Drill = require('qa.scenarios.drill')
  local Snapshot = require('src.session.snapshot')
  local Journal = require('src.session.journal')
  local seconds = 12

  -- Content tools may append definitions to an already loaded module before a
  -- session uses them. Such registration explicitly invalidates the index; plain
  -- repeated capture/restore shares definitions and still isolates mutable state.
  -- Temporarily occupy a real content-module slot: no fake production module
  -- and no require of a synthetic fixture. Restore it even if a check fails.
  local contentName = 'src.content.enemies'
  local previousContent = package.loaded[contentName]
  local ok, reason = pcall(function()
    local content = { existing = { hp = 80 } }
    package.loaded[contentName] = content
    local source = { profile = content.existing, health = { current = 62 } }
    local first = Snapshot.capture(source)
    local second = Snapshot.capture(source)
    local restored = Snapshot.restore({}, second)
    check(
      'repeated snapshots share immutable definitions and isolate mutable state',
      first.data.profile == content.existing
        and second.data.profile == content.existing
        and restored.profile == content.existing
        and first.data.health ~= source.health
        and second.data.health ~= first.data.health
        and restored.health ~= second.data.health
        and restored.health.current == 62
    )
    content.added = { attack = { damage = 17 } }
    Snapshot.invalidateDefinitions()
    local extended = Snapshot.capture({ profile = content.existing, attack = content.added.attack })
    local extendedState = Snapshot.restore({}, extended)
    check(
      'explicit invalidation shares newly registered nested definitions',
      extended.data.attack == content.added.attack
        and extendedState.attack == content.added.attack
        and extendedState.profile == content.existing
        and Snapshot.restore({}, first).profile == content.existing
    )
    -- Module replacement between sessions must refresh even if module count is
    -- unchanged. Replacing definitions is not a migration of the earlier session.
    local replacement = { existing = { hp = 95 } }
    package.loaded[contentName] = replacement
    local replaced = Snapshot.capture({ profile = replacement.existing })
    check(
      'same-count content module replacement refreshes the shared index',
      replaced.data.profile == replacement.existing
        and Snapshot.restore({}, replaced).profile == replacement.existing
    )
  end)
  package.loaded[contentName] = previousContent
  Snapshot.invalidateDefinitions()
  assert(ok, reason)

  -- Memento: rewind to second 6 and play the second half again.
  local g = Drill.setup(G)
  Drill.play(g, nil, 6)
  local memento = Snapshot.capture(g)
  local midway = Golden.digest(g)
  Drill.play(g, nil, seconds, 6 * Drill.rate + 1)
  local straight = Golden.digest(g)
  check('the second half changes the fight', straight ~= midway)
  Snapshot.restore(g, memento)
  check('a restored session is the captured one', Golden.digest(g) == midway)
  Drill.play(g, nil, seconds, 6 * Drill.rate + 1)
  check('a rewound session plays the same second half', Golden.digest(g) == straight)
  check(
    'definitions are shared by a snapshot, not copied',
    memento.data.enemies[1] ~= g.enemies[1]
      and require('src.combat.rules').archetype(g.enemies[1])
        == require('src.content.enemies').get(g.enemies[1].kind)
  )
  local other = Drill.setup(G)
  Snapshot.restore(other, memento)
  Drill.play(other, nil, seconds, 6 * Drill.rate + 1)
  check('a snapshot restores into another session too', Golden.digest(other) == straight)

  -- Journal: record the drill, write it as text, replay it on a fresh session.
  local recorded = Drill.setup(G)
  local journal = Journal.record(recorded)
  Drill.play(recorded, nil, seconds)
  Journal.stop(recorded)
  check('recording leaves the session plain again', rawget(recorded, 'update') == nil)
  local text = Journal.encode(journal)
  local loaded = Journal.decode(text)
  check('journal contains resolved hit receipts', #loaded.receipts > 0)
  check(
    'a journal is text that reads back whole',
    loaded and #loaded.entries == #journal.entries and #journal.entries > seconds * Drill.rate
  )
  local replayed = Journal.replay(Drill.setup(G), loaded)
  local corrupted = Journal.decode(text)
  corrupted.receipts[1] = 'corrupted contact'
  local accepted, diagnostic = pcall(Journal.replay, Drill.setup(G), corrupted)
  check(
    'hit receipt mismatch identifies the first divergent contact',
    not accepted and tostring(diagnostic):find('hit receipt 1 differs', 1, true) ~= nil
  )
  check(
    'a replayed journal reproduces the recorded fight bit for bit',
    Golden.digest(replayed) == Golden.digest(recorded)
  )
  local plain = Drill.run(G, nil, seconds)
  check(
    'recording does not change what it records',
    Golden.digest(plain) == Golden.digest(recorded)
  )
  -- A journal names its session: a recorded game rebuilds and replays alone.
  local live = G.new('floor')
  live.testing = true
  local log = Journal.record(live)
  live:start()
  for tick = 1, 240 do
    live.player.yaw = live.player.yaw + 0.01
    live:update(1 / 120, { forward = 1, shoot = tick % 40 == 0 })
  end
  Journal.stop(live)
  local again = Journal.session(G, Journal.decode(Journal.encode(log)))
  again.testing = true
  Journal.replay(again, Journal.decode(Journal.encode(log)))
  check(
    'a journal rebuilds its own session (mode, map) and replays it exactly',
    log.header.mode == 'floor' and Golden.digest(again) == Golden.digest(live)
  )
  -- The proving ground (plan v7 H0): catalogue actions (targets, tier, god
  -- mode, reset) are session commands, and what the application sets between
  -- commands (a pause) is in the journal too.
  local Field = require('src.run.test_field')
  local field = Field.new(G)
  field.testing = true
  local fieldLog = Journal.record(field)
  field:act('catalog', 'field_god')
  field:act('catalog', 'field_spawn_imp_3')
  local function fight(ticks)
    for tick = 1, ticks do
      field.player.yaw = field.player.yaw + 0.004
      field:update(1 / 120, { shoot = tick % 50 == 0, strafe = tick % 90 < 30 and 1 or 0 })
    end
  end
  fight(300)
  field.state = 'paused'
  fight(30)
  field.state = 'playing'
  fight(120)
  field:act('catalog', 'field_reset')
  field:act('catalog', 'field_spawn_furfur_1')
  fight(240)
  Journal.stop(field)
  local acts, sets = 0, 0
  for _, entry in ipairs(fieldLog.entries) do
    acts = acts + (entry[1] == 'act' and 1 or 0)
    sets = sets + (entry[1] == 'set' and 1 or 0)
  end
  check(
    'catalogue actions and the pause are journal entries',
    acts == 4 and sets >= 2 and fieldLog.header.mode == 'field'
  )
  local fieldText = Journal.encode(fieldLog)
  local fieldAgain = Journal.session(G, Journal.decode(fieldText))
  fieldAgain.testing = true
  Journal.replay(fieldAgain, Journal.decode(fieldText))
  check(
    'a proving-ground journal (targets, tier, god mode, pause, reset) replays exactly',
    Golden.digest(fieldAgain) == Golden.digest(field)
      and fieldAgain.testField.invincible == field.testField.invincible
      and #fieldAgain.enemies == #field.enemies
  )
  -- A journal that began mid-session refuses a fresh session instead of
  -- diverging silently.
  local late = Field.new(G)
  late.testing = true
  late:act('catalog', 'field_spawn_imp_1')
  local lateLog = Journal.record(late)
  late:update(1 / 120, {})
  Journal.stop(late)
  local fresh = Field.new(G)
  fresh.testing = true
  check(
    'a journal begun mid-session refuses a session in another state',
    not pcall(Journal.replay, fresh, lateLog)
  )
  local Integrity = require('src.session.integrity')
  local cosmeticWorld = Field.new(G)
  local beforeMesh = Integrity.capture(cosmeticWorld)
  cosmeticWorld.world.mesh, cosmeticWorld.world.meshRevision = { rendererOwned = true }, 99
  check(
    'renderer-owned world cache does not enter simulation integrity',
    not Integrity.difference(beforeMesh, Integrity.capture(cosmeticWorld))
  )
  for _, action in ipairs({ 'field_god', 'field_low' }) do
    local changed = Field.new(G)
    changed.testing = true
    changed:act('catalog', action)
    local changedLog = Journal.record(changed)
    changed:act('catalog', 'field_spawn_imp_1')
    Journal.stop(changed)
    local pristine = Field.new(G)
    pristine.testing = true
    local accepted, reason = pcall(Journal.replay, pristine, changedLog)
    check(
      'origin rejects pre-recording ' .. action .. ' with a field diagnostic',
      not accepted and tostring(reason):find('initial state differs', 1, true) ~= nil
    )
  end
  -- Actual station/catalogue commands, including buffered input, with exact
  -- gameplay data comparisons rather than the legacy partial golden digest.
  local complete = Field.new(G)
  complete.testing = true
  local completeLog = Journal.record(complete)
  for _, action in ipairs({
    'field_station_range',
    'field_freeze',
    'field_pose_next',
    'field_refill',
    'field_station_physics',
    'field_reset',
  }) do
    complete:act('catalog', action)
    complete:update(1 / 120, {})
  end
  complete.state, complete.map, complete.help = 'paused', true, true
  complete.player.fireBuffer, complete.player.jumpBuffer = 0.12, 0.08
  local exported = Journal.encode(completeLog)
  check(
    'repeat export does not append duplicate external changes',
    Journal.encode(completeLog) == exported
  )
  local rebuilt = Journal.session(G, Journal.decode(exported))
  rebuilt.testing = true
  Journal.replay(rebuilt, Journal.decode(exported))
  local difference = Integrity.difference(Integrity.capture(complete), Integrity.capture(rebuilt))
  check(
    'station replay and immediate export match full simulation data: ' .. tostring(difference),
    not difference
  )
  complete.state, complete.map, complete.help = 'playing', false, false
  complete.player.fireBuffer, complete.player.jumpBuffer = 0, 0
  Journal.stop(complete)
  local stopped = Journal.session(G, completeLog)
  stopped.testing = true
  Journal.replay(stopped, Journal.decode(Journal.encode(completeLog)))
  difference = Integrity.difference(Integrity.capture(complete), Integrity.capture(stopped))
  check(
    'stop flushes changes without another simulation tick: ' .. tostring(difference),
    not difference
  )
  local wrongBuild = Journal.decode(exported)
  wrongBuild.header.build = 'incompatible-build'
  check(
    'foreign build is refused before any replay command',
    not pcall(Journal.replay, rebuilt, wrongBuild)
  )
  local wrongVersion = Journal.decode(exported)
  wrongVersion.header.version = Journal.version + 1
  check('unknown replay format is refused', not pcall(Journal.replay, rebuilt, wrongVersion))
  local wrongFinal = Journal.decode(exported)
  wrongFinal.final['player["hp"]'] = '-1'
  local finalSession = Journal.session(G, wrongFinal)
  finalSession.testing = true
  local finalOK, finalReason = pcall(Journal.replay, finalSession, wrongFinal)
  check(
    'final simulation mismatch identifies the exact field',
    not finalOK and tostring(finalReason):find('player["hp"]', 1, true) ~= nil
  )
  local rngChanged = Field.new(G)
  rngChanged.testing = true
  rngChanged.rng.sim:random()
  check('origin includes simulation RNG state', not pcall(Journal.replay, rngChanged, completeLog))
  -- The build a journal carries is the game's own even where the application
  -- was never loaded (a tool, a headless test): a fresh load of the journal
  -- alone, with the application modules absent, stamps the release version.
  local saved = {}
  for _, name in ipairs({ 'src.session.journal', 'src.app.release', 'src.app.application' }) do
    saved[name], package.loaded[name] = package.loaded[name], nil
  end
  local alone = require('src.session.journal')
  local applicationLoaded = package.loaded['src.app.application'] ~= nil
  for name, module in pairs(saved) do
    package.loaded[name] = module
  end
  check(
    'a journal stamps the release version without the application loaded',
    not applicationLoaded
      and alone.build == require('src.app.release').version
      and Journal.header(rebuilt).build == alone.build
  )
  return lines
end
return Tests
