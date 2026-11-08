-- Contact effects are data with a schema per behaviour. A periodic payload
-- cannot contain contact effects, preventing recursive damage/status loops.
local Schema = require('src.core.schema')
local Registry = require('src.core.registry')
local Id = require('src.core.id')
local Payload = require('src.content.defs.payload')
local Conditions = require('src.content.conditions')
local Effect = { kinds = Registry:new('effect schemas') }
local common = {
  id = { type = 'string', required = true, desc = 'stable stacking identity on a body' },
  kind = { type = 'string', required = true },
  duration = { type = 'number', required = true, min = 1e-9, desc = 'active seconds' },
}
function Effect.defineKind(id, fields)
  local schema = Schema:new('effect ' .. id, common):extend('effect ' .. id, fields)
  return Effect.kinds:register(id, schema)
end
Effect.defineKind('condition', { condition = { type = 'string', required = true } })
Effect.defineKind('periodic', {
  interval = {
    type = 'number',
    required = true,
    min = require('src.core.rate').step,
    desc = 'seconds between pulses, at least one simulation step',
  },
  packet = { type = 'table', required = true, schema = Payload },
  stacking = { type = 'string', default = 'refresh', values = { 'refresh', 'replace' } },
  cancelOnSourceDeath = { type = 'boolean', default = false },
})
-- Polymorphic nested-list schema consumed by Packet and Weapon.attack.
Effect.schema = {}
-- Exposure that gathers: each contact adds amount, it fades by decay per second
-- (read every interval), and only at the threshold do its results fall.
Effect.defineKind('buildup', {
  amount = { type = 'number', required = true, min = 0 },
  threshold = { type = 'number', required = true, min = 0 },
  decay = { type = 'number', default = 0, min = 0 },
  interval = { type = 'number', default = 0.25, min = 0.01 },
  results = { type = 'table', required = true, list = Effect.schema },
})
function Effect.schema:fill(definition)
  return Effect.kinds:get(definition.kind):fill(definition)
end
-- Marked fields (core/schema.lua: Schema:marked) of the effect's own kind.
function Effect.schema:marked(definition, mark, visit, path)
  local schema = type(definition) == 'table' and Effect.kinds:find(definition.kind)
  if schema then
    schema:marked(definition, mark, visit, path)
  end
end
function Effect.schema:problems(definition, path, out)
  out = out or {}
  if type(definition) ~= 'table' then
    out[#out + 1] = path .. ': expected an effect record'
    return out
  end
  local schema = Effect.kinds:find(definition.kind)
  if not schema then
    out[#out + 1] = path .. ': unknown effect kind ' .. tostring(definition.kind)
    return out
  end
  schema:problems(definition, path, out)
  if not Id.valid(definition.id) then
    out[#out + 1] = path .. '.id: invalid effect id'
  end
  if definition.kind == 'condition' and not Conditions.find(definition.condition) then
    out[#out + 1] = path .. '.condition: unknown condition ' .. tostring(definition.condition)
  end
  if definition.kind == 'buildup' and type(definition.results) == 'table' then
    for index, result in ipairs(definition.results) do
      if result.kind == 'buildup' then
        out[#out + 1] = path .. '.results[' .. index .. ']: a buildup cannot gather a buildup'
      end
    end
  end
  if definition.kind == 'periodic' and type(definition.packet) == 'table' then
    if definition.packet.impact ~= 0 or (definition.packet.push or 0) ~= 0 then
      out[#out + 1] = path .. '.packet: periodic exposure has no impact or shove'
    end
  end
  return out
end
return Effect
