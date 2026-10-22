-- Every map a session can be built on (0.24 F6). A new map (the base, a hub,
-- the next circle) is a data file registered here; world/arena.lua builds
-- it and the modes read its places (spawn, Ember, gates, zones).
local Registry = require('src.core.registry')
local Maps = Registry:new('maps', function(map, id)
  assert(type(map.size) == 'number' and map.size > 0, 'map ' .. id .. ' needs a size')
  assert(type(map.rooms) == 'table', 'map ' .. id .. ' needs rooms')
  assert(map.spawn and map.portal and map.ember, 'map ' .. id .. ' needs spawn, portal, ember')
  assert(type(map.zones) == 'table' and #map.zones > 0, 'map ' .. id .. ' needs zones')
end)
Maps:register('limbo', require('src.content.maps.limbo'))
-- The map every session is built on unless it names another.
Maps.default = 'limbo'
return Maps
