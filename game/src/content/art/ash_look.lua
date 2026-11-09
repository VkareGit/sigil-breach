-- The ash in the air of a fight (render/passes/ash.lua): grey ash falls and
-- every twelfth mote is a live cinder rising from the pit. Lengths are in
-- metres, rates per second; a colour is { r, g, b }.
return {
  -- The motes (the renderer's ash batch holds this many).
  count = 96,
  ash = { 0.30, 0.25, 0.22 },
  -- A dull cinder: a fire accent, not a bright speck.
  ember = { 1.25, 0.52, 0.16 },
  -- Where the motes are scattered: from start, over a square of span, by
  -- two steps that never line up.
  start = 2.5,
  span = 26,
  stepX = 7.31,
  stepZ = 3.71,
  cinderEvery = 12,
  -- A cinder rises (phase step, rate, top), sways (rate, reach) and is this
  -- big (base, step).
  cinder = {
    phase = 0.53,
    rate = 0.55,
    top = 4.6,
    swayRate = 1.7,
    sway = 0.30,
    size = 0.10,
    grow = 0.04,
  },
  -- Ash falls from top (phase step, rate), sways and is this big.
  fall = {
    top = 4.3,
    phase = 0.37,
    rate = 0.16,
    swayRate = 0.5,
    sway = 0.22,
    size = 0.12,
    grow = 0.06,
  },
}
