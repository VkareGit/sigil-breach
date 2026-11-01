-- Iron Thrall: the Ember Thrall in iron (variant: same atlas and AI family).
local Creature = require('src.content.defs.creature')
local Action = require('src.content.defs.action')
local packet = require('src.content.defs.packet').new
return Creature.define({
  extends = require('src.content.creatures.imp'),
  id = 'armored',
  kind = 'imp',
  variant = 'armored',
  name = 'creature_armored',
  souls = 12,
  catalog = {
    field = 2,
    bestiary = {
      order = 4,
      text = 'creature_armored_text',
      tip = 'creature_armored_tip',
      color = 'blue',
    },
  },
  -- Its own sheet; it does not leap, so it has no leap art of its parent.
  appearance = {
    atlas = 'armored',
    portal = { 0.66, 0.70, 0.78 },
    motion = 'heavy',
    art = { leap = false },
  },
  -- Armour protects from a major wound: a Judge body shot (53.8) does not
  -- wound, a head shot (72.7) does: threshold 68.
  body = {
    hp = 260,
    armor = 60,
    -- Its plate covers the front: the legs are the way in.
    locationArmor = { head = 60, torso = 60, lower = 25 },
    mass = 1.4,
    woundAt = 0.26,
    struck = 'metal',
  },
  move = { speed = 3.8, accel = 16, heavy = true },
  sounds = { step = 'iron_step' },
  tactics = {
    moves = {
      { attack = 'claw', ideal = 1.6, max = 2.05, weight = 2 },
      { attack = 'cleave', ideal = 2.2, max = 2.8, weight = 3 },
      { attack = 'shoulder', ideal = 5, min = 2.6, weight = 1.5 },
      { attack = 'ground-slam', ideal = 2.4, max = 3.6, weight = 2.2 },
    },
  },
  attacks = {
    -- The thrall's claw with hyperarmour (guard x2 while it attacks).
    Action.lunge({
      id = 'claw',
      range = 2.05,
      windup = 0.56,
      lead = 0.24,
      lungeSpeed = 8,
      lungeTime = 0.22,
      recover = 0.42,
      cooldown = 0.8,
      hyper = 2,
      string = { into = 'cleave', gap = 0.16, every = 2 },
      packet = packet(30, 70),
    }),
    -- Shoulder charge: closes 2.6-8 m in a straight rush; a leg shot or a
    -- dodge answers it, a Judge round into it breaks the hyperarmour. Every
    -- other one it feints: the body stays lowered.
    Action.charge({
      id = 'shoulder',
      minRange = 2.6,
      range = 8,
      rest = 3.0,
      windup = 0.8,
      hold = { 0, 0.45 },
      lead = 0.45,
      speed = 10.5,
      minTime = 0.25,
      maxTime = 0.7,
      contactY = 1.0,
      contactRadius = 0.4,
      reach = 0.5,
      recover = 0.9,
      cooldown = 1.0,
      hyper = 2,
      packet = packet(38, 120),
    }),
    -- A full swing: leave its arc, it cannot turn after the windup. Its long
    -- rest is the way in.
    Action.sweep({
      id = 'cleave',
      range = 2.8,
      rest = 3.4,
      windup = 0.72,
      hold = { 0, 0.3 },
      hyper = 2.5,
      reach = 2.7,
      arc = 2.4,
      active = { 0.08, 0.22 },
      lungeSpeed = 4,
      lungeTime = 0.16,
      duration = 0.34,
      recover = 1.05,
      cooldown = 1.2,
      packet = packet(42, 120),
    }),
    -- The fist driven into the floor: a low ring to jump, and a long rest.
    Action.wave({
      id = 'ground-slam',
      windupSound = 'furnace_warning',
      sound = 'ground_sunder',
      range = 3.6,
      rest = 6,
      windup = 0.86,
      hyper = 2,
      speed = 8,
      reach = 4.6,
      duration = 0.4,
      recover = 1.2,
      cooldown = 1.3,
      packet = packet(26, 90),
    }),
  },
})
