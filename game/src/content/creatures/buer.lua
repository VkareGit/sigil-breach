-- Plague Gardener: spits venom that leaves a poison pool.
local Creature = require('src.content.defs.creature')
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
return Creature.define({
  id = 'buer',
  name = 'creature_buer',
  souls = 12,
  catalog = {
    field = 4,
    bestiary = {
      order = 3,
      text = 'creature_buer_text',
      tip = 'creature_buer_tip',
      color = 'green',
    },
  },
  appearance = {
    seal = 'buer',
    portal = { 0.58, 0.84, 0.30 },
    stain = { 0.18, 0.15, 0.055 },
    warning = { 0.49, 0.41, 0.16 },
    motion = 'sway',
  },
  -- Rot burns: fire hurts it more. A Judge body shot (70) wounds (60).
  body = {
    hp = 220,
    resist = { fire = -0.25 },
    poise = 50,
    woundAt = 0.27,
    blood = { 0.20, 0.26, 0.08 },
  },
  move = { speed = 3.5, accel = 16, ideal = 5.5 },
  sounds = { step = 'flesh_step', alert = 'growl', windup = 'growl', strike = 'cast' },
  tactics = {
    moves = {
      { attack = 'spore', ideal = 5, weight = 1 },
      { attack = 'root-brace', ideal = 2, max = 3.2, weight = 3 },
      { attack = 'late-bloom', ideal = 6, min = 3, weight = 1.3 },
    },
  },
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
    -- A seed under the feet: it waits long enough to forget it, then bursts.
    Action.pattern({
      id = 'late-bloom',
      range = 8,
      rest = 6,
      windup = 0.6,
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
})
