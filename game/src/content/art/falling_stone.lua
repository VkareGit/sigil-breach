-- Stones falling while a support comes down (render/kit/debris.lua): how long
-- the fall shows, how many stones, their shape, where they start and how
-- they fall. Lengths are in metres, times in seconds.
return {
  duration = 2.6,
  count = 72,
  -- One stone, about a metre across: its half sizes, seed and shade.
  half = { 0.5, 0.34, 0.42 },
  seed = 7,
  shade = 0.55,
  -- Every third stone comes from the pier itself: round it, at a height up
  -- the shaft, a little after the break.
  shaft = { reach = 0.55, rise = 7.5, delay = 0.3 },
  -- The rest are the roof it carried: high, and a little later.
  roof = { height = 10, rise = 5, delay = 0.12, wait = 0.9 },
  size = 0.22,
  sizeVary = 0.95,
  spin = 7,
  yaw = 6,
  -- Half of gravity (m/s²), where a stone rests (a share of its size) and
  -- how fast it sinks into the heap once landed.
  halfGravity = 4.9,
  rest = 0.25,
  sink = 0.4,
}
