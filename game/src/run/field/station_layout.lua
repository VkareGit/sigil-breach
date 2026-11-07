-- Map-owned inspection positions, with the historical tools as a fallback.
-- Neither the catalogue nor reset needs to know the geometry of a given map.
local Characters = require('src.content.characters')
local Archetypes = require('src.content.enemies')
local Arena = require('src.world.arena')
local Maps = require('src.content.maps.index')
local FieldData = require('src.content.field')
local S = {}
function S.get(g)
  local layout = Maps:get(g.world.mapId).proving
  return layout and layout.stations or FieldData
end
function S.validate(g)
  local data = S.get(g)
  local function clear(spot, radius)
    assert(not Arena.solid(g.world, spot.x, spot.z, radius), 'blocked field station')
  end
  clear(data.start, Characters.standard().body.radius)
  clear(data.physics.stand, Characters.standard().body.radius)
  clear(data.physics.slam, Archetypes.get(FieldData.dummy).body.radius)
  for i = 1, data.physics.domino.count do
    local row = data.physics.domino
    clear(
      { x = row.x, z = row.z - (i - 1) * row.step },
      Archetypes.get(FieldData.dummy).body.radius
    )
  end
  for _, lane in ipairs(FieldData.range.lanes) do
    clear(
      { x = data.start.x + lane[2], z = data.start.z - math.sqrt(lane[1] ^ 2 - lane[2] ^ 2) },
      Archetypes.get(FieldData.dummy).body.radius
    )
  end
end
return S
