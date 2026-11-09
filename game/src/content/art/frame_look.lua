-- How the renderer shows a frame (render/renderer.lua): the shapes of its
-- small meshes, how a body brightens, the tracers, the warmth of the hands
-- in a muzzle flash and the heartbeat of low health. Lengths are in metres,
-- times in seconds; a colour is { r, g, b, a }.
return {
  -- The window the renderer starts at, before the first layout.
  startWidth = 1280,
  startHeight = 720,
  -- Nothing nearer than this to the eye is projected.
  near = 0.1,
  clear = { 0.035, 0.02, 0.035 },
  border = { 0.008, 0.007, 0.011 },
  -- A spark of an effect, and how many burn at once.
  spark = { lift = -0.025, half = 0.045, color = { 1, 1, 1, 0.6 }, count = 240 },
  -- The seal mark drawn on the ground: two rings and a pentagram.
  sigil = {
    outer = { radius = 0.48, width = 0.025 },
    inner = { radius = 0.37, width = 0.015 },
    sides = 40,
    star = { reach = 0.36, width = 0.012, sides = 5 },
  },
  warning = { width = 0.035, color = { 1, 1, 1, 0.7 }, sides = 40 },
  -- The soft dark disc under a body, and how many fit in one batch.
  shadow = {
    radius = 0.44,
    height = 0.006,
    color = { 0.025, 0.018, 0.025, 0.05 },
    sides = 24,
    count = 2048,
  },
  -- A stain on the floor: a disc and seven drops round it.
  stain = {
    radius = 0.45,
    height = 0.003,
    color = { 1, 1, 1, 0.05 },
    sides = 16,
    turn = 2.4,
    near = 0.22,
    step = 0.14,
    drop = 0.04,
    dropStep = 0.025,
    dropSides = 7,
  },
  -- Tracers drawn at once.
  tracers = 64,
  tracer = { width = 0.009, alpha = 0.46, swept = 0.18 },
  -- A body's brightening (R.tell): how fast a hit, a wound and a break fade
  -- in (per second of their timers) and how bright a break shows; the pulse
  -- of the last instant of a windup; the slow glow of an exposed body.
  tell = {
    hit = 13,
    wound = 5,
    broke = 7,
    brokeGlow = 0.85,
    last = 0.18,
    base = 0.35,
    pulse = 0.30,
    pulseRate = 40,
    exposed = 0.30,
    exposedPulse = 0.28,
    exposedRate = 4.7,
  },
  -- A body in torchlight: how strongly the light's direction turns into its
  -- lit side, the muzzle flash on it, its brightest, and how the flash
  -- flattens its key light.
  body = { direction = 4, flash = 2.4, brightest = 1.05, side = 6, flatten = 3 },
  -- The sky's brightness where the map says nothing.
  skyGain = 0.54,
  -- The muzzle flash on the hands: how fast it fades in and the warmth it
  -- adds to each channel; the floor's tint toward cold in green and blue.
  hands = { flash = 16, warm = { 0.40, 0.22, 0.06 }, floorGreen = 0.97, floorBlue = 0.95 },
  -- Low health: the heartbeat's rate (and how much faster when lower), its
  -- first and second beat, and the share of the effect that always shows.
  heartbeat = {
    rate = 1.05,
    faster = 0.55,
    first = 9,
    second = 0.6,
    gap = 0.18,
    secondFade = 11,
    floor = 0.55,
    swing = 0.45,
  },
  -- A kill's punch on the frame, per second of its timer.
  kill = 7,
}
