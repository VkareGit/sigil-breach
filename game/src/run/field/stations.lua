-- Registered inspection stations: identity, name (a text key) and an executor. The
-- catalogue and its dispatcher share these entries; no station-name branch.
local Registry = require('src.core.registry')
local Access = require('src.run.field.access')
local Stations = Registry:new('field stations', function(entry, id)
  assert(type(entry.name) == 'string' and entry.name ~= '', 'station ' .. id .. ' needs a name')
  assert(type(entry.run) == 'function', 'station ' .. id .. ' needs run(g, field)')
  Access.check(entry.feature)
end)
Stations:register('range', {
  name = 'station_range',
  menuText = 'menu_station_range',
  run = function(g, field)
    return field.range(g)
  end,
})
Stations:register('physics', {
  name = 'station_physics',
  menuText = 'menu_station_physics',
  run = function(g, field)
    return field.physics(g)
  end,
})
Stations:register('waves', {
  name = 'station_waves',
  menuText = 'menu_station_waves',
  feature = 'waves',
  run = function(g, field)
    return field.waves(g)
  end,
})
return Stations
