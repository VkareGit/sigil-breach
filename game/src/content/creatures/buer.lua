-- Plague Gardener: spits venom that leaves a poison pool.
local Creature = require('src.content.defs.creature')
local Action = require('src.content.defs.action')
local packet = require('src.content.defs.packet').new
return Creature.define({
  id = 'buer',
  name = 'Plague Gardener',
  souls = 12,
  catalog = {
    field = 4,
    bestiary = {
      order = 3,
      text = 'Leaves venom pools.',
      tip = 'Leave the marked ring.',
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
  sounds = { alert = 'growl', windup = 'growl', strike = 'cast' },
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
  },
})
