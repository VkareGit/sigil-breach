-- How the damage numbers stand over the scene (render/numbers.lua): their
-- colours, sizes, drift and how they keep clear of the aim. Sizes are in
-- pixels of a 600-pixel-high view, times in seconds.
return {
  -- How many show at once and how long one lives.
  limit = 24,
  lifetime = 0.7,
  colors = {
    body = { 0.96, 0.92, 0.82 },
    armor = { 0.70, 0.78, 0.86 },
    head = { 1, 0.86, 0.52 },
    broke = { 1, 0.80, 0.30 },
    wound = { 1, 0.52, 0.50 },
    kill = { 1, 0.62, 0.36 },
    -- 0.20: a counter-hit glows ember red, a crippling leg hit pale ochre.
    counter = { 1, 0.42, 0.24 },
    crippled = { 0.86, 0.76, 0.52 },
  },
  -- The contact is tested a little below the label, and only beyond near;
  -- a wall within slack of it does not hide it.
  contact = { below = 0.15, near = 0.1, slack = 0.035 },
  referenceHeight = 600,
  margin = 8,
  gap = 5,
  -- The square round the aim no label covers (half its side).
  aimHalf = 25,
  -- Height of a big number (a kill, a head, a wound, a break, a counter) and
  -- of the rest; the pop of a fresh one (a break pops more) and how fast it
  -- settles (per second).
  big = 32,
  small = 26,
  pop = 0.14,
  breakPop = 0.24,
  settle = 8,
  -- The widest a label may be: pixels, and a share of the view.
  widest = 150,
  widestShare = 0.23,
  -- Its drift beside the contact and up over its life.
  side = 30,
  sideDrift = 12,
  rise = 12,
  riseDrift = 24,
  -- It fades over the last part of its life.
  fade = 2.2,
}
