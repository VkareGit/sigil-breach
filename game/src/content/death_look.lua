-- How an already resolved death looks (feedback/death_response.lua, PLAN G7):
-- its clots, the landing's dust, sound and stain, and how the body settles.
return {
  -- A body that names no blood.
  blood = { 0.26, 0.025, 0.016 },
  -- Clots through the wound: a few plus more by the blow's strength (strong:
  -- a full volley), their speed and fan, and the specks they make.
  clots = {
    least = 3,
    strong = 5,
    weak = 3,
    speed = 0.65,
    speedGain = 1.25,
    fan = 0.8,
    rise = 0.35,
    riseStep = 0.18,
    rises = 3,
    life = 0.24,
    lifeStep = 0.025,
    size = 0.30,
    sizeGain = 0.26,
  },
  -- Specks alive at once (feedback/impact_response.lua shares it).
  speckLimit = 240,
  -- The landing: dust and thud by root energy within caps, two low lateral
  -- strokes, and a second stain once the body travelled far enough.
  landing = {
    size = 0.16,
    sizeGain = 0.065,
    sizeHigh = 0.66,
    loudHigh = 0.58,
    stroke = 0.33,
    strokeHeight = 0.10,
    tint = { 0.58, 0.49, 0.36 },
    duration = 0.22,
    drift = 0.65,
    rise = 0.10,
    travelled = 0.0625,
    stain = 0.34,
    stainGain = 0.45,
    stainHigh = 0.64,
  },
  -- The painted body keeps its form through the fall, then settles into the
  -- floor's shadow; and the pain it shows right after the blow.
  shade = { after = 0.11, floor = 0.72, rest = 0.28, rate = 5 },
  pain = { share = 0.5, lasts = 0.085 },
}
