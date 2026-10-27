-- Furfur, Storm Count: antlered boss with a charge and lightning.
local Creature = require('src.content.defs.creature')
local Action = require('src.content.defs.action')
local packet = require('src.content.defs.packet').new
return Creature.boss({
  id = 'furfur',
  name = 'creature_furfur',
  catalog = { field = 6 },
  appearance = {
    portal = { 0.86, 0.86, 1 },
    stature = 'large',
    casts = { lightning = true },
    fieldRing = 0.85,
    banner = {
      calm = 'creature_furfur_calm',
      fury = 'creature_furfur_fury',
      exposed = 'creature_furfur_exposed',
      plainFury = 'creature_furfur_plain_fury',
    },
  },
  body = {
    hp = 1400,
    -- A long collapse: settled after 0.44 s, on the floor at 0.22 s.
    corpse = { settle = 0.44, landing = 0.22 },
    armor = 35,
    locationArmor = { head = 0, torso = 35, lower = 50 },
    mass = 1 / 0.12,
    poise = 400,
    radius = 0.55,
    struck = 'bone',
    aimY = 1.55,
  },
  move = { speed = 2.6, accel = 8 },
  sounds = { alert = 'growl', windup = 'growl', strike = 'antler' },
  tactics = {
    repeatPenalty = 0.2,
    moves = {
      { attack = 'melee', ideal = 1.5, max = 3, weight = 1.5 },
      { attack = 'charge', ideal = 6, min = 3, weight = 1 },
      { attack = 'lightning', ideal = 8, weight = 0.9 },
    },
  },
  phases = {
    { id = 'storm' },
    {
      id = 'tempest',
      at = 0,
      refill = 0.5,
      recovery = 1.5,
      pace = 1.25,
      speed = 1.12,
      tactics = {
        repeatPenalty = 0.15,
        moves = {
          { attack = 'melee', ideal = 1.5, max = 3.2, weight = 1.6 },
          { attack = 'charge', ideal = 5, min = 2.5, weight = 1.2 },
          { attack = 'lightning', ideal = 7, weight = 1.2 },
        },
      },
    },
  },
  attacks = {
    Action.lunge({
      id = 'melee',
      maxRange = 3,
      range = 11,
      windup = 0.75,
      lungeSpeed = 3,
      lungeTime = 0.20,
      duration = 0.32,
      recover = 0.75,
      packet = packet(24, 120),
    }),
    -- push 230: the charge can drive the knight into a wall (3.4 m/s > 3.2).
    Action.charge({
      id = 'charge',
      rest = 4.0,
      range = 11,
      every = 2,
      windup = 0.95,
      speed = 12,
      minTime = 0.30,
      maxTime = 0.85,
      contactY = 1.18,
      contactRadius = 0.42,
      reach = 0.75,
      recover = 0.75,
      packet = packet(28, 160, 'physical', 230),
    }),
    Action.strike({
      id = 'lightning',
      rest = 3.4,
      range = 11,
      windup = 1.1,
      duration = 0.32,
      recover = 0.75,
      radius = 1.25,
      life = 0.22,
      sound = 'thunder',
      packet = packet(30, 90, 'lightning'),
    }),
  },
})
