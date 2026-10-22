-- Ember Thrall: the common melee demon. Only what differs from the body,
-- movement and action defaults (content/defs/*).
local Creature = require('src.content.defs.creature')
local Action = require('src.content.defs.action')
local packet = require('src.content.defs.packet').new
return Creature.define({
  id = 'imp',
  name = 'Ember Thrall',
  souls = 4,
  appearance = {
    layout = 'extended',
    portal = { 1, 0.42, 0.14 },
    art = { leap = 'leap' },
  },
  -- 0.20: survives one volley at 8 m (~102), dies point blank (240) and when
  -- two thralls share one close volley (~120 each): the multi-kill stays.
  body = { hp = 112 },
  -- 0.21: 4 m/s (76 % of the player) with mass-limited acceleration.
  move = { speed = 4.0, accel = 18, style = 'flank' },
  sounds = { alert = 'snarl', windup = 'snarl', strike = 'claw' },
  attacks = {
    Action.lunge({
      id = 'claw',
      range = 2.05,
      windup = 0.54,
      lungeSpeed = 5.8,
      lungeTime = 0.18,
      cooldown = 1.0,
      packet = packet(15, 55),
    }),
    -- Gap closer: a ballistic leap under world gravity onto the spot where
    -- the player will be (lead). Readable crouch, dodgeable arc; shot in the
    -- air it is a counter-hit and a broken guard drops it out of the sky.
    Action.leap({
      id = 'leap',
      minRange = 3.5,
      range = 7.5,
      rest = 2.6,
      windup = 0.45,
      -- Predicted share of the player's motion until landing, rising to 1
      -- with the tier's aim lead.
      leadShare = 0.6,
      recover = 0.55,
      cooldown = 0.8,
      packet = packet(18, 80),
    }),
  },
})
