-- A reaction: what a body does on an event of its own fighting, carried by a
-- weapon, a run's modifier, a character or a condition. Its effect is a contact
-- effect (content/defs/effect.lua) or a kind of its own below, whose behaviour
-- is an entry in combat/reactions.lua. An effect record has no reactions field,
-- so a reaction cannot carry another.
local Schema = require('src.core.schema')
local Registry = require('src.core.registry')
local Effect = require('src.content.defs.effect')
local Action = require('src.content.defs.action')
local Conditions = require('src.content.conditions')
local Reaction = { kinds = Registry:new('reaction schemas') }
Reaction.events = { 'hit', 'kill', 'shot', 'miss', 'surface', 'reload' }
-- The events with a struck body.
local struck = { hit = true, kill = true }
function Reaction.defineKind(id, fields)
  local specs = { kind = { type = 'string', required = true } }
  for key, spec in pairs(fields or {}) do
    specs[key] = spec
  end
  return Reaction.kinds:register(id, Schema:new('reaction ' .. id, specs))
end
Reaction.defineKind('heal', { amount = { type = 'number', required = true, min = 0 } })
Reaction.defineKind('blast', {
  radius = { type = 'number', required = true, min = 0, desc = 'reach (m)' },
  blast = { type = 'table', required = true, schema = Action.blast },
})
Reaction.defineKind('action', {
  action = { type = 'table', required = true, desc = 'Action.build(...): done at the place' },
})
local function schemaOf(def)
  return Reaction.kinds:find(def.kind) or Effect.schema
end
Reaction.effect = {}
function Reaction.effect:fill(def)
  return schemaOf(def):fill(def)
end
function Reaction.effect:problems(def, path, out)
  out = out or {}
  if type(def) ~= 'table' then
    out[#out + 1] = path .. ': expected an effect record'
    return out
  end
  return schemaOf(def):problems(def, path, out)
end
local record = Schema:new('reaction', {
  on = { type = 'string', required = true, values = Reaction.events },
  target = { type = 'string', default = 'self', values = { 'self', 'struck' } },
  effect = { type = 'table', required = true, schema = Reaction.effect },
})
Reaction.schema = {}
function Reaction.schema:fill(def)
  return record:fill(def)
end
function Reaction.schema:problems(def, path, out)
  out = record:problems(def, path, out)
  if type(def) == 'table' and def.target == 'struck' and not struck[def.on] then
    out[#out + 1] = path .. ": nothing is struck on '" .. tostring(def.on) .. "'"
  end
  return out
end
-- What a condition's bearer reacts with: kept here, since an effect names
-- conditions and a condition must not depend on effects.
Reaction.ofCondition = {}
function Reaction.bind(condition, list)
  assert(Conditions.find(condition), 'unknown condition ' .. tostring(condition))
  Reaction.ofCondition[condition] = Reaction.build(list, 'condition ' .. condition)
end
function Reaction.unbind(condition)
  Reaction.ofCondition[condition] = nil
end
-- The field of a definition that carries reactions.
Reaction.field = { type = 'table', list = Reaction.schema, desc = '{ on, effect, target }' }
local holder = Schema:new('reactions', { list = Reaction.field })
function Reaction.build(list, where)
  return holder:build({ list = list }, where).list
end
return Reaction
