-- Pigment placement only. Delivery dimensions come from the live action.
return {
  -- What the pigment painter claims (render/painters/pigment.lua): the casts
  -- of these attack kinds and the projectiles of these arts.
  casts = { stream = true, sow = true, harvest = true },
  projectiles = { ['rot-spit'] = true, ['rot-seed'] = true },
  rate = 7,
  stream = { 'rotSpray1', 'rotSpray2', 'rotSpray3' },
  seed = { 'rotSeed1', 'rotSeed2', 'rotSeed3' },
  planted = 'rotPlanted',
  mature = 'rotMature',
  spent = 'rotSpent',
  harvest = { 'rotSwell', 'rotRise', 'rotFall' },
  poolRim = 0.82,
  seedCore = 0.55,
  castSize = 0.23,
  segments = 8,
  flow = 14,
  near = 0.65,
}
