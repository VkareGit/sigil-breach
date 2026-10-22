local Report = require('qa.report')
local Tests = {}

function Tests.run()
  local lines = {}
  local function check(name, ok)
    assert(ok, 'FAIL reporting: ' .. name)
    lines[#lines + 1] = 'PASS ' .. name
  end
  local report = Report.new('unused-test-output')
  local writes = {}
  report.write = function(self)
    writes[#writes + 1] = self:render()
  end
  check(
    'new test report begins empty without historical files',
    report.total == 0 and #report.suites == 0 and report.status == 'RUNNING'
  )
  local results = { 'PASS first', 'PASS second' }
  report:add('first', 'Fixture', results)
  results[1] = 'FAIL changed outside the collector'
  check(
    'report retains a snapshot of executed assertions',
    report.suites[1].lines[1] == 'PASS first'
  )
  check('report total counts returned assertions', report.total == 2)
  local ok = pcall(report.add, report, 'first', 'Duplicate', { 'PASS extra' })
  check(
    'duplicate suite cannot inflate totals',
    not ok and report.total == 2 and #report.suites == 1
  )
  ok = pcall(report.add, report, 'invalid', 'Invalid', { 'PASS valid', 'FAIL invalid' })
  check(
    'invalid batch cannot partially alter results',
    not ok and report.total == 2 and not report.ids.invalid
  )
  ok = pcall(report.run, report, 'failure', 'Failure', function()
    error('intentional reporter fixture')
  end)
  check('suite failure propagates to the process', not ok)
  check(
    'suite failure persists a diagnostic and earlier results',
    report.status == 'FAILED'
      and #writes == 1
      and writes[1]:find('intentional reporter fixture', 1, true)
      and writes[1]:find('PASS first', 1, true)
      and report.total == 2
  )
  local nextRun = Report.new('unused-test-output')
  check(
    'next invocation does not inherit counts or failure state',
    nextRun.total == 0 and nextRun.status == 'RUNNING' and not nextRun.failure
  )
  local _, count = report:render():gsub('MECHANICS / ASSETS TOTAL:', '')
  check('report exposes exactly one authoritative total', count == 1)
  return lines
end

return Tests
