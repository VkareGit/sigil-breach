local Fixtures = require('tests.support.fixtures')
local Test = {}
function Test.run(Game)
  local Journal = require('src.session.journal')
  local Values = require('src.session.journal_values')
  local Observation = require('src.combat.observation')
  local Serialize = require('src.core.serialize')
  local lines = {}
  local check = Fixtures.checker(lines, 'journal values: ', 'journal values: ')
  local archive = { observations = {} }
  local pack = Values.writer(archive, function(list, value)
    list[#list + 1] = value
  end)
  local observation = {
    version = 1,
    session = 1,
    generation = 0,
    sequence = 1,
    origin = { 0, 1, 0 },
    bodies = { { id = 1, x = 4 } },
  }
  local first = pack({ observation = observation })
  local duplicate = pack({ observation = Observation.copy(observation) })
  check(
    'the same display is stored once across distinct input copies',
    #archive.observations == 1
      and first.observation._journalObservation == duplicate.observation._journalObservation
  )
  observation.bodies[1].x = 7
  local changed = pack({ observation = observation })
  check(
    'equal IDs cannot alias different geometry',
    #archive.observations == 2
      and changed.observation._journalObservation ~= first.observation._journalObservation
  )
  local replayInput = Values.expand(first, archive.observations)
  replayInput.observation.bodies[1].x = 99
  check(
    'archive is detached from both source and replay mutation',
    archive.observations[1].bodies[1].x == 4 and archive.observations[2].bodies[1].x == 7
  )
  check(
    'missing references fail before a command executes',
    not pcall(Values.expand, { _journalObservation = 3 }, archive.observations)
  )
  check(
    'ambiguous references fail',
    not pcall(Values.expand, { _journalObservation = 1, body = {} }, archive.observations)
  )
  local function fresh()
    local g = Game.new('floor')
    g.ephemeral, g.state, g.enemies = true, 'playing', {}
    return g
  end
  local g = fresh()
  local journal = Journal.record(g)
  local shown = Observation.capture(g)
  for _ = 1, 8 do
    g:update(1 / 120, { shoot = true, fireCommand = Observation.command(shown, g) })
  end
  Journal.stop(g)
  check('real repeated displayed input uses one pooled observation', #journal.observations == 1)
  local text = Journal.encode(journal)
  local loaded = Journal.decode(text)
  check(
    'v5 round trip replays the exact final state and receipts',
    loaded.header.version == 5 and pcall(Journal.replay, fresh(), loaded)
  )
  -- Exercise the actual v4 decoder route, not a current-format archive
  -- carrying an obsolete test label. This trial has only the default actor.
  local v4, v4Game = Observation.copy(loaded), fresh()
  v4.header.version = 4
  local v4OK = pcall(Journal.replay, v4Game, v4)
  local Integrity = require('src.session.integrity')
  check(
    'v4 pooled journals replay to exactly the current-format final state',
    v4OK and not Integrity.difference(Integrity.capture(g), Integrity.capture(v4Game))
  )
  local legacy = Observation.copy(loaded)
  legacy.header.version = 2
  legacy.observations = nil
  for _, entry in ipairs(legacy.entries) do
    if entry[1] == 'set' then
      entry[3] = Values.expand(entry[3], loaded.observations, loaded.bodies)
    elseif entry[1] ~= 'aim' then
      entry[2] = Values.expand(entry[2], loaded.observations, loaded.bodies)
    end
  end
  check(
    'v2 expanded journals from the same build remain readable',
    pcall(Journal.replay, fresh(), legacy)
  )
  check('sharing reduces serialized command geometry', #text < #Serialize.encode(legacy))
  local foreign = Observation.copy(loaded)
  foreign.header.sourceFingerprint = 'another-source-tree'
  local untouched = fresh()
  local before = require('src.session.integrity').capture(untouched)
  check(
    'same version from different sources is rejected before changing the session',
    not pcall(Journal.replay, untouched, foreign)
      and not require('src.session.integrity').difference(
        before,
        require('src.session.integrity').capture(untouched)
      )
  )
  local forged = Observation.copy(loaded)
  forged.entries = { { 'spawn', { 'imp', 5, 5 } } }
  check('replay permits player commands only', not pcall(Journal.replay, fresh(), forged))
  forged.entries = { { 'set', 'world', {} } }
  check(
    'replay cannot replace arbitrary session fields',
    not pcall(Journal.replay, fresh(), forged)
  )
  local function rejectedUntouched(name, change)
    local candidate, destination = Observation.copy(loaded), fresh()
    destination._observationSession, destination._observationGeneration = 987, 654
    local before = require('src.session.integrity').capture(destination)
    change(candidate)
    check(
      name,
      not pcall(Journal.replay, destination, candidate)
        and destination._observationSession == 987
        and destination._observationGeneration == 654
        and not require('src.session.integrity').difference(
          before,
          require('src.session.integrity').capture(destination)
        )
    )
  end
  rejectedUntouched('foreign build leaves the input namespace untouched', function(value)
    value.header.build = 'foreign'
  end)
  rejectedUntouched('unsupported format leaves the input namespace untouched', function(value)
    value.header.version = 999
  end)
  rejectedUntouched('a late missing reference fails before earlier valid commands', function(value)
    value.entries = {
      { 'look', { 0.4, 0.2 } },
      { 'update', { 1 / 120, { fireCommand = { observation = { _journalObservation = 999 } } } } },
    }
  end)
  rejectedUntouched('a late forbidden command fails before earlier valid commands', function(value)
    value.entries = { { 'look', { 0.4, 0.2 } }, { 'spawn', { 'imp', 5, 5 } } }
  end)
  rejectedUntouched('fractional pooled references are rejected', function(value)
    value.entries = { { 'update', { 1 / 120, { observation = { _journalObservation = 0.5 } } } } }
  end)
  rejectedUntouched('cycles in pooled geometry are rejected before replay', function(value)
    value.observations[1].bodies[1] = value.observations[1]
  end)
  rejectedUntouched('non-finite command data is rejected before replay', function(value)
    value.entries[1] = { 'look', { math.huge } }
  end)
  rejectedUntouched('sparse entry arrays cannot silently truncate replay', function(value)
    value.entries = { [2] = { 'look', { 0.1 } } }
  end)
  for _, limit in ipairs({ 'commands', 'bytes' }) do
    local bounded = fresh()
    local log = Journal.record(bounded, {
      maxCommands = limit == 'commands' and 3 or 100,
      maxBytes = limit == 'bytes' and 1 or 10000000,
    })
    for _ = 1, 8 do
      bounded:update(
        1 / 120,
        { fireCommand = Observation.command(Observation.capture(bounded), bounded) }
      )
    end
    local count = limit == 'commands' and 3 or 1
    check(
      limit .. ' limit also bounds new pooled displays after stop',
      log.stopped == 'limit' and log.commands == count and #log.observations == count
    )
    Journal.stop(bounded)
  end
  check(
    'infinite recording ceilings cannot disable the bounded recorder',
    not pcall(Journal.record, fresh(), { maxBytes = math.huge, maxCommands = math.huge })
  )
  local weak = setmetatable({}, { __mode = 'v' })
  do
    local unowned = fresh()
    weak.session, weak.journal = unowned, Journal.record(unowned)
  end
  collectgarbage('collect')
  collectgarbage('collect')
  check(
    'abandoned active recorder cannot retain its session through weak-key callback indexes',
    weak.session == nil and weak.journal == nil
  )
  local live = fresh()
  local liveLog = Journal.record(live)
  collectgarbage('collect')
  collectgarbage('collect')
  live:update(1 / 120, {})
  local exported = Journal.decode(Journal.encode(liveLog))
  check(
    'a live session keeps recorder callbacks across collection',
    exported.commands == 1 and exported.final and pcall(Journal.replay, fresh(), exported)
  )
  Journal.stop(live)
  -- Verify the signed-build side even in an intentionally unfingerprinted
  -- local focused run. A separate module instance borrows an isolated Build;
  -- the shared production Build object and live Journal are never mutated.
  local buildModule, journalModule =
    package.loaded['src.core.build'], package.loaded['src.session.journal']
  package.loaded['src.core.build'] =
    { version = Journal.build, sourceFingerprint = string.rep('a', 64), provenance = 'qa-fixture' }
  package.loaded['src.session.journal'] = nil
  local moduleOK, Verified = pcall(require, 'src.session.journal')
  package.loaded['src.core.build'], package.loaded['src.session.journal'] =
    buildModule, journalModule
  assert(moduleOK, Verified)
  local verifiedGame = fresh()
  local verifiedLog = Verified.record(verifiedGame)
  verifiedGame:update(1 / 120, {})
  Verified.stop(verifiedGame)
  local signedV2 = Observation.copy(verifiedLog)
  signedV2.header.version = 2
  check(
    'same-source v2 metadata remains compatible in a verified build',
    pcall(Verified.replay, fresh(), signedV2)
  )
  verifiedLog.header.sourceFingerprint = nil
  check(
    'deleting fingerprint cannot bypass a verified build identity check',
    not pcall(Verified.replay, fresh(), verifiedLog)
  )
  return lines
end
return Test
