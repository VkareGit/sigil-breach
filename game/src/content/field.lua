-- Values of the proving ground's inspection tools; never combat balance.
-- Its numbers (run/test_field.lua and run/field/*): its limits, where its
-- targets may stand, where the knight is set, its stations' layout.
-- Distances in metres, times in seconds.
return {
  altar = { top = 1.046, reach = 1.85 }, -- painted pedestal surface and walk-up interaction
  -- Names used by optional tool requirements. Availability is per session;
  -- new tool families declare their feature here, not in application branches.
  toolFeatures = { trade = true },
  -- The creature its posts and rows are made of, and who a skirmish meets.
  dummy = 'imp',
  skirmish = { 'imp', 'imp', 'stolas' },
  -- The low-resources preview's health.
  lowHealth = 25,
  -- The bench of a blow (app/field_tools.lua): the speeds of time, and one step.
  bench = { times = { 1, 0.5, 0.25, 0 }, stepTicks = 4 },
  -- Live demons and open gates at once.
  limit = 20,
  -- The souls of its unsaved trial shop.
  wallet = 1000,
  -- Where a reset, the shop and the range set the knight (the nave's foot).
  start = { x = 16, z = 27.5 },
  -- The ward a skirmish begins with.
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
  -- Summoning gates (run/gates.lua). A gate glows glow s before its demon steps out,
  -- re-checked every retry s while the knight stands within clear m. What comes out
  -- hunts the knight for hunt s.
  gates = { glow = 1.2, retry = 0.35, clear = 2.5, hunt = 60 },
}
