-- How the renderer's effects look (render/effects.lua): the palette of
-- casts, the cut and the cast in the air, a thrown charge leaving the hand,
-- and the hitbox overlay of the proving ground. Lengths are in metres, times
-- in seconds; a colour is { r, g, b }.
return {
  colors = {
    coal = { 0.018, 0.016, 0.014 },
    bone = { 0.82, 0.73, 0.52 },
    ember = { 0.83, 0.39, 0.10 },
    brimstone = { 0.49, 0.41, 0.16 },
    blood = { 0.29, 0.018, 0.012 },
  },
  -- A cut: the share of its span it is drawn whole, and its opacity after.
  cut = { whole = 0.65, fading = 0.8 },
  -- A cast in the air: how far in front of the caster, and its opacity.
  cast = { ahead = 0.4, alpha = 0.72 },
  -- A thrown charge in the first instants by the eye: how long it fades in
  -- (at most, and as a share of its fuse), and the distance over which it
  -- does (from, over).
  handoff = { longest = 0.12, share = 0.25, from = 0.35, over = 0.55 },
  -- A charge in the world: its brightness, size and how far its painting
  -- hangs below its centre.
  charge = { brightness = 1.1, size = 0.4, drop = 0.16 },
  -- Diagnostic colours of the hitbox overlay, by what a part is.
  hitColors = {
    head = { 1, 0.84, 0.25 },
    torso = { 0.92, 0.25, 0.16 },
    lower = { 1, 0.58, 0.12 },
    blocks = { 0.35, 0.85, 0.95 },
    decorative = { 0.55, 0.42, 0.80 },
    shield = { 0.55, 0.55, 0.55 },
    body = { 1, 1, 1 },
    attack = { 1, 0.15, 0.10 },
    idle = { 0.45, 0.30, 0.28 },
  },
  -- The overlay's opacity on decoration, on a dead body and on a part, and
  -- how much brighter a material's pattern shows.
  overlay = { decorative = 0.45, dead = 0.6, part = 0.62, pattern = 1.45 },
  -- The last shot's rays: how long after the shot, colour of stone, the
  -- dotted line (start, longest, spacing, end gap, dot size and opacity) and
  -- the contact (size on a body, elsewhere, opacity).
  rays = {
    shown = 3,
    stone = { 0.62, 0.62, 0.60 },
    start = 0.8,
    longest = 24,
    every = 0.45,
    gap = 0.2,
    dot = 0.18,
    dotAlpha = 0.55,
    hit = 0.9,
    miss = 0.55,
    hitAlpha = 0.95,
  },
  -- A collision volume's rings: lift off the floor and opacity; the body's
  -- floor ring.
  volume = { lift = 0.025, alpha = 0.85 },
  bodyRing = { lift = 0.03, alpha = 0.7 },
  -- An attack's contact (render/attack_debug.lua): sizes of a live and an
  -- idle point, and of a blade's; the leap ring; the path's dots; the
  -- windup's facing dots.
  attackDebug = {
    live = 1.1,
    idle = 0.6,
    blade = 1.2,
    bladeIdle = 0.7,
    ringLift = 0.03,
    ringAlpha = 0.85,
    dot = 0.5,
    facing = 0.8,
  },
}
