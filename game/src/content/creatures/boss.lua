-- Margrave of Ash: the guardian of the first circle (boss template).
local Creature = require('src.content.defs.creature')
local Action = require('src.content.defs.action')
local packet = require('src.content.defs.packet').new
return Creature.boss({
  id = 'boss',
  name = 'creature_boss',
  souls = 150,
  catalog = { field = 5 },
  guardian = true,
  appearance = {
    portal = { 1, 0.30, 0.08 },
    shadow = 2,
    stature = 'large',
    casts = { all = true },
    cast = { size = 0.85, height = 2.2 },
    deathStain = 1.5,
    fieldRing = 0.7,
    banner = {
      calm = 'creature_boss_calm',
      fury = 'creature_boss_fury',
      exposed = 'creature_boss_exposed',
      plainFury = 'creature_boss_plain_fury',
    },
  },
  body = {
    hp = 1000,
    armor = 30,
    -- An ash lord: fire barely warms it.
    resist = { astral = 0.15, fire = 0.4 },
    -- Weak point (Doom Eternal): the bare skull carries no armour.
    locationArmor = { head = 0, torso = 30, lower = 45 },
    mass = 1 / 0.12,
    -- Two point-blank volleys or ~7 Judge rounds make the Margrave falter.
    poise = 300,
    struck = 'metal',
    aimY = 1.6,
    microStun = 0.035,
  },
  move = { speed = 2.2, accel = 8, ideal = 5.5 },
  sounds = { alert = 'growl', windup = 'growl', strike = 'cast' },
  phases = {
    { id = 'ash', tactics = { moves = { { attack = 'ember-fan', ideal = 5 } } } },
    {
      id = 'cinders',
      at = 0,
      refill = 0.4,
      recovery = 1.4,
      pace = 1.2,
      speed = 1.1,
      tactics = {
        repeatPenalty = 0.2,
        moves = {
          { attack = 'ember-fan', ideal = 5, weight = 1 },
          { attack = 'ash-lance', ideal = 8, weight = 1.2, min = 2.5 },
        },
      },
    },
  },
  attacks = {
    Action.fan({
      id = 'ember-fan',
      range = 11,
      windup = 0.9,
      recover = 0.75,
      speed = 4.6,
      rageSpeed = 5.3,
      count = 5,
      rageCount = 7,
      spread = 0.19,
      aimLead = 0.5,
      height = 1.9,
      big = true,
      color = { 0.95, 0.38, 0.12 },
      packet = packet(22, 60, 'fire'),
      line = {
        every = 2,
        count = 3,
        step = 1.65,
        delay = 1.1,
        radius = 1.05,
        life = 1.3,
        pulse = 0.45,
        packet = packet(8, 0, 'fire'),
      },
    }),
    -- Same painted cast and projectile, another readable lane: narrow,
    -- quicker flight, longer warning. No new model or invisible hitbox.
    Action.fan({
      id = 'ash-lance',
      range = 11,
      minRange = 2.5,
      windup = 1.05,
      recover = 0.9,
      cooldown = 1.5,
      rest = 3.8,
      speed = 6.2,
      count = 3,
      spread = 0.11,
      aimLead = 0.65,
      height = 1.9,
      big = true,
      color = { 0.95, 0.38, 0.12 },
      packet = packet(22, 60, 'fire'),
    }),
  },
})
