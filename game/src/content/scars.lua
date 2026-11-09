-- The small painted scars a shot leaves on the arena (feedback/surface_marks.lua,
-- PLAN G7): how many, how long, and where on the visible surface they sit (m).
return {
  limit = 96,
  duration = 36,
  fade = 6,
  path = 'assets/art/impact-scars-v17.png',
  -- A normal steeper than this is a floor, a ceiling or a cap.
  flat = 0.7,
  -- Visible lime stands 4 mm proud of the floor, the ceiling and a cap.
  proud = 0.004,
  -- The panel behind a wall contact is looked up this far into the wall.
  probe = 0.12,
  -- On a wall: lime 1.4 cm proud; every third wall carries a niche panel
  -- (its trim, then its fillet) between these heights, unless it is a mural.
  wall = 0.014,
  niche = { every = 3, half = 0.46, low = 0.55, high = 3.35, offset = 0.0692 },
  fillet = { half = 0.0175, low = 0.7, high = 2.95, offset = 0.0865 },
  -- The shot meets the proud plane along its own ray; too grazing, no scar.
  grazing = -0.04,
  detached = 0.75,
  -- Size by root normal energy, within these bounds.
  size = { base = 0.060, gain = 0.012, low = 0.065, high = 0.23 },
  -- Pellets this close (share of the smaller scar) on one plane deepen it.
  coplanar = 0.99,
  overlap = 0.24,
  deepen = 1.035,
  deepest = 0.25,
  -- Atlas frames by material, the golden turn, and the stretch of a graze.
  stoneFrame = 3,
  turn = 2.39996323,
  stretch = 0.65,
  opacity = 0.91,
}
