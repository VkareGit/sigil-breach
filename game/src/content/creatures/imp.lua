-- Ember Thrall: the common melee demon. Only what differs from the body,
-- movement and action defaults (content/defs/*).
local Creature = require('src.content.defs.creature')
local Action = require('src.content.defs.action')
local packet = require('src.content.defs.packet').new
return Creature.define({
  id = 'imp',
  name = 'creature_imp',
  souls = 4,
  catalog = {
    field = 1,
    bestiary = {
      order = 1,
      text = 'creature_imp_text',
      tip = 'creature_imp_tip',
      color = 'red',
    },
  },
  appearance = {
    portal = { 1, 0.42, 0.14 },
    art = { leap = 'leap' },
  },
  -- 0.20: survives one volley at 8 m (~102), dies point blank (240) and when
  -- two thralls share one close volley (~120 each): the multi-kill stays.
  -- A long collapse: settled after 0.44 s, on the floor at 0.22 s.
  body = { hp = 112, corpse = { settle = 0.44, landing = 0.22 } },
  -- Below the knight's running speed; the committed leap closes the gap.
  move = { speed = 4.3, accel = 20, style = 'flank' },
  sounds = { step = 'cloven_step', alert = 'snarl', windup = 'snarl', strike = 'claw' },
  attacks = {
    Action.lunge({
      id = 'claw',
      range = 2.05,
      windup = 0.54,
      lead = 0.24,
      lungeSpeed = 8,
      lungeTime = 0.22,
      recover = 0.34,
      cooldown = 0.65,
      packet = packet(20, 55),
    }),
    -- Gap closer: a ballistic leap under world gravity onto the spot where
    -- the player will be (lead). Readable crouch, dodgeable arc; shot in the
    -- air it is a counter-hit and a broken guard drops it out of the sky.
    Action.leap({
      id = 'leap',
      minRange = 2.6,
      range = 7.5,
      rest = 1.8,
      windup = 0.45,
      -- Predicted share of the player's motion until landing, rising to 1
      -- with the tier's aim lead.
      leadShare = 0.9,
      recover = 0.45,
      cooldown = 0.6,
      packet = packet(24, 80),
    }),
  },
})
