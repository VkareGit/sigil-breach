-- Shared QA contracts: finite workload profiles, state-driven waits and report
-- provenance. None of these helpers changes the shipped simulation or its limits.
local Build = require('src.core.build')
local Grid = require('src.physics.grid')
local Tooling = {}

Tooling.catalog = {
  { flag = '--benchmark', reports = { 'benchmark.txt' } },
  { flag = '--core-measure', reports = { 'core-measure.txt' } },
  { flag = '--step-study', reports = { 'step-study.txt' } },
  {
    flag = '--audio-export',
    reports = { 'audio-export.txt', 'sounds/report.txt', 'music/report.txt' },
  },
}

function Tooling.count(smoke, full, short)
  return smoke and short or full
end

function Tooling.header(name, smoke)
  return {
    name,
    'Build: ' .. Build.version,
    'Source fingerprint: '
      .. (os.getenv('SIGIL_QA_SOURCE_FINGERPRINT') or 'unfingerprinted direct invocation'),
    'Build fingerprint: '
      .. (os.getenv('SIGIL_QA_BUILD_FINGERPRINT') or 'unfingerprinted direct invocation'),
    'Profile: '
      .. (smoke and 'smoke (functional coverage; not a performance sample)' or 'full measurement'),
    require('qa.output').receipt(),
  }
end

function Tooling.write(output, name, lines, smoke)
  lines[#lines + 1] = 'QA COMPLETE: ' .. name .. ' profile=' .. (smoke and 'smoke' or 'full')
  local file = assert(io.open(output .. '/' .. name, 'wb'))
  file:write(table.concat(lines, '\n'), '\n')
  file:close()
end

-- A simulated-time bound, never a sleep or an unconditional delay. Readiness
-- is checked before advancing, including on the final allowed step.
function Tooling.advanceUntil(label, ready, advance, dt, seconds)
  assert(dt > 0 and seconds >= 0, 'invalid QA advancement bound')
  local steps, maximum = 0, math.ceil(seconds / dt)
  while not ready() do
    assert(steps < maximum, label .. ' did not converge within ' .. seconds .. ' simulated seconds')
    advance(dt)
    steps = steps + 1
  end
  return steps, steps * dt
end

function Tooling.populations(spec, defaults)
  if spec == nil or spec == '' then
    return defaults
  end
  local result, seen = {}, {}
  for value in (spec .. ','):gmatch('(.-),') do
    assert(value:match('^%s*%d+%s*$'), 'SIGIL_BENCH_POPULATIONS must be comma-separated integers')
    local count = tonumber(value)
    assert(
      count >= 1 and count <= 512 and not seen[count],
      'population must be unique and within 1..512'
    )
    seen[count], result[#result + 1] = true, count
  end
  assert(#result > 0, 'population list is empty')
  return result
end

-- The map crowds are built on: the arena, or SIGIL_CROWD_MAP=qa_crowd, the
-- diagnostic hall (qa/data/crowd_map.lua) registered on first use, where one
-- cost curve from 20 to 512 bodies is measured on the same floor.
function Tooling.crowdMap()
  local id = os.getenv('SIGIL_CROWD_MAP')
  if id == nil or id == '' then
    return nil
  end
  assert(id == 'qa_crowd', 'SIGIL_CROWD_MAP knows only qa_crowd')
  local Maps = require('src.content.maps.index')
  if not Maps:find(id) then
    Maps:register(id, require('qa.data.crowd_map'))
  end
  return id
end

-- This intentionally bypasses the catalogue's player-facing population cap.
-- Every body still comes from the production factory, on a free arena tile.
-- It is a diagnostic crowd, not a promise that these counts are playable.
function Tooling.crowd(Game, count)
  local Field = require('src.run.test_field')
  local Enemies = require('src.content.enemies')
  local World = require('src.world.arena')
  local game = Field.new(Game, Tooling.crowdMap())
  game.ephemeral = true
  local index = 1
  for z = 3, Grid.depth(game.world) - 3, 1.5 do
    for x = 3, Grid.width(game.world) - 3, 1.5 do
      local kind = Field.catalog.enemies[1 + (index - 1) % #Field.catalog.enemies].id
      if index <= count and not World.solid(game.world, x, z, Enemies.get(kind).body.radius) then
        local enemy = game:spawn(kind, x, z)
        enemy.spawnAge, enemy.awake = 1, true
        index = index + 1
      end
    end
  end
  assert(#game.enemies == count, 'diagnostic population does not fit the arena')
  Field.close(game)
  return game
end

return Tooling
