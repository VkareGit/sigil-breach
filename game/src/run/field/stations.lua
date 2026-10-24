-- Registered inspection stations: identity/name and an executor. The
-- catalogue and its dispatcher share these entries; no station-name branch.
local Registry = require('src.core.registry')
local Stations = Registry:new('field stations', function(entry, id)
  assert(type(entry.name) == 'string' and entry.name ~= '', 'station ' .. id .. ' needs a name')
  assert(type(entry.run) == 'function', 'station ' .. id .. ' needs run(g, field)')
end)
Stations:register('range', {
  name = 'RANGE',
  run = function(g, field)
    return field.range(g)
  end,
})
Stations:register('physics', {
  name = 'PHYSICS',
  run = function(g, field)
    return field.physics(g)
  end,
})
Stations:register('waves', {
  name = 'WAVE TRIAL',
  run = function(g, field)
    return field.waves(g)
  end,
})
return Stations
