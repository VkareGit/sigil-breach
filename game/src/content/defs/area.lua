-- Finite cylinders anchored to a ground surface. Damage sampling is explicit:
-- a floor pool tests feet; a pillar tests the body. Horizontal extent is separate.
local Schema = require('src.core.schema')
local Area = {}
Area.defaults = {
  pool = { bottom = 0, top = 0.42, sample = 'feet', includeRadius = false },
  landing = { bottom = 0, top = 1, sample = 'feet', includeRadius = true },
  lightning = { bottom = 0, top = 2.9, sample = 'body', includeRadius = true },
}
Area.schema = Schema:new('ground volume', {
  bottom = { type = 'number', required = true, desc = 'lower height above source ground (m)' },
  top = { type = 'number', required = true, desc = 'upper height above source ground (m)' },
  sample = { type = 'string', required = true, values = { 'feet', 'body' } },
  includeRadius = { type = 'boolean', required = true },
})
function Area.field(profile)
  return { type = 'table', default = Area.defaults[profile], schema = Area.schema }
end
function Area.validate(volume, path)
  Area.schema:validate(volume, path)
  assert(volume.top > volume.bottom, path .. ': top must exceed bottom')
end
return Area
