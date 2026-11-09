-- How broken things look and sound (feedback/scenery_feedback.lua, PLAN G7).
return {
  -- By material: the colour of its fragments, the dust a collapse raises, and
  -- the sound of a blow on it and its loudness.
  materials = {
    stone = {
      color = { 0.46, 0.37, 0.26 },
      dust = { 0.62, 0.5, 0.38 },
      sound = 'thud',
      volume = 0.3,
    },
    clay = { color = { 0.5, 0.26, 0.13 }, sound = 'graze', volume = 0.4 },
    wood = { color = { 0.3, 0.2, 0.12 }, sound = 'thud', volume = 0.3 },
    wax = { color = { 0.7, 0.58, 0.36 }, sound = 'graze', volume = 0.14 },
    cloth = { color = { 0.42, 0.09, 0.07 }, sound = 'whoosh', volume = 0.2 },
    iron = { color = { 0.3, 0.27, 0.24 }, sound = 'shell', volume = 0.4 },
  },
  -- A struck thing throws a few fragments; a broken one more, and louder.
  struck = { fragments = 8, speed = 1.3 },
  broken = { fragments = 16, speed = 1.8, loudness = 1.4 },
  -- A collapse: fragments up the column from bottom to top every few metres,
  -- a ring of dust puffs turning by turn and reaching out, and its sound.
  collapse = {
    bottom = 0.5,
    top = 8,
    every = 1.5,
    fragments = 22,
    speed = 3.2,
    puffs = 16,
    turn = 2.4,
    reach = 0.6,
    reachStep = 0.28,
    height = 0.5,
    heightStep = 0.8,
    heights = 4,
    size = 2.6,
    sizeStep = 1.1,
    sizes = 3,
    drift = 0.7,
    thunder = 1,
    blast = 0.8,
  },
}
