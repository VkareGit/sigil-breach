-- What can be broken and how. A new kind is one entry here; a map places them
-- (decor.breakables) and the art of a kind lives in render/kit/props.lua.
--   health    damage it takes; a resolved shot's own damage counts, so a heavier
--             weapon breaks it sooner
--   walk      a body walking through it breaks it
--   collapses it carries the roof: its fall opens cells and brings masonry down
--   blast     share of a charge's blast it takes
--   mass      too big for a shot to weaken with distance
--   crush     { radius, damage } what its fall does to demons near it
--   cracked   share of health at which it shows its wounds
--   material  the dust and sound of it (feedback/scenery_feedback.lua)
return {
  pier = {
    health = 800,
    blast = 3,
    mass = true,
    collapses = true,
    crush = { radius = 3, damage = 220 },
    cracked = 0.4,
    material = 'stone',
  },
  urn = { health = 10, blast = 1, walk = true, material = 'clay' },
  bench = { health = 60, blast = 1, walk = true, material = 'wood' },
  candles = { health = 10, blast = 1, material = 'wax' },
  banner = { health = 40, blast = 1, material = 'cloth' },
  chain = { health = 240, blast = 1, material = 'iron', sways = true },
}
