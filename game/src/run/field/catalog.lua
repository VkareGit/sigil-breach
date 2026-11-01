-- The proving-ground catalogue follows registered content at query time.
-- Existing screens retain their ordered arrays; adding a creature is data.
-- Names are text keys (content/text.lua).
local Archetypes = require('src.content.enemies')
local Stations = require('src.run.field.stations')
local Access = require('src.run.field.access')
local Catalog = { seals = require('src.content.occult_catalog').visits }
function Catalog.contains(id)
  for _, definition in ipairs(Archetypes.listed('field')) do
    if definition.id == id then
      return true
    end
  end
  return false
end
function Catalog.stationsFor(record)
  local list = {}
  for id, definition in Stations:each() do
    if Access.allows(record, definition.feature) then
      list[#list + 1] = { id = id, name = definition.name, menuText = definition.menuText }
    end
  end
  return list
end
return setmetatable(Catalog, {
  __index = function(_, key)
    if key == 'enemies' then
      local list = {}
      for _, definition in ipairs(Archetypes.listed('field')) do
        list[#list + 1] = { id = definition.id, name = definition.name }
      end
      return list
    elseif key == 'stations' then
      return Catalog.stationsFor()
    end
  end,
})
