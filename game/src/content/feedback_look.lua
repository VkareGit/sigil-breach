-- The smaller presentation numbers of feedback/ (PLAN G7), by the module that
-- reads them. Metres, seconds, px of the 450 px scene where it says so.
return {
  -- feedback/shot_trails.lua: a short powder-coloured exposure of a shot.
  traces = {
    limit = 64,
    shortest = 0.02,
    start = 0.30,
    life = 0.038,
    lifePerMetre = 0.0011,
    longest = 24,
    strong = { color = { 0.68, 0.53, 0.32 }, width = 0.55 },
    light = { color = { 0.76, 0.61, 0.39 }, width = 0.78 },
    head = 0.55,
    headRate = 2.1,
  },
  -- feedback/transients.lua: specks of a burst, spent cases, damage numbers.
  transients = {
    limit = 240,
    force = 2,
    life = 0.4,
    lifeSpread = 0.5,
    size = 0.4,
    sizeSpread = 0.6,
  },
  shells = {
    gravity = 520,
    spin = 8,
    bouncedSpin = 3,
    floor = 90,
    bounce = 0.24,
    slide = 0.65,
    sound = 0.12,
    friction = 12,
  },
  damageNumbers = { life = 0.7, limit = 24, rise = 0.15 },
  -- feedback/listeners.lua: a hit's clots, a kill's voice and captions.
  hits = {
    clots = 3,
    clotsGain = 5,
    speed = 0.7,
    speedGain = 1.6,
    blood = 0.28,
    bloodGain = 0.48,
    otherSpecks = 4,
    otherSpeed = 1.0,
  },
  kills = {
    fade = 0.025,
    voice = 0.65,
    priority = 2,
    healed = 0.22,
    worldKill = 0.65,
    destroyedCaption = 1.8,
    perfectDodgeCaption = 1.2,
  },
  -- feedback/effects.lua: how many at once, a default size, the decals.
  effects = {
    limits = { effects = 48, decals = 40, smoke = 8 },
    size = 0.65,
    decalTurnX = 13,
    decalTurnZ = 17,
    turn = 6.28,
    decalLife = 24,
  },
  -- feedback/movement_marks.lua: the spread of a spray's specks.
  sprays = {
    ringJitter = 0.6,
    speed = 0.5,
    speedSpread = 0.5,
    up = 0.6,
    upSpread = 0.4,
    cross = 0.3,
    lifeSpread = 0.5,
    size = 0.75,
    sizeSpread = 0.5,
    still = 0.1,
  },
  -- feedback/gait.lua: each half-cycle plants one foot (pi / 2.5 = 1.257 m).
  gait = { radiansPerMetre = 2.5 },
}
