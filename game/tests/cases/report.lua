-- One run shows every failure: a failing suite does not stop the ones after it, and the run
-- still fails at its end.
local F = require('tests.support.fixtures')
local Report = require('qa.report')
local T = {}
function T.run()
  local lines = {}
  local check = F.checker(lines, 'report: ', 'report: ')
  local path = love.filesystem.getSaveDirectory() .. '/report-test.txt'
  local report = Report.new(path)
  report:run('first', 'passes', function()
    return { 'PASS one' }
  end)
  report:run('second', 'fails', function()
    error('the second failure')
  end)
  report:run('third', 'passes after it', function()
    return { 'PASS two' }
  end)
  report:run('fourth', 'fails again', function()
    error('the fourth failure')
  end)
  local finished, reason = pcall(report.finish, report)
  local file = assert(io.open(path, 'r'))
  local text = file:read('*a')
  file:close()
  os.remove(path)
  check('a suite after a failure still runs', report.total == 2)
  check(
    'the run fails at its end',
    not finished and tostring(reason):find('2 suites failed', 1, true)
  )
  check('the report says so', text:find('STATUS: FAILED', 1, true))
  check('it names the first failure', text:find('the second failure', 1, true))
  check('and the second', text:find('the fourth failure', 1, true))
  check('and one total', select(2, text:gsub('ASSETS TOTAL', '')) == 1)
  return lines
end
return T
