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
    seal = 'stolas',
    portal = { 0.48, 0.66, 1 },
    stain = { 0.10, 0.075, 0.055 },
    warning = { 0.82, 0.73, 0.52 },
    casts = { all = true },
    motion = 'hover',
    evadeArt = 'evade',
  },
  -- Catching it is the difficulty. Its long casts are the safest place to learn the
  -- counter: a shot at the right moment stops the spell from any distance.
  body = {
    hp = 240,
    breakTime = 1.6,
    execution = 0.6,
    resist = { astral = 0.25 },
    poise = 60,
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
  answers = {
    { when = 'hugging', attack = 'slip', rest = 4, within = 2.4, after = 0.4 },
    { when = 'drinking', attack = 'star', rest = 4, within = 11 },
  },
  sounds = { step = 'wing_fold', alert = 'owl', windup = 'owl', strike = 'cast' },
  tactics = {
    roll = true,
    moves = {
      { attack = 'star', ideal = 7, weight = 1 },
      { attack = 'talon-fan', ideal = 2.8, max = 4.2, weight = 2.5 },
      { attack = 'star-trio', ideal = 6, min = 3.5, weight = 1.4 },
      { attack = 'star-ray', ideal = 6, min = 3, weight = 1.1 },
      { attack = 'slip', ideal = 1.5, max = 3.2, weight = 5 },
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
      packet = packet(34, 40, 'astral'),
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
      packet = packet(34, 40, 'astral'),
    }),
    -- Three stars let go in turn: keep moving through all of them. It stays
    -- bound to the cast until the last has left.
    Action.salvo({
      id = 'star-trio',
      range = 10,
      rest = 5,
      windup = 0.95,
      parry = 0.45,
      parryReach = 14,
      speed = 10,
      count = 3,
      interval = 0.42,
      duration = 0.3,
      recover = 1.05,
      cooldown = 1.1,
      color = { 0.72, 0.58, 0.34 },
      packet = packet(34, 40, 'astral'),
    }),
    -- A ray across the floor, warned along its whole length.
    Action.beam({
      id = 'star-ray',
      range = 9,
      rest = 8,
      windup = 0.9,
      parry = 0.45,
      parryReach = 14,
      delay = 0.55,
      length = 9,
      arc = 1.5,
      spin = 1.7,
      duration = 0.5,
      recover = 1.3,
      cooldown = 1.4,
      packet = packet(40, 50, 'astral'),
    }),
    -- It will not be caught: gone, and behind a shoulder.
    Action.blink({
      id = 'slip',
      range = 3.2,
      rest = 5,
      windup = 0.34,
      distance = 6,
      duration = 0.2,
      recover = 0.5,
      cooldown = 0.5,
    }),
  },
})
