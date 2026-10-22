-- The original three-seal trial (classic mode) as level data: who waits in
-- it, what lies on its floor, what its secret, seals and guardian give and
-- how a finished trial is ranked. Its rules are in session/interactions.lua.
local Tuning = require('src.content.tuning')
return {
  -- The map the trial is laid out on.
  map = 'limbo',
  -- Spawned when any session is built, in this order (seeded randomness that
  -- replays and QA rely on is consumed by it): kind, x, z.
  garrison = { { 'imp', 16, 22 }, { 'imp', 14, 16 }, { 'stolas', 18, 12 } },
  supplies = {
    { x = 13.5, z = 26, kind = 'ammo', amount = Tuning.ammoPickup },
    { x = 18.5, z = 26, kind = 'health', amount = Tuning.healthPickup },
    { x = 5, z = 17, kind = 'ammo', amount = Tuning.ammoPickup },
    { x = 27, z = 17, kind = 'health', amount = Tuning.healthPickup },
    { x = 17, z = 7, kind = 'ammo', amount = Tuning.ammoPickup },
  },
  -- How close (m) the knight must stand to use each thing.
  reach = { secret = 1.4, seal = 2.1, portal = 2.6 },
  -- Shotgun rounds and ward never exceed these here.
  maxRounds = 72,
  maxWard = 100,
  secret = { x = 3.7, z = 20.4, ward = 35, rounds = 16, score = 500 },
  -- A broken seal: a surge, a burst at height m, ward, and an ambush of a
  -- leader and two thralls at the seal's own spots (x, z), who know where
  -- the knight is for memory s.
  seal = {
    surge = 0.6,
    burstHeight = 1.8,
    burst = 40,
    burstSpeed = 3,
    ward = 15,
    memory = 5,
    ambush = {
      { leader = 'buer', spots = { { 4, 13 }, { 9, 19 }, { 9, 13 } } },
      { leader = 'stolas', spots = { { 24, 13 }, { 28, 19 }, { 23, 20 } } },
      { leader = 'buer', spots = { { 11, 3 }, { 21, 3 }, { 18, 8 } } },
    },
    thrall = 'imp',
  },
  -- The guardian rises when the three seals are broken and the court is
  -- clear; the knight is given health, rounds and ward.
  guardian = { kind = 'boss', x = 16, z = 8, health = 30, rounds = 18, ward = 20 },
  -- Rank S: under time s with under damage taken; A: under time s; else B.
  rank = { S = { time = 180, damage = 100 }, A = { time = 300 } },
}
