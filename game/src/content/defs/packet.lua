-- Damage packet: what one blow delivers. Shared by demon actions, hazards,
-- the knight's abilities and wall slams (src/combat/rules/*).
local Payload = require('src.content.defs.payload')
local Effect = require('src.content.defs.effect')
local Packet = {}
Packet.schema = Payload:extend('packet', {
  effects = {
    type = 'table',
    list = Effect.schema,
    desc = 'effects applied after a damaging contact',
  },
})
-- packet(base, impact, type?, push?)
function Packet.new(base, impact, kind, push)
  return Packet.schema:build({ base = base, impact = impact, damageType = kind, push = push })
end
return Packet
