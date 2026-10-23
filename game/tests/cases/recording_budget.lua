-- Recording is optional and finite. A budget boundary must preserve the whole
-- command, its resolved hit receipts and its final state, while play continues.
local Fixtures = require('tests.support.fixtures')
local Journal = require('src.session.journal')
local Integrity = require('src.session.integrity')
local T = {}
function T.run(G)
  local lines = {}
  local check = Fixtures.checker(lines, 'recording budget: ', 'recording budget: ')
  local function setup()
    local g = Fixtures.arena(G)
    local e = g:spawn('imp', 16, 21)
    e.hp, e.maxHp, e.spawnAge, e.dummy = 1000, 1000, 1, true
    g.player.yaw = math.pi
    return g, e
  end
  for _, kind in ipairs({ 'commands', 'bytes' }) do
    local g, e = setup()
    local stopped = 0
    local log = Journal.record(g, {
      maxCommands = kind == 'commands' and 1 or 100,
      maxBytes = kind == 'bytes' and 1 or 1000000,
    }, function(completed)
      stopped = stopped + 1
      assert(completed.final and rawget(g, 'shoot') == nil, 'callback sees a closed recording')
    end)
    g:update(1 / 120, { shoot = true })
    check(
      kind .. ' bound closes after the complete update, nested shot and receipts',
      log.stopped == 'limit'
        and log.commands == 1
        and #log.receipts > 1
        and e.hp < 1000
        and rawget(g, 'update') == nil
        and stopped == 1
    )
    local text = Journal.encode(log)
    local replayed = Journal.replay(setup(), Journal.decode(text))
    check(
      kind .. ' bound replays its complete hit and final state',
      not Integrity.difference(Integrity.capture(g), Integrity.capture(replayed))
    )
    g:update(1 / 120, { forward = 1 })
    Journal.stop(g)
    check(
      kind .. ' bound leaves a frozen export while the live game continues',
      Journal.encode(log) == text
        and stopped == 1
        and Integrity.difference(log.final, Integrity.capture(g)) ~= nil
    )
  end

  local Application = require('src.app.application')
  local Report = require('src.app.session_report')
  local tuning = require('src.content.tuning')
  local oldLimit = tuning.recording
  local oldWrite, oldAppend, oldAfter =
    love.filesystem.write, love.filesystem.append, Report.afterWrite
  local saved = {}
  local app
  local ok, reason = pcall(function()
    tuning.recording = { maxBytes = 1000000, maxCommands = 1 }
    love.filesystem.write = function(name, text)
      saved[#saved + 1] = { name, text }
      return true
    end
    love.filesystem.append = function()
      return true
    end
    app = Application.new()
    app.qa = {
      isolated = true,
      has = function(_, flag)
        return flag == '--record' or flag == '--selftest'
      end,
    }
    Report.afterWrite = function(g)
      if app.journals and app.journals[g] then
        app:writeJournal(g)
      end
    end
    app:reset(false)
    local first = app.game
    first:start()
    local log = app.journal
    check(
      'application retains the completed journal and announces the stop',
      log
        and log.stopped == 'limit'
        and first.view.message:find('Recording stopped:', 1, true) ~= nil
    )
    first:update(1 / 120, {})
    app.input:keypressed(app, 'f9', 'f9', false)
    local loaded = Journal.decode(saved[1][2])
    local fresh = Journal.session(G, loaded)
    Journal.replay(fresh, loaded)
    check(
      'F9 after auto-stop exports the completed prefix, not the later live state',
      #saved == 1
        and loaded.stopped == 'limit'
        and not Integrity.difference(log.final, Integrity.capture(fresh))
        and Integrity.difference(log.final, Integrity.capture(first)) ~= nil
    )
    app:adopt(first)
    check(
      're-adopting the stopped session preserves its journal without resuming wrappers',
      app.journal == log and rawget(first, 'update') == nil
    )
    app:reset(false)
    check(
      'a restarted session receives a new live journal',
      app.game ~= first
        and app.journal ~= log
        and app.journal.stopped == nil
        and rawget(app.game, 'update') ~= nil
        and app.journals[first] == log
    )
    app.game:start()
    app.input:keypressed(app, 'f9', 'f9', false)
    check('F9 remains valid after restart and a second automatic stop', #saved == 2)
    local Field = require('src.run.test_field')
    local function targetField()
      local g = Field.new(G)
      Field.close(g)
      local target = g:spawn('imp', 16, 21)
      target.hp, target.spawnAge, target.dummy = 1, 1, true
      g.player.yaw = math.pi
      return g, target
    end
    for _, limited in ipairs({ false, true }) do
      tuning.recording = { maxBytes = 1000000, maxCommands = limited and 1 or 100 }
      local field, target = targetField()
      app:adopt(field)
      local before = #saved
      local inside = false
      Report.afterWrite = function(g)
        inside = true
        app:writeJournal(g)
        assert(#saved == before, 'automatic export must wait for the direct shot to complete')
      end
      field:shoot()
      local exported = Journal.decode(saved[#saved][2])
      local rebuilt = targetField()
      rebuilt.testing = true
      Journal.replay(rebuilt, exported)
      check(
        (limited and 'auto-limit' or 'active recording')
          .. ' defers a direct-kill telemetry export until all receipts and final state exist',
        inside
          and target.hp <= 0
          and #saved == before + 1
          and #exported.receipts > 1
          and not Integrity.difference(Integrity.capture(field), Integrity.capture(rebuilt))
          and (not limited or exported.stopped == 'limit')
      )
      Journal.stop(field)
    end
  end)
  if app and app.game then
    Journal.stop(app.game)
  end
  tuning.recording = oldLimit
  love.filesystem.write, love.filesystem.append, Report.afterWrite = oldWrite, oldAppend, oldAfter
  assert(ok, reason)
  return lines
end
return T
