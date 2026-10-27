-- External profile facts are explicit journal inputs; replay has no durable writes.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(Game)
  local Journal = require('src.session.journal')
  local Encounter = require('src.session.encounter')
  local Pools = require('src.session.world')
  local RunSave = require('src.storage.run_save')
  local Save = require('src.storage.save')
  local Execution = require('src.storage.execution')
  local Integrity = require('src.session.integrity')
  local Report = require('src.app.session_report')
  local lines = {}
  local check = Fixtures.checker(lines, 'replay IO: ', 'replay IO: ')
  local read, write, append = love.filesystem.read, love.filesystem.write, love.filesystem.append
  local runWrite = RunSave.write
  local profile, reads, writes = '1000', 0, 0
  love.filesystem.read = function(path, ...)
    if path == 'best-score-v03.txt' then
      reads = reads + 1
      return profile
    end
    return read(path, ...)
  end
  love.filesystem.write = function()
    writes = writes + 1
    return true
  end
  love.filesystem.append = love.filesystem.write
  RunSave.write = function()
    writes = writes + 1
    return true
  end
  local ok, problem = xpcall(function()
    local function ending()
      local g = Game.new('classic')
      g.testing = true
      g:start()
      Pools.clear(g, 'enemies')
      Encounter.guardianFell(g)
      g.player.x, g.player.z = g.world.portal.x, g.world.portal.z
      return g
    end
    local recorded = ending()
    local journal = Journal.record(recorded)
    recorded:interact()
    Journal.stop(recorded)
    local archive = assert(Journal.decode(Journal.encode(journal)))
    profile = '2000'
    local destination = ending()
    destination.testing = false
    local before = reads
    local previousWrites = writes
    local replayOK = pcall(Journal.replay, destination, archive)
    check(
      'classic replays the original profile input after disk data changes',
      replayOK and destination.modeData.bestScore == 1000 and reads == before
    )
    check(
      'classic replay also refuses its profile write without the testing flag',
      writes == previousWrites
    )
    check(
      'external profile input survives encoding as plain data',
      #archive.externalInputs == 1
        and archive.externalInputs[1].name == 'classic.bestScore'
        and archive.externalInputs[1].value == 1000
    )
    local expedition = Game.new('descent')
    local log = Journal.record(expedition)
    expedition:start()
    Journal.stop(expedition)
    local replay = Game.new('descent')
    before = writes
    Journal.replay(replay, assert(Journal.decode(Journal.encode(log))))
    check(
      'replaying an expedition cannot commit a checkpoint without the testing flag',
      not replay.testing and writes == before
    )

    -- A failed write is an external result too: it may set saveWarning, but
    -- replay must reproduce the result without retrying the write on this disk.
    RunSave.write = function()
      writes = writes + 1
      return false, 'fixture disk unavailable'
    end
    local failingSave = Game.new('descent')
    local failureLog = Journal.record(failingSave)
    failingSave:start()
    Journal.stop(failingSave)
    local failureReplay = Game.new('descent')
    before = writes
    Journal.replay(failureReplay, assert(Journal.decode(Journal.encode(failureLog))))
    check(
      'failed checkpoint receipt replays without a second disk attempt',
      failureReplay.saveWarning == 'fixture disk unavailable' and writes == before
    )

    -- Both malformed inputs and a runtime failure leave the IO policy usable.
    local malformed = assert(Journal.decode(Journal.encode(archive)))
    malformed.externalInputs[1].value = {}
    local untouched = ending()
    local initial = Integrity.capture(untouched)
    check(
      'malformed external inputs fail preflight before changing the destination',
      not pcall(Journal.replay, untouched, malformed)
        and not Integrity.difference(initial, Integrity.capture(untouched))
    )
    local failing = ending()
    failing.testing = false
    local blockedSave, blockedReport = false, false
    failing.interact = function(self)
      blockedSave = not Save.write('replay-io-must-not-exist', 'fixture')
      blockedReport = not Report.write(self, 'fixture replay')
      error('fixture replay failure')
    end
    before = writes
    local failed, message = pcall(Journal.replay, failing, archive)
    check(
      'replay blocks low-level saves and synchronous telemetry before an error',
      not failed
        and tostring(message):find('fixture replay failure', 1, true)
        and blockedSave
        and blockedReport
        and writes == before
    )
    check('runtime failure releases the replay write guard', Execution.canWrite(failing))

    local outer = Execution.beginReplay(failing, {})
    local inner = Execution.beginReplay(untouched, {})
    inner()
    local outerStillBlocked = not Execution.canWrite(failing)
    outer()
    check(
      'nested replay cleanup preserves the enclosing read-only scope',
      outerStillBlocked and Execution.canWrite(failing)
    )

    local legacy = assert(Journal.decode(Journal.encode(log)))
    legacy.externalInputs = nil
    local oldReplay = Game.new('descent')
    before = writes
    check(
      'older journals without external reads retain their no-write replay',
      pcall(Journal.replay, oldReplay, legacy) and writes == before
    )
    legacy = assert(Journal.decode(Journal.encode(archive)))
    legacy.externalInputs = nil
    before = reads
    local oldWinner = ending()
    local oldOK, oldReason = pcall(Journal.replay, oldWinner, legacy)
    check(
      'older wins lacking the profile fact fail explicitly instead of reading current disk',
      not oldOK
        and tostring(oldReason):find('journal lacks external input classic.bestScore', 1, true)
        and reads == before
        and Execution.canWrite()
    )
  end, debug.traceback)
  love.filesystem.read, love.filesystem.write, love.filesystem.append, RunSave.write =
    read, write, append, runWrite
  assert(ok, problem)
  return lines
end
return Tests
