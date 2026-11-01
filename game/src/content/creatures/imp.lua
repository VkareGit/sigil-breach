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
  -- Three clean volleys. Its lesson is the wait: the late claw, and a shot in the beat
  -- before it turns the claw aside.
  -- A long collapse: settled after 0.44 s, on the floor at 0.22 s.
  body = {
    hp = 360,
    poise = 140,
    breakTime = 1.4,
    execution = 0.6,
    corpse = { settle = 0.44, landing = 0.22 },
  },
  -- Below a knight walking on, above one backing away; the committed leap closes the gap.
  move = { speed = 4.6, accel = 20, style = 'flank', turn = 7 },
  answers = {
    { when = 'reloading', attack = 'leap', rest = 6 },
    { when = 'drinking', attack = 'leap', rest = 6 },
  },
  sounds = { step = 'cloven_step', alert = 'snarl', windup = 'snarl', strike = 'claw' },
  tactics = {
    roll = true,
    moves = {
      { attack = 'claw', ideal = 1.6, max = 2.05, weight = 2 },
      { attack = 'leap', ideal = 5, min = 2.6, weight = 1.5 },
      {
        attack = 'hop-back',
        ideal = 1.4,
        max = 2.4,
        weight = 14,
        after = { attack = 'claw-late', within = 1.3 },
      },
    },
  },
  attacks = {
    -- Every second claw goes on: a beat, then the late one.
    Action.lunge({
      id = 'claw',
      range = 2.05,
      windup = 0.54,
      lead = 0.24,
      lungeSpeed = 8,
      lungeTime = 0.22,
      recover = 0.34,
      cooldown = 0.65,
      turn = 8,
      lockAt = 0.7,
      parry = 0.18,
      string = {
        gap = 0.14,
        branches = { { into = 'claw-late', weight = 2 }, { into = 'hop-back' }, { weight = 1 } },
      },
      packet = packet(34, 55),
    }),
    -- Gap closer: a ballistic leap under world gravity onto the spot where
    -- the player will be (lead), the claw right behind it. Readable crouch,
    -- dodgeable arc; shot in the air it is a counter-hit and a broken guard
    -- drops it out of the sky.
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
      string = { into = 'pounce', gap = 0.12 },
      packet = packet(36, 80),
    }),
    -- Off the landing, at whoever stepped back from the leap: the step is as long as
    -- the gap, so the answer is across it, not away.
    Action.sweep({
      id = 'pounce',
      range = 6,
      windup = 0.3,
      turn = 8,
      lockAt = 0.6,
      trace = {
        { at = 0.06, angle = -0.7, reach = 2.4, height = 1.3 },
        { at = 0.14, angle = 0, reach = 2.6, height = 1.1 },
        { at = 0.22, angle = 0.7, reach = 2.4, height = 0.9 },
      },
      lungeSpeed = 13,
      lungeTime = 0.24,
      closing = 0.6,
      duration = 0.3,
      parry = 0.16,
      recover = 0.55,
      cooldown = 0.7,
      packet = packet(34, 55),
    }),
    -- It waits with the arm raised, watching: a dodge at the old beat is spent.
    Action.lunge({
      id = 'claw-late',
      range = 2.8,
      windup = 0.42,
      hold = { 0.1, 0.3, 0.55 },
      shuffle = true,
      turn = 8,
      lockAt = 0.8,
      parry = 0.18,
      lungeSpeed = 9,
      lungeTime = 0.22,
      recover = 0.62,
      cooldown = 0.8,
      packet = packet(34, 55),
    }),
    -- Out of the reach of the answer to a long string.
    Action.hop({
      id = 'hop-back',
      range = 2.4,
      windup = 0.12,
      speed = 7,
      lungeTime = 0.22,
      duration = 0.25,
      recover = 0.3,
      cooldown = 0.5,
    }),
  },
})
