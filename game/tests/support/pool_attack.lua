-- A spitting cast that leaves a pool (the 'pool' kind, enemies/ranged_kinds.lua),
-- as the Plague Gardener once carried it. No creature carries it now; the
-- tests keep the kind and its contracts proven on this definition.
local Action = require('src.content.defs.action')
local Packet = require('src.content.defs.packet')
-- The rot gathers in the blood: only a third dose takes hold.
local function venom(base, impact)
  local packet = Packet.new(base, impact or 0, 'poison')
  packet.effects = {
    {
      id = 'rot',
      kind = 'buildup',
      duration = 5,
      amount = 36,
      threshold = 100,
      decay = 12,
      results = {
        {
          id = 'rot_burn',
          kind = 'periodic',
          duration = 4,
          interval = 0.5,
          packet = Packet.new(6, 0, 'poison'),
        },
      },
    },
  }
  return Packet.schema:build(packet, 'venom')
end
return Action.build(
  Action.pool({
    id = 'spore',
    range = 8,
    windup = 0.74,
    recover = 0.4,
    cooldown = 1.15,
    aimLead = 0.95,
    leadFloor = 1,
    pool = {
      delay = 0.65,
      radius = 1.35,
      life = 3.2,
      pulse = 0.45,
      packet = venom(8),
      condition = 'poisoned',
    },
    bolt = { speed = 8.5, color = { 0.46, 0.39, 0.14 }, packet = venom(20, 40) },
  }),
  'pool attack fixture'
)
