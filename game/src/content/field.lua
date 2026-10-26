-- Values of the proving ground's inspection tools; never combat balance.
-- Its numbers (run/test_field.lua and run/field/*): its limits, where its
-- targets may stand, where the knight is set, its stations' layout.
-- Distances in metres, times in seconds.
return {
  -- The low-resources preview's health; the TIER dial's highest tier.
  lowHealth = 25,
  maxTier = 5,
  -- Live demons and open gates at once.
  limit = 20,
  -- The souls of its unsaved trial shop.
  wallet = 1000,
  -- Where a reset, the shop and the range set the knight (the nave's foot).
  start = { x = 16, z = 27.5 },
  -- The ward a skirmish and a wave trial begin with.
  armor = 40,
  -- A catalogue demon set on the knight remembers him memory s and strikes
  -- after firstBlow s.
  engage = { memory = 60, firstBlow = 1.2 },
  -- A target stands at least near m from the knight and spacing m from
  -- others: first on rings ahead of him (offsets across his view), else on
  -- any free cell within search m, nearest first.
  placement = {
    near = 3,
    spacing = 1.8,
    rings = { 6, 9, 12, 4 },
    offsets = { 0, -2.1, 2.1, -4.2, 4.2 },
    search = 16,
  },
  -- Visiting a seal: the knight stands on the first clear spot (clearance m
  -- of his body, crowd m from any target) on circles of radii, at around
  -- points each, looking down at pitch rad.
  seal = { clearance = 0.28, crowd = 2.2, radii = { 3, 4.5, 6 }, around = 16, pitch = 0.08 },
  -- Stations: a felled dummy stands again after raise s; a label floats
  -- labelHeight m up.
  raise = 1.5,
  labelHeight = 0.35,
  -- Range: dummies at { distance, across } from the start, looking down
  -- the nave.
  range = { lanes = { { 4, -1.7 }, { 8, 2.1 }, { 12, -2.4 }, { 16, 2.4 }, { 20, 0 } } },
  -- Physics: the knight's stand, a domino row (first body, spacing, count),
  -- the wall-slam dummy, and how high the trip label floats.
  physics = {
    stand = { x = 16, z = 24.5 },
    domino = { x = 16, z = 21.4, step = 0.8, count = 3 },
    slam = { x = 22.6, z = 27 },
    tripLabel = 2.1,
  },
  -- The wave trial runs the waves up to this one (the guardian's).
  lastWave = 5,
}
