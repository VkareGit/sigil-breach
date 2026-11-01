-- Engravings of a run. A weapon says what each does to it (its glyphs field); a
-- run wears at most limit of them. A new one is an entry here, its offer and its
-- field on the weapons it marks.
local Registry = require('src.core.registry')
local Glyphs = Registry:new('glyphs')
Glyphs.none = 'none'
Glyphs.limit = 1
Glyphs:register('choke', { icon = 'choke' })
Glyphs:register('pierce', { icon = 'pierce' })
-- A schema check: nil when the id names a glyph, or none.
function Glyphs.problem(id)
  if id ~= Glyphs.none and not Glyphs:has(id) then
    return 'unknown glyph ' .. tostring(id)
  end
end
-- A schema check of the map of owned glyphs.
function Glyphs.ownedProblem(owned)
  for id, value in pairs(owned) do
    if not Glyphs:has(id) or type(value) ~= 'boolean' then
      return 'unknown glyph ' .. tostring(id)
    end
  end
end
return Glyphs
