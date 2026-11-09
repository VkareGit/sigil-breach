-- How a summoning portal is painted over the spawner's clock
-- (render/portals.lua): its sheet, the frames of its opening and of an
-- arrival, its size and its medallion. Times are in seconds, lengths in
-- metres.
return {
  path = 'assets/art/portal-fresco-v23.png',
  -- The opening when the gate names no delay.
  delay = 1.2,
  -- The opening's frames by progress: the first three end at these shares;
  -- the last frame shows from done on; between, three frames cycle at rate.
  opening = { 0.15, 0.35, 0.60 },
  done = 0.90,
  cycle = 18,
  -- An arrival shows for this long, its three frames ending at these ages.
  arrival = 0.6,
  arrivalFrames = { 0.16, 0.38 },
  -- The creature's colour in the portal's tint: base and share.
  tint = { base = 0.72, share = 0.28 },
  size = 2.75,
  largeSize = 3.6,
  lift = 0.018,
  -- A gate: its shadow (lift, size and growth, opacity and growth), its
  -- medallion (lift, radius and shrink, opacity and growth) and its
  -- painting (opacity and growth, brightness and growth).
  gate = {
    shadowLift = 0.014,
    shadow = 0.9,
    shadowGrow = 0.8,
    shadowAlpha = 0.25,
    shadowAlphaGrow = 0.35,
    medallionLift = 0.033,
    medallion = 1.55,
    medallionShrink = 0.65,
    medallionAlpha = 0.55,
    medallionAlphaGrow = 0.4,
    alpha = 0.9,
    alphaGrow = 0.1,
    bright = 0.85,
    brightGrow = 0.22,
  },
  -- An arrival: the medallion (lift, radius, opacity) and the painting's
  -- brightness and its fall.
  arriving = { lift = 0.028, medallion = 1.4, alpha = 0.75, bright = 1.05, dim = 0.25 },
}
