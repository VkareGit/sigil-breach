-- How a resolved contact looks (feedback/impact_response.lua, PLAN G7): the
-- debris and blood a blow throws, in metres, seconds and multiples of the
-- square root of the retained-power proxy (combat/damage.lua).
return {
  -- The most debris and blood specks alive at once.
  particleLimit = 240,
  -- Debris by struck material: colour, sprite tint, and size, speed and life
  -- per unit of root energy.
  materials = {
    plaster = {
      color = { 0.65, 0.51, 0.34 },
      tint = { 1.03, 0.98, 0.87 },
      size = 0.031,
      speed = 0.27,
      life = 0.28,
    },
    stone = {
      color = { 0.36, 0.35, 0.31 },
      tint = { 0.77, 0.87, 0.98 },
      size = 0.024,
      speed = 0.22,
      life = 0.25,
    },
    metal = {
      color = { 0.53, 0.55, 0.53 },
      tint = { 0.66, 0.82, 1.10 },
      size = 0.022,
      speed = 0.36,
      life = 0.18,
    },
    bone = {
      color = { 0.40, 0.29, 0.18 },
      tint = { 0.82, 0.69, 0.52 },
      size = 0.026,
      speed = 0.24,
      life = 0.24,
    },
  },
  -- The art starts in front of the surface: a wall's painted niche fillet
  -- projects 8.25 cm, so beyond that trim; any other surface just above it.
  offset = { wall = 0.095, other = 0.028 },
  -- The plume: its size and speeds from normal and tangential root energy,
  -- within artistic caps.
  size = { base = 0.07, tangent = 0.004, high = 0.58 },
  normalSpeed = { base = 0.12, high = 3.1 },
  tangentSpeed = { share = 0.62, high = 2.1 },
  -- How many specks: gain per root energy, weighted flat + incidence share.
  count = { gain = 0.40, flat = 0.45, incidence = 0.55, high = 6 },
  -- A normal this close to vertical takes the x axis for its fan.
  vertical = 0.85,
  -- Where a contact seeds its fan, and the golden turn between specks.
  seed = { x = 0.137, z = 0.191, scale = 0.117 },
  turn = 2.3999632297287,
  ratio = 0.61803398875,
  variation = { base = 0.64, spread = 0.36 },
  spread = { blood = 0.31, debris = 0.48 },
  bloodLife = 0.27,
  life = { base = 0.78, spread = 0.22 },
  speckSize = { base = 0.20, gain = 0.040, high = 0.82 },
  -- The painted puff drifts with a share of the plume's speeds.
  sprite = { normal = 0.16, tangent = 0.12 },
  -- The compact contact mark.
  mark = { base = 0.12, gain = 0.012, low = 0.14, high = 0.25 },
  -- A body: its blood when it names none, and how a wound bleeds.
  blood = { 0.26, 0.025, 0.016 },
  wound = {
    count = 0.46,
    most = 8,
    speed = 0.18,
    speedGain = 0.13,
    speedHigh = 1.5,
    tangent = 0.18,
    offset = 0.025,
    size = 0.13,
    sizeGain = 0.035,
    sizeHigh = 0.58,
    drift = 0.09,
  },
}
