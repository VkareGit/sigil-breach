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
  -- Evasion reads the held aim, never the trigger or future player input.
  move = {
    speed = 3.4,
    accel = 14,
    evade = { speed = 6.5, time = 0.24, cooldown = 2.2, fromTier = 1 },
  },
  sounds = { step = 'wing_fold', alert = 'owl', windup = 'owl', strike = 'cast' },
  tactics = {
    moves = {
      { attack = 'star', ideal = 7, weight = 1 },
      { attack = 'talon-fan', ideal = 2.8, max = 4.2, weight = 2.5 },
    },
  },
  attacks = {
    -- 0.21: faster than a running player; a change of direction dodges it.
    Action.bolt({
      id = 'star',
      range = 11,
      windup = 0.74,
      recover = 0.34,
      cooldown = 0.72,
      speed = 11,
      aimLead = 1,
      leadFloor = 0.9,
      color = { 0.72, 0.58, 0.34 },
      packet = packet(20, 40, 'astral'),
    }),
    -- Readably wider at close range; no health/armour inflation. Bait it,
    -- change direction after the cast, then punish its longer recovery.
    Action.fan({
      id = 'talon-fan',
      range = 4.2,
      rest = 3.8,
      windup = 0.9,
      recover = 0.65,
      cooldown = 0.95,
      speed = 10,
      rageSpeed = 10,
      aimLead = 0.8,
      leadFloor = 1,
      count = 3,
      rageCount = 3,
      spread = 0.28,
      color = { 0.72, 0.58, 0.34 },
      packet = packet(20, 40, 'astral'),
    }),
  },
})
