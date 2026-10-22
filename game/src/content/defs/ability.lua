-- Ability: the TYPE OBJECT of equipment the knight uses (the powder charge;
-- never magic, the knight is a man). It wraps an action (content/defs/action.lua: the
-- delivery kind, its payload and timing, the same format as demon attacks)
-- with what the knight carries of it: uses at most and at the start, and
-- the notice when none is left. The live record (uses left, ready time) is
-- player.abilityState[id] (content/abilities.lua: newState).
local Schema = require('src.core.schema')
local Action = require('src.content.defs.action')
local Ability = {}
Ability.schema = Schema:new('ability', {
  id = { type = 'string', required = true },
  name = { type = 'string', required = true },
  tag = { type = 'string', required = true, desc = 'its word on the HUD key (Q CHARGE)' },
  action = { type = 'table', required = true, desc = 'Action.build(...): delivery and payload' },
  capacity = { type = 'number', required = true, min = 1, desc = 'uses carried at most' },
  start = { type = 'number', required = true, min = 0, desc = 'uses a fresh knight carries' },
  empty = { type = 'string', required = true, desc = 'notice when no use is left' },
})
function Ability.define(def)
  local path = 'ability ' .. tostring(def.id)
  local built = Ability.schema:build(def, path)
  assert(built.capacity % 1 == 0, path .. '.capacity: expected an integer')
  assert(built.start % 1 == 0, path .. '.start: expected an integer')
  assert(built.start <= built.capacity, path .. '.start: exceeds capacity')
  built.action = Action.build(built.action, path .. '.action')
  return built
end
return Ability
