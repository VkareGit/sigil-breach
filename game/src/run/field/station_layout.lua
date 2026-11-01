-- Map-owned inspection positions, with the historical tools as a fallback.
-- Neither the catalogue nor reset needs to know the geometry of a given map.
local Maps = require('src.content.maps.index')
local K = require('src.content.field')
local S = {}
function S.get(g)
  local layout = Maps:get(g.world.mapId).proving
  return layout and layout.stations or K
end
function S.validate(g)
  local data = S.get(g)
  local W = require('src.world.arena')
  local A = require('src.content.enemies')
  local function clear(spot, radius)
    assert(not W.solid(g.world, spot.x, spot.z, radius), 'blocked field station')
  end
  clear(data.start, require('src.content.characters').standard().body.radius)
  clear(data.physics.stand, require('src.content.characters').standard().body.radius)
  clear(data.physics.slam, A.get('imp').body.radius)
  for i = 1, data.physics.domino.count do
    local row = data.physics.domino
    clear({ x = row.x, z = row.z - (i - 1) * row.step }, A.get('imp').body.radius)
  end
  for _, lane in ipairs(K.range.lanes) do
    clear(
      { x = data.start.x + lane[2], z = data.start.z - math.sqrt(lane[1] ^ 2 - lane[2] ^ 2) },
      A.get('imp').body.radius
    )
  end
end
return S
