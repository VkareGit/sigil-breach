-- Star Acolyte: a glass-cannon caster that keeps its distance.
local Creature = require('src.content.defs.creature')
local Action = require('src.content.defs.action')
local packet = require('src.content.defs.packet').new
return Creature.define({
  id = 'stolas',
  name = 'creature_stolas',
  souls = 8,
  catalog = {
    field = 3,
    bestiary = {
      order = 2,
      text = 'creature_stolas_text',
      tip = 'creature_stolas_tip',
      color = 'blue',
    },
  },
  appearance = {
    portal = { 0.48, 0.66, 1 },
    stain = { 0.10, 0.075, 0.055 },
    warning = { 0.82, 0.73, 0.52 },
    casts = { all = true },
    motion = 'hover',
    evadeArt = 'evade',
  },
  -- One volley at 8 m (~81) or one Judge head shot (94.5) kills; a Judge
  -- body shot (70) does not.
  body = {
    hp = 76,
    resist = { astral = 0.25 },
    poise = 30,
    blood = { 0.18, 0.30, 0.44 },
    -- A long collapse: settled after 0.44 s, on the floor at 0.22 s.
    corpse = { settle = 0.44, landing = 0.22 },
  },
  -- Evade: when the player aims at it, a short sidestep (tier 2 and up).
  move = {
    speed = 2.4,
    accel = 14,
    evade = { speed = 6.5, time = 0.24, cooldown = 3.5, fromTier = 2 },
  },
  sounds = { alert = 'owl', windup = 'owl', strike = 'cast' },
  attacks = {
    -- 0.21: faster than a running player; a change of direction dodges it.
    Action.bolt({
      id = 'star',
      range = 11,
      windup = 0.74,
      speed = 7.0,
      aimLead = 0.85,
      color = { 0.72, 0.58, 0.34 },
      packet = packet(14, 40, 'astral'),
    }),
  },
})
