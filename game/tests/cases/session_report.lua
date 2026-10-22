-- Real-play measurements: a cleared proving ground, a death and a wave
-- trial each leave one entry in telemetry.txt, measuring the encounter and
-- the whole run of measurements; a test session writes nothing.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G)
  local lines = {}
  local check = Fixtures.checker(lines, 'session report: ', 'session report: ')
  local Report = require('src.app.session_report')
  local Field = require('src.run.test_field')
  local Telemetry = require('src.combat.telemetry')
  local Signal = require('src.session.signal')
  local written = {}
  local append, after = love.filesystem.append, Report.afterWrite
  love.filesystem.append = function(name, text)
    written[#written + 1] = { name = name, text = text }
    return true
  end
  Report.afterWrite = nil
  local ok, err = pcall(function()
    local g = Field.new(G)
    g.testing = true
    Field.close(g)
    g.testField.invincible = false
    check('a test session writes nothing', not Report.write(g, 'F9') and #written == 0)
    g.testing = false
    local first = g:spawn('imp', 16, 20)
    local second = g:spawn('imp', 14, 20)
    g:damageEnemy(first, first.hp + 1, 'weapon')
    check('a demon down while others stand writes nothing', #written == 0)
    g:damageEnemy(second, second.hp + 1, 'weapon')
    check(
      'the last demon down writes one entry to telemetry.txt',
      #written == 1
        and written[1].name == 'telemetry.txt'
        and written[1].text:find('proving ground cleared', 1, true)
        and written[1].text:find('This encounter: [%d.]+ s; kills 2')
    )
    local third = g:spawn('imp', 16, 20)
    g:damageEnemy(third, third.hp + 1, 'weapon')
    check(
      'the next entry measures its own encounter and the whole run apart',
      #written == 2
        and written[2].text:find('This encounter: [%d.]+ s; kills 1')
        and written[2].text:find('Since the measurements began: [%d.]+ s; kills 3')
    )
    g.player.hp, g.player.armor, g.player.invuln = 1, 0, 0
    g:damagePlayer(500)
    check('a death writes one entry', #written == 3 and written[3].text:find('death', 1, true))
    Signal(g, 'WaveCleared', { wave = 2, final = false, trial = true })
    check(
      'a cleared wave trial writes one entry',
      #written == 4 and written[4].text:find('wave trial 2', 1, true)
    )
    Field.reset(g)
    check('a fresh proving ground starts its measurements anew', Telemetry.get(g).kills == 0)
    check(
      'the report names the full path of the file',
      Report.path():find('telemetry.txt', 1, true)
    )
  end)
  love.filesystem.append, Report.afterWrite = append, after
  assert(ok, err)
  return lines
end
return Tests
