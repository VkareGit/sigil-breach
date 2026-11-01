-- Iron Thrall: the Ember Thrall in iron (variant: same atlas and AI family).
local Creature = require('src.content.defs.creature')
local Action = require('src.content.defs.action')
local packet = require('src.content.defs.packet').new
return Creature.define({
  extends = require('src.content.creatures.imp'),
  id = 'armored',
  -- It moves and fights as its kind; variant is what it is to the art and the catalogue.
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
    hp = 560,
    poise = 150,
    -- Its plate covers what it faces, and it turns slowly: walk around it.
    front = 0.4,
    breakTime = 2,
    execution = 0.5,
    armor = 60,
    -- Its plate covers the front: the legs are the way in.
    locationArmor = { head = 60, torso = 60, lower = 25 },
    mass = 1.4,
    woundAt = 0.26,
    struck = 'metal',
  },
  move = { speed = 3.8, accel = 16, heavy = true, turn = 1.8 },
  answers = {
    { when = 'behind', attack = 'back-swing', rest = 4, within = 3.6 },
    { when = 'hugging', attack = 'ground-slam', rest = 6, within = 2.4, after = 1.2 },
  },
  sounds = { step = 'iron_step' },
  tactics = {
    roll = true,
    moves = {
      { attack = 'claw', ideal = 1.6, max = 2.05, weight = 2 },
      { attack = 'cleave', ideal = 3, max = 4.6, weight = 3 },
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
      -- It leans after a knight who stepped aside early and rushes again if it missed.
      bend = 1.6,
      turns = 1,
      turnPause = 0.4,
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
      range = 4.6,
      rest = 3,
      windup = 0.72,
      hold = { 0, 0.3, 0.55 },
      shuffle = true,
      turn = 2.2,
      lockAt = 0.7,
      steady = true,
      mirror = true,
      chase = 1.8,
      hyper = 2.5,
      trace = {
        { at = 0.08, angle = -1.3, reach = 2.7, height = 1.4 },
        { at = 0.24, angle = 1.3, reach = 2.8, height = 1 },
      },
      lungeSpeed = 12,
      lungeTime = 0.18,
      closing = 0.6,
      duration = 0.36,
      recover = 1.05,
      cooldown = 1.2,
      packet = packet(46, 120),
    }),
    -- Who gets behind the plate meets the elbow: slow to turn, not helpless.
    Action.sweep({
      id = 'back-swing',
      range = 3.6,
      windup = 0.5,
      turn = 4,
      lockAt = 0.8,
      steady = true,
      mirror = true,
      trace = {
        { at = 0.06, angle = -1.6, reach = 2.6, height = 1.3 },
        { at = 0.2, angle = 1.6, reach = 2.6, height = 1.1 },
      },
      duration = 0.32,
      recover = 1.3,
      cooldown = 1.4,
      packet = packet(38, 100),
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
