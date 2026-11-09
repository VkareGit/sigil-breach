-- How the fight sounds and shows around the knight (feedback/world_feedback.lua,
-- PLAN G7): each event's loudness (gain) and the priority its voice keeps in a
-- crowded room (higher survives), and what it throws into the air.
return {
  -- A warning layer is let go over this many seconds when its attack stops.
  warningFade = 0.025,
  phase = { gain = 0.75, priority = 2 },
  telegraph = { material = 0.7, materialPriority = 3, voice = 0.58, voicePriority = 2 },
  release = { gain = 0.65, priority = 2, voice = 0.58 },
  chargeBlocked = { gain = 0.5, priority = 2 },
  landing = { dust = 0.5, heavyDust = 0.75, gain = 0.42, heavyGain = 0.55 },
  evaded = { gain = 0.45 },
  alerted = { gain = 0.4, priority = 2 },
  -- A body driven into stone: louder by the health it lost; its blood.
  wallSlam = { gain = 0.30, lostGain = 0.08, bloodHeight = 1.0, drops = 6, speed = 1.4 },
  collided = { gain = 0.35 },
  portal = { gain = 0.45, priority = 2 },
  arrival = { smokeHeight = 0.7, smoke = 0.9, burstHeight = 1.0, specks = 14, speed = 2.6 },
  arrivalVoice = { gain = 0.55, priority = 2 },
  blink = { departure = 0.35, arrival = 0.5, priority = 2 },
  seized = { gain = 0.6 },
  -- A powder charge: its smoke above it, the stone it throws, its blast.
  charge = { smokeRise = 0.65, smoke = 3.2, stoneRise = 0.15, stone = 0.9, gain = 0.85 },
  projectileBurst = { fade = 0.025, size = 0.65, gain = 0.23 },
  -- Spent cases thrown out of an opened breech, one to each side (px of the
  -- 450 px scene, px/s, s, rad).
  shells = { x = 7, vx = 83, vy = -135, vyStep = 17, life = 1.2, turn = 0.3 },
  pickup = 0.4,
}
