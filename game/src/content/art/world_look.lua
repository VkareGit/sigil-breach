-- How the things standing in the world are shown (render/world_art.lua):
-- props, murals, supplies, the Ember's shrine and ring, lamps and the echo.
-- Lengths are in metres; a colour is { r, g, b }.
return {
  -- The props sheet (lamps and decor), cut through its empty gutters: the
  -- first effigy's hood starts above the nominal half-sheet boundary.
  propSheet = {
    path = 'assets/art/props-fresco-v12.png',
    cols = 4,
    rows = 2,
    cuts = { { 0, 425, 887 }, { 0, 443, 887 }, { 0, 443, 887 }, { 0, 443, 887 } },
  },
  -- The brightness of a prop where it names none.
  propBright = 0.9,
  -- The inset of each mural in its sheet of two by two.
  muralPad = 0.001,
  -- A supply's seal laid on the floor: its lift and opacity.
  seal = { lift = 0.028, alpha = 0.8 },
  -- An atlas supply hovers and bobs; a painted one is lit like the fresco.
  hover = { lift = 0.27, rate = 3, bob = 0.04 },
  supplyGlow = 1.15,
  -- The shrine of the Ember: its size, the share of its width, brightness lit
  -- and dark, and its frames per second.
  shrine = { size = 3, width = 0.5, lit = 0.92, dark = 0.32, rate = 5 },
  -- The Ember's ring on the floor: lift, size, colour lit and dark.
  ring = {
    lift = 0.035,
    size = 0.72,
    lit = { 0.50, 0.85, 0.72 },
    dark = { 0.12, 0.13, 0.14 },
  },
  -- A lamp: its spark (colour, sway, rate, rise, its flicker, size) and its
  -- painting (frames per second, scale and brightness by default).
  lamp = {
    spark = { 1, 0.5, 0.1 },
    sway = 0.06,
    swayRate = 4,
    rise = 0.3,
    flicker = 0.6,
    flickerSpan = 0.4,
    sparkSize = 0.3,
    rate = 7,
    scale = 1.7,
    bright = 1.1,
  },
  -- The echo of a death: the seal that floats (height, bob and its rate,
  -- turn, size, colour) and its ring.
  echo = {
    height = 1.1,
    bob = 0.07,
    bobRate = 2,
    turn = 0.7,
    size = 0.8,
    color = { 0.15, 0.7, 1 },
    ringLift = 0.03,
    ringColor = { 0.2, 0.7, 1 },
  },
}
