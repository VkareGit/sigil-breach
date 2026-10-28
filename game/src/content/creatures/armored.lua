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
  body = { hp = 170, armor = 60, mass = 1.4, woundAt = 0.40, struck = 'metal' },
  move = { speed = 3.0, accel = 12, heavy = true },
  sounds = { step = 'iron_step' },
  attacks = {
    -- The thrall's claw with hyperarmour (guard x2 while it attacks).
    { from = 'claw', hyper = 2, packet = packet(15, 70) },
    -- 0.24 shoulder charge: closes 3-7 m in a straight rush; a leg shot or a
    -- dodge answers it, a Judge round into it breaks the hyperarmour.
    Action.charge({
      id = 'shoulder',
      minRange = 3,
      range = 7,
      rest = 4.5,
      windup = 0.8,
      speed = 8.5,
      minTime = 0.25,
      maxTime = 0.7,
      contactY = 1.0,
      contactRadius = 0.4,
      reach = 0.5,
      recover = 0.9,
      cooldown = 1.0,
      hyper = 2,
      packet = packet(20, 120),
    }),
  },
})
