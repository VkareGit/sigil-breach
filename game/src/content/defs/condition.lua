-- Condition: a named state with a duration (staggered, wounded, poisoned...).
-- While it lasts it changes named numbers of the body (content/attributes.lua)
-- and forbids acts; speed and recovery are the common shorthand.
local Schema = require('src.core.schema')
local Attributes = require('src.content.attributes')
local Condition = {}
Condition.schema = Schema:new('condition', {
  speed = { type = 'number', default = 1, min = 0, desc = 'movement multiplier' },
  recovery = {
    type = 'number',
    default = 1,
    min = 0,
    desc = 'guard and breath recovery multiplier',
  },
  modifiers = { type = 'table', desc = 'attribute -> { mul }' },
  forbids = { type = 'table', desc = "acts it forbids, e.g. { 'fire' }" },
})
function Condition.define(id, def)
  local where = 'condition ' .. id
  local built = Condition.schema:build(def, where)
  local modifiers = {}
  for name, modifier in pairs(built.modifiers or {}) do
    assert(Attributes:has(name), where .. ': unknown attribute ' .. tostring(name))
    assert(type(modifier.mul) == 'number' and modifier.mul >= 0, where .. '.' .. name .. '.mul')
    modifiers[name] = modifier
  end
  modifiers.speed = modifiers.speed or { mul = built.speed }
  modifiers.recovery = modifiers.recovery or { mul = built.recovery }
  built.modifiers = modifiers
  local forbids = {}
  for _, act in ipairs(built.forbids or {}) do
    forbids[act] = true
  end
  built.forbids = forbids
  return built
end
return Condition
