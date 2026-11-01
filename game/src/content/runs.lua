-- A run: a list of stages, each with its map and its waves (the last wave of a
-- stage is its guardian's). The expedition is a run of one stage; nine circles
-- are a matter of data. A record of a run names its plan and its stage.
local Maps = require('src.content.maps.index')
local Registry = require('src.core.registry')
local Waves = require('src.content.waves')
local Runs = Registry:new('runs', function(run, id)
  assert(type(run.stages) == 'table' and #run.stages > 0, 'run ' .. id .. ' needs stages')
  for index, stage in ipairs(run.stages) do
    assert(Maps:has(stage.map), 'run ' .. id .. ' stage ' .. index .. ': unknown map')
    assert(#stage.waves > 0, 'run ' .. id .. ' stage ' .. index .. ': needs waves')
  end
end)
Runs.default = 'expedition'
Runs:register(Runs.default, { stages = { { map = 'limbo', waves = Waves } } })
-- A schema check: nil when the id names a run.
function Runs.problem(id)
  if not Runs:has(id) then
    return 'unknown run ' .. tostring(id)
  end
end
-- The stage a record stands in. A record of a shared shop names none.
function Runs.stage(record)
  local run = Runs:get(record.plan or Runs.default)
  return assert(run.stages[record.stage or 1], 'no such stage of the run')
end
-- The ordinary waves of its stage; the guardian's wave is the next one.
function Runs.total(record)
  return #Runs.stage(record).waves - 1
end
function Runs.guardian(record)
  return record.wave == Runs.total(record) + 1
end
function Runs.wave(record)
  return Runs.stage(record).waves[record.wave]
end
-- The stage after this one, if the run goes on.
function Runs.following(record)
  return Runs:get(record.plan or Runs.default).stages[(record.stage or 1) + 1]
end
-- The most waves any stage of any run has: what a save may name.
function Runs.longest()
  local most = 1
  for _, run in Runs:each() do
    for _, stage in ipairs(run.stages) do
      most = math.max(most, #stage.waves)
    end
  end
  return most
end
return Runs
