-- The proving-ground catalogue follows registered content at query time.
-- Existing screens retain their ordered arrays; adding a creature is data.
local Archetypes = require('src.content.enemies')
local Stations = require('src.run.field.stations')
local Catalog = {
  seals = {
    { id = 'asmoday', name = 'ASMODAY' },
    { id = 'stolas', name = 'STOLAS' },
    { id = 'buer', name = 'BUER' },
  },
}
function Catalog.contains(id)
  for _, definition in ipairs(Archetypes.listed('field')) do
    if definition.id == id then
      return true
    end
  end
  return false
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
      local list = {}
      for id, definition in Stations:each() do
        list[#list + 1] = { id = id, name = definition.name }
      end
      return list
    end
  end,
})
