-- Frozen delivery data solely for continuing saves written before the garden rework.
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
local Legacy = {
  attacks = {
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
    -- Close the forward approach, leave the flanks clear. It can be
    -- interrupted like the ordinary cast; the three marks never chase, and
    -- what steps in stops walking.
    Action.pattern({
      id = 'root-brace',
      origin = 'caster',
      range = 3.2,
      rest = 4.5,
      windup = 0.85,
      duration = 0.3,
      recover = 0.9,
      cooldown = 1.6,
      hazard = 'pool',
      radius = 0.8,
      life = 1.6,
      pulse = 0.45,
      condition = 'rooted',
      marks = {
        -- Place the barrier at the creature, not underneath the camera:
        -- its silhouette/gesture and the forward floor remain readable.
        { forward = 0.9, lateral = -1.25, delay = 0.6 },
        { forward = 1.3, lateral = 0, delay = 0.6 },
        { forward = 0.9, lateral = 1.25, delay = 0.6 },
      },
      packet = venom(8),
    }),
    -- A ring of rot around the knight, then its heart: wait for the ring, then walk.
    Action.pattern({
      id = 'seed-ring',
      range = 8,
      minRange = 2.5,
      rest = 7,
      windup = 0.7,
      duration = 0.3,
      recover = 0.9,
      cooldown = 1.2,
      hazard = 'pool',
      radius = 1,
      life = 0.6,
      pulse = 0.3,
      marks = {
        { forward = 2.4, lateral = 0, delay = 0.8 },
        { forward = 1.7, lateral = 1.7, delay = 0.8 },
        { forward = 0, lateral = 2.4, delay = 0.8 },
        { forward = -1.7, lateral = 1.7, delay = 0.8 },
        { forward = -2.4, lateral = 0, delay = 0.8 },
        { forward = -1.7, lateral = -1.7, delay = 0.8 },
        { forward = 0, lateral = -2.4, delay = 0.8 },
        { forward = 1.7, lateral = -1.7, delay = 0.8 },
        { forward = 0, lateral = 0, delay = 1.6 },
      },
      packet = venom(26, 40),
    }),
    -- A seed under the feet: it waits long enough to forget it, then bursts.
    Action.pattern({
      id = 'late-bloom',
      range = 8,
      rest = 6,
      windup = 0.6,
      parry = 0.3,
      parryReach = 10,
      duration = 0.3,
      recover = 0.7,
      cooldown = 1.2,
      hazard = 'pool',
      radius = 1.7,
      life = 0.4,
      pulse = 0.3,
      marks = { { forward = 0, lateral = 0, delay = 1.5 } },
      packet = venom(30, 60),
    }),
  },
}
for i, attack in ipairs(Legacy.attacks) do
  Legacy.attacks[i] = Action.build(attack, 'saved gardener attack')
end
return Legacy
