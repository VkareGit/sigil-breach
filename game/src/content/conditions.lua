-- Conditions: named states with a duration, the same for every body
-- (combat/rules/conditions.lua). Each scales speed and guard recovery while it
-- lasts; a new condition is a new entry.
--  staggered: cannot act (enemies) / slowed and unsteady (player)
--  wounded:   a major wound; slower for a while, the stagger lasts longer
--  poisoned:  standing in plague; the body recovers its guard and breath slower
--  crippled:  a leg blow (hit zones); the body limps for a while
--  exposed:   a boss whose guard broke; half armour (combat/damage.lua)
local Condition = require('src.content.defs.condition')
local Registry = require('src.core.registry')
local registry = Registry:new('conditions', function(entry, id)
  Condition.schema:validate(entry, 'condition ' .. id)
end)
local api, order = {}, {}
local function reorder()
  order = registry:ids()
  table.sort(order)
end
function api.register(id, definition)
  assert(api[id] == nil, 'condition id is reserved: ' .. tostring(id))
  local built = Condition.define(id, definition)
  registry:register(id, built)
  reorder()
  return built
end
function api.unregister(id)
  local removed = registry:unregister(id)
  reorder()
  return removed
end
function api.ids()
  return order
end
function api.get(id)
  return registry:get(id)
end
function api.find(id)
  return registry:find(id)
end
api.register('staggered', { speed = 0.45 })
api.register('wounded', { speed = 0.72 })
api.register('poisoned', { recovery = 0.5 })
api.register('crippled', { speed = 0.65 })
api.register('exposed', {})
-- Existing data readers retain Conditions[id]; methods are not definition keys.
return setmetatable(registry:view(), { __index = api })
