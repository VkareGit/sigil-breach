-- Resolve authored stations once per geometry revision. Both interaction and
-- painting use the same altar anchor; cached values never retain their world.
local Maps = require('src.content.maps.index')
local Schema = require('src.core.schema')
local Ground = require('src.physics.ground')
local P = {}
local Altar = require('src.content.field').altar
local cache = setmetatable({}, { __mode = 'k' })
function P.forWorld(world)
  local data = Maps:get(world.mapId).proving
  if not data then
    return nil
  end
  local cached = cache[world]
  if cached and cached.revision == world.geometryRevision then
    return cached.pads
  end
  local pads = {}
  for i, definition in ipairs(data.pads) do
    local pad = Schema.copy(definition)
    if pad.altar then
      for _, seal in ipairs(world.seals) do
        if seal.id == pad.altar then
          pad.x, pad.z = seal.x, seal.z
          pad.y, pad.reach = Ground.of(world, seal) + Altar.top, Altar.reach
          break
        end
      end
    end
    pads[i] = pad
  end
  cache[world] = { revision = world.geometryRevision, pads = pads }
  return pads
end
return P
