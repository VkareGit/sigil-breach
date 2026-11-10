-- How sounds are mixed as they play (audio/*.lua): aggregate Source gains,
-- the voice budget, the default levels, hearing and obstruction, and the
-- levels of the world's own voices. Separate from sample peaks (the
-- recipes) and the player's sliders. Distances are in metres, times in
-- seconds.
return {
  groups = { rites = 1.2 },
  release = 0.12,
  -- Voices playing at once, and recycled Sources kept for reuse.
  voices = 28,
  -- The seed of the roll that picks a recorded take.
  takeSeed = 43,
  -- The ambience's share by default, and the master volume at full slider.
  ambience = 0.65,
  master = 0.7,
  -- A voice's volume where its caller names none, and at a point in the world.
  volume = 0.65,
  volumeAt = 0.6,
  -- A voice steals the quietest of its rank only if this much louder.
  steal = 1.05,
  -- A warning (rank 3) holds the music ducked this long.
  warningHold = 0.65,
  -- A looped voice joining late rises in over this long.
  rejoin = 0.04,
  -- Nothing is heard beyond this; the fall-off per metre where a recipe
  -- names none; the level and high band left behind a wall.
  hearing = 32,
  falloff = 0.13,
  obstructed = 0.38,
  muffled = 0.4,
  -- A voice's place on the listener's stereo circle (its radius), and how
  -- often and fast its obstruction follows the walls.
  stereo = 0.8,
  obstructionPeriod = 0.08,
  obstructionRate = 18,
  -- Bodies: a body's first idle voice waits this long, then each its own
  -- share of the stagger (by id over this many); its voice stops with a fade.
  body = { wait = 0.8, spread = 7, fade = 0.02 },
  -- A field of fire or rot: its voice's level and rank, the level of its
  -- end, its stop fade; a dropped voice is retried this often; one beat of
  -- a group sounds once in this long.
  field = { volume = 0.4, rank = 2, finish = 0.22, fade = 0.035, retry = 0.25, beat = 0.09 },
  -- World cues: a projectile is heard passing within reach² m² (its own and
  -- another's levels); a footfall within reach² of a walking body, its
  -- level by mass (base, per kilogram, most), and only when moving faster
  -- than walk and lower than airborne.
  flight = { reach2 = 25, own = 0.22, other = 0.12 },
  step = { reach2 = 400, base = 0.16, perMass = 0.09, most = 0.5, walk = 0.15, airborne = 0.05 },
  -- The bodies' steps and wings sounding at once, by category, the nearest first (PLAN
  -- Z10b): a crowd leaves the rest of the voices to warnings and blows. A step voice not
  -- named in `of` is a step. Today's chapel with every body awake reaches 18 steps and 3
  -- wings at once (measured), so it never meets these.
  crowd = { voices = { steps = 18, wings = 4 }, of = { owl_wings = 'wings', wing_fold = 'wings' } },
  -- The scene's pressure: enemies count within reach, their nearness over
  -- near, their weight and a committed blow's; the share of the knight's
  -- lost health; a full health where the viewer names none.
  scene = { reach = 24, near = 12, weight = 0.6, committed = 0.3, wounds = 0.25, fullHealth = 100 },
}
