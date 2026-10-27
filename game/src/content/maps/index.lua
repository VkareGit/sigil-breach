-- Every map a session can be built on (0.24 F6). A new map (the base, a hub,
-- the next circle) is a data file registered here; world/arena.lua builds
-- it and the modes read its places (spawn, Ember, gates, zones).
local Registry = require('src.core.registry')
local Maps = Registry:new('maps', require('src.content.maps.schema').check)
Maps:register('limbo', require('src.content.maps.limbo'))
Maps:register('proving', require('src.content.maps.proving'))
-- The map every session is built on unless it names another.
Maps.default = 'limbo'
return Maps
