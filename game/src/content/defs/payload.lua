-- The numerical payload shared by direct blows and periodic effects.
-- It contains no delivery, contact effects or presentation dependency.
local Schema = require('src.core.schema')
local DamageTypes = require('src.content.damage_types')
return Schema:new('damage payload', {
  base = { type = 'number', required = true, min = 0, desc = 'health damage before armour' },
  impact = { type = 'number', required = true, min = 0, desc = 'guard damage' },
  damageType = { type = 'string', default = 'physical', check = DamageTypes.problem },
  push = { type = 'number', min = 0, desc = 'physical impulse when it differs from impact' },
})
