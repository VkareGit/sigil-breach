-- How the ritual medallions and the goetic seals are drawn
-- (render/ritual_art.lua). Lengths are in metres; a tint is { r, g, b }.
return {
  path = 'assets/art/ritual-medallion-v31.png',
  -- The colour of the ritual ink.
  ink = { 0.88, 0.77, 0.58 },
  -- A dimmed medallion and the symbol on it.
  dim = { 0.58, 0.55, 0.50 },
  dimSymbol = { 0.47, 0.43, 0.36 },
  -- The symbol: how far above the medallion, and its share of the diameter.
  symbol = { lift = 0.002, share = 0.53 },
  -- The proving map's axis the pads and seals turn to face: across the hall
  -- at x, and the south pads beyond z. (A map datum held here until maps
  -- name their own facing.)
  axisX = 16,
  southZ = 28,
  pad = { lift = 0.024, diameter = 1.8 },
  seal = { diameter = 1.18 },
  -- A seal being summoned: the upright ink above its altar (lift, size, tint
  -- when complete and while drawn, and its softness), the glowing trace a
  -- few millimetres toward the viewer (tint and softness) and the glow of
  -- the medallion below (lift, growth, opacity, tint, softness).
  upright = {
    lift = 0.10,
    size = 1.55,
    complete = { 0.58, 0.51, 0.40 },
    drawing = { 1.0, 0.87, 0.66 },
    soft = 0.58,
  },
  trace = { toward = 0.003, tint = { 1, 0.92, 0.73 }, soft = 1.15 },
  glow = { lift = 0.006, grow = 0.15, alpha = 0.48, tint = { 1, 0.65, 0.32 }, soft = 0.85 },
  -- The curves of a summoning (render/seal_motion.lua): after it ends the
  -- glow fades over fadeOut from rest; the stroke is traced over reveal and
  -- its glow then decays at decay to a slow ember (base, pulse, rate); the
  -- ink lifts by lift over liftTime.
  summoning = {
    fadeOut = 0.9,
    rest = 0.25,
    reveal = 0.65,
    decay = 1.8,
    ember = 0.10,
    emberPulse = 0.025,
    emberRate = 2,
    lift = 0.16,
    liftTime = 1.6,
  },
}
