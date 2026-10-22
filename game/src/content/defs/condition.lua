-- Condition: a named state with a duration (staggered, wounded, poisoned...).
-- While it lasts it scales the body's speed and guard recovery.
local Schema = require('src.core.schema')
local Condition = {}
Condition.schema = Schema:new('condition', {
  speed = { type = 'number', default = 1, min = 0, desc = 'movement multiplier' },
  recovery = {
    type = 'number',
    default = 1,
    min = 0,
    desc = 'guard and breath recovery multiplier',
  },
})
function Condition.define(id, def)
  return Condition.schema:build(def, 'condition ' .. id)
end
return Condition
