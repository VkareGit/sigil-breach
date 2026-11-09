-- The forms of the small breakable things of a hall (render/kit/props.lua):
-- each kind whole and what it leaves. Lengths are in metres; a profile is
-- { radius, height } from the foot up; a shade darkens its light (1 = as lit).
return {
  -- Broken pieces scattered round a fall: how far out (a share of the
  -- spread, and its spread), their size (a share of the size, and its
  -- spread), their shape and their tilt.
  shards = {
    near = 0.3,
    far = 0.7,
    small = 0.5,
    vary = 0.8,
    lift = 0.4,
    long = 1.4,
    flat = 0.35,
    tilt = 0.6,
  },
  urn = {
    profile = {
      { 0.0, 0.0 },
      { 0.15, 0.0 },
      { 0.17, 0.05 },
      { 0.27, 0.26 },
      { 0.3, 0.42 },
      { 0.24, 0.6 },
      { 0.12, 0.72 },
      { 0.1, 0.78 },
      { 0.15, 0.84 },
      { 0.12, 0.84 },
      { 0.08, 0.76 },
    },
    broken = {
      { 0.0, 0.0 },
      { 0.15, 0.0 },
      { 0.17, 0.05 },
      { 0.25, 0.2 },
      { 0.2, 0.2 },
      { 0.12, 0.08 },
    },
    sides = 16,
    brokenSides = 12,
    wraps = 2,
    brokenShade = 0.9,
    -- The height its texture spans, as a share of its scale.
    span = 0.9,
    shards = { count = 9, spread = 0.62, size = 0.075 },
  },
  bench = {
    seat = { height = 0.46, thick = 0.035, half = 0.2 },
    back = { out = 0.22, height = 0.72, tall = 0.08, thick = 0.025 },
    legs = { along = 0.42, height = 0.22, thick = 0.04, half = 0.17 },
    -- Its broken planks on the floor.
    planks = 6,
    scatter = 0.5,
    rest = 0.05,
    plank = { long = 0.34, vary = 0.28, thick = 0.03, half = 0.08 },
    tilt = 0.25,
  },
  candles = {
    turn = 2.1,
    reach = 0.1,
    height = 0.16,
    taller = 0.05,
    foot = 0.042,
    head = 0.038,
    sides = 6,
    shade = 1.2,
    flame = { foot = 0.02, middle = 0.026, rise = 0.03, height = 0.1, sides = 5 },
    shards = { count = 4, spread = 0.2, size = 0.04 },
  },
}
