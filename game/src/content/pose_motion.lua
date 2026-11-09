-- How a painted body moves on top of its frames (enemies/animation.lua, PLAN G7):
-- its bounce (m), lean (rad) and squash (share). The hit volumes follow the
-- same pose, so these are shapes of the body, not decoration.
return {
  -- A hovering body bobs and sways on its own clock (rad/s).
  hover = { height = 0.17, bob = 0.065, bobRate = 2.6, sway = 0.018, swayRate = 1.7 },
  -- A heavy body barely bounces and leans less while it walks.
  heavy = { bounce = 0.3, lean = 0.55 },
  -- A swaying body leans with its walk.
  sway = { rate = 5.5, lean = 0.018 },
  -- A body walks from this speed (m/s).
  walking = 0.1,
  -- The shortest falter read, so a zero window cannot divide by zero (s).
  shortestFalter = 0.001,
  knockedLean = -0.06,
  -- A heavy or light hurt: how long the first recoil shows, lean and squash.
  hurt = { recoil = 0.20, heavyLean = -0.08, heavySquash = 0.95, lean = -0.03 },
  -- The windup gathers and the strike lands: lean and widening by the phase.
  transition = { lean = -0.025, widen = 0.025 },
  strike = { lean = 0.06, widen = 0.035 },
  recover = { squash = 0.98, rise = 0.02 },
  walk = { bounce = 0.008, lean = 0.012 },
  -- A struck body widens and squashes by its flinch.
  flinch = { widen = 0.05, squash = 0.045 },
  -- A gathering windup sinks and widens.
  gather = { sink = 0.10, widen = 0.06 },
  evadeLean = 0.09,
  -- Climbing out of a portal over this many seconds, from this depth (m).
  arrival = { time = 0.6, depth = 1.4 },
  -- A crippled body limps on one side.
  limp = { rate = 4.2, lean = 0.02, leanGain = 0.05, sink = 0.05 },
  -- A major wound trembles.
  tremble = { rate = 38, lean = 0.010 },
}
