-- Damage packet: what one blow delivers. Shared by demon actions, hazards,
-- the knight's abilities and wall slams (src/combat/rules/*).
local Schema = require('src.core.schema')
local Packet = {}
Packet.schema = Schema:new('packet', {
  base = { type = 'number', required = true, min = 0, desc = 'health damage before armour' },
  impact = { type = 'number', required = true, min = 0, desc = 'guard (poise) damage' },
  damageType = { type = 'string', default = 'physical', desc = 'physical, fire, astral, poison...' },
  push = { type = 'number', min = 0, desc = 'physical impulse when it differs from impact' },
})
-- packet(base, impact, type?, push?)
function Packet.new(base, impact, kind, push)
  return Packet.schema:build({ base = base, impact = impact, damageType = kind, push = push })
end
return Packet
