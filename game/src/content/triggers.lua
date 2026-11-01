-- What a press of the trigger means. A mode is its fields here and its behaviour
-- in player/intent.lua (I.modes). Both production weapons are automatic.
local Registry = require('src.core.registry')
local Schema = require('src.core.schema')
local Triggers = Registry:new('trigger modes')
function Triggers.define(id, fields)
  local specs = { mode = { type = 'string', required = true } }
  for key, spec in pairs(fields or {}) do
    specs[key] = spec
  end
  return Triggers:register(id, Schema:new('trigger ' .. id, specs))
end
Triggers.define('auto')
return Triggers
