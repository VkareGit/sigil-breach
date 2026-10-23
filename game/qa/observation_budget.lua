-- Diagnostic only: no machine-dependent performance assertion. Measures CPU
-- geometry capture/copy/resolve and the plain recorded command size.
local O = require('src.combat.observation')
local Serialize = require('src.core.serialize')
local Budget = {}
function Budget.run(G)
  local rows = {
    'bodies,capture_mean_ms,capture_max_ms,command_copy_mean_ms,prepare_mean_ms,command_bytes,held_record_bytes_per_sim_second',
  }
  for _, count in ipairs({ 1, 8, 24, 48 }) do
    local g = require('tests.support.fixtures').arena(G)
    local kinds = { 'imp', 'armored', 'buer', 'stolas', 'boss', 'furfur' }
    for i = 1, count do
      local e =
        g:spawn(kinds[(i - 1) % #kinds + 1], 9 + (i - 1) % 12, 8 + math.floor((i - 1) / 12) * 3)
      e.spawnAge, e.dummy = 1, true
    end
    collectgarbage('collect')
    local capture, largest, copy, prepare, observation = 0, 0, 0, 0
    local iterations = 40
    for _ = 1, iterations do
      local start = love.timer.getTime()
      observation = O.capture(g)
      local elapsed = love.timer.getTime() - start
      capture, largest = capture + elapsed, math.max(largest, elapsed)
      start = love.timer.getTime()
      O.command(observation, g)
      copy = copy + love.timer.getTime() - start
      start = love.timer.getTime()
      O.prepare(g, observation)
      prepare = prepare + love.timer.getTime() - start
    end
    local bytes = #Serialize.encode(O.command(observation, g))
    rows[#rows + 1] = string.format(
      '%d,%.6f,%.6f,%.6f,%.6f,%d,%d',
      count,
      capture * 1000 / iterations,
      largest * 1000,
      copy * 1000 / iterations,
      prepare * 1000 / iterations,
      bytes,
      bytes * 120
    )
  end
  local file = assert(io.open(require('qa.output').path('observation-budget.csv'), 'w'))
  file:write(table.concat(rows, '\n') .. '\n')
  file:close()
end
return Budget
