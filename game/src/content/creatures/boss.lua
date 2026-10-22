-- Margrave of Ash: the guardian of the first circle (boss template).
local Creature = require('src.content.defs.creature')
local Action = require('src.content.defs.action')
local packet = require('src.content.defs.packet').new
return Creature.boss({
  id = 'boss',
  name = 'Margrave of Ash',
  souls = 150,
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
      calm = 'MARGRAVE OF ASH',
      fury = 'MARGRAVE / FURY',
      exposed = 'MARGRAVE / EXPOSED',
      plainFury = 'MARGRAVE OF ASH / FURY',
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
  },
})
