-- Plague Gardener: spits venom that leaves a poison pool.
local Creature = require('src.content.defs.creature')
local Action = require('src.content.defs.action')
local packet = require('src.content.defs.packet').new
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
    portal = { 0.58, 0.84, 0.30 },
    stain = { 0.18, 0.15, 0.055 },
    warning = { 0.49, 0.41, 0.16 },
    motion = 'sway',
  },
  -- Rot burns: fire hurts it more. A Judge body shot (70) wounds (60).
  body = {
    hp = 150,
    resist = { fire = -0.25 },
    poise = 50,
    woundAt = 0.40,
    blood = { 0.20, 0.26, 0.08 },
  },
  move = { speed = 3.0, accel = 12, ideal = 4.5 },
  sounds = { step = 'flesh_step', alert = 'growl', windup = 'growl', strike = 'cast' },
  tactics = {
    moves = {
      { attack = 'spore', ideal = 5, weight = 1 },
      { attack = 'root-brace', ideal = 2, max = 3.2, weight = 3 },
    },
  },
  attacks = {
    Action.pool({
      id = 'spore',
      range = 8,
      windup = 0.74,
      cooldown = 2.5,
      lead = 0.16,
      pool = {
        delay = 0.65,
        radius = 1.35,
        life = 3.2,
        pulse = 0.45,
        packet = packet(8, 0, 'poison'),
        condition = 'poisoned',
      },
      bolt = { speed = 5.0, color = { 0.46, 0.39, 0.14 }, packet = packet(14, 40, 'poison') },
    }),
    -- Close the forward approach, leave the flanks clear. It can be
    -- interrupted like the ordinary cast; the three marks never chase.
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
      marks = {
        -- Place the barrier at the creature, not underneath the camera:
        -- its silhouette/gesture and the forward floor remain readable.
        { forward = 0.9, lateral = -1.25, delay = 0.6 },
        { forward = 1.3, lateral = 0, delay = 0.6 },
        { forward = 0.9, lateral = 1.25, delay = 0.6 },
      },
      packet = packet(8, 0, 'poison'),
    }),
  },
})
