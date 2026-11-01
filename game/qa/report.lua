-- Aggregate executed assertions in memory. Historical reports are never inputs.
local Report = {}
Report.__index = Report

function Report.new(path)
  return setmetatable(
    { path = path, suites = {}, ids = {}, total = 0, failures = {}, status = 'RUNNING' },
    Report
  )
end

function Report:add(id, title, lines)
  assert(not self.ids[id], 'duplicate test suite: ' .. id)
  assert(type(lines) == 'table', id .. ' must return its executed assertion lines')
  local copy = {}
  for index, line in ipairs(lines) do
    assert(
      type(line) == 'string' and line:sub(1, 5) == 'PASS ',
      id .. ' returned an invalid result at ' .. index
    )
    copy[index] = line
  end
  self.ids[id] = true
  self.suites[#self.suites + 1] = { id = id, title = title, lines = copy }
  self.total = self.total + #copy
end

function Report:render()
  local lines = {
    'SIGIL / MECHANICS AND ASSETS',
    'STATUS: ' .. self.status,
    require('qa.output').receipt(),
    '',
  }
  for _, suite in ipairs(self.suites) do
    lines[#lines + 1] = 'SUITE ' .. suite.id .. ' / ' .. suite.title
    for _, line in ipairs(suite.lines) do
      lines[#lines + 1] = line
    end
    lines[#lines + 1] = 'SUITE ' .. suite.id .. ': ' .. #suite.lines .. ' passing checks.'
    lines[#lines + 1] = ''
  end
  for _, failure in ipairs(self.failures) do
    lines[#lines + 1] = 'FAIL ' .. failure
  end
  lines[#lines + 1] = 'MECHANICS / ASSETS TOTAL: ' .. self.total .. ' passing checks.'
  lines[#lines + 1] = 'Controller checks run separately via --input-test.'
  return table.concat(lines, '\n') .. '\n'
end

function Report:write()
  local file = assert(io.open(self.path, 'w'))
  file:write(self:render())
  file:close()
end

-- A failing suite is written down and the rest still run: one run shows every failure, not
-- the first of them.
function Report:run(id, title, execute)
  local ok, result = xpcall(execute, debug.traceback)
  if ok then
    ok, result = pcall(self.add, self, id, title, result)
  end
  if not ok then
    self.status = 'FAILED'
    self.failures[#self.failures + 1] = id .. ': ' .. tostring(result)
    self:write()
    print('FAIL ' .. id .. ': ' .. tostring(result))
    return
  end
  self:write()
  print('SUITE ' .. id .. ': ' .. #self.suites[#self.suites].lines .. ' passing checks.')
end

-- The end of the run: the process fails here if any suite did.
function Report:finish()
  if #self.failures > 0 then
    self:write()
    error(#self.failures .. ' suites failed; first: ' .. self.failures[1], 0)
  end
  self.status = 'PASSED'
  self:write()
  print('TOTAL ' .. self.total .. ' mechanics/asset checks.')
  return self
end

return Report
