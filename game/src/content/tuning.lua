-- Named numbers of the knight and the session. Where values live:
--   content/tuning.lua          the knight's movement, weapons, economy (flat,
--                               historical names) and grouped session tables
--   content/combat_defaults.lua the shared rules of bodies and demon behaviour
--                               (impulse, guard, walking, senses, attacks...)
--   content/waves.lua           waves, the pacing director, portals
--   content/classic.lua, content/expedition.lua, content/shop.lua  mode data
--   content/ballistic_surfaces.lua  materials of a body's surface
--   content/art/anatomy/*       painted regions of every demon frame
--   physics/collision.lua       tile heights and pillar radius
--   ui/palette.lua              interface colours
-- tools/check refuses new unnamed numbers in simulation code (KONWENCJE).
return {
  -- Heightfield support: largest walkable riser (m), segment length (m).
  -- Sight is queried between observers' eye planes, independently of walking.
  terrain = { stepHeight = 0.32, segment = 0.25, eye = 1.15 },
  -- A displayed input may survive one capped 200 ms catch-up plus a 120 ms tap.
  observation = { maxAge = 0.20 + 0.12 },
  -- Optional command recording: estimated serialized text, not Lua heap bytes.
  -- Stop after the complete command that reaches either bound (10 min at 120 Hz).
  recording = { maxBytes = 64 * 1024 * 1024, maxCommands = 10 * 60 * 120 },
  -- Movement (player/feel.lua): speeds m/s, accelerations m/s^2, times s.
  moveSpeed = 5.25,
  groundAccel = 68,
  groundBrake = 82,
  airAccel = 22,
  airSpeed = 6.1,
  airMomentumCap = 7.2,
  jumpSpeed = 5.5,
  gravity = 18.5,
  slideSpeed = 8.7,
  slideTime = 0.52,
  slideCooldown = 0.85,
  dashSpeed = 16.0,
  dashTime = 0.155,
  dashRecharge = 0.78,
  -- Weapons (content/weapons.lua builds the profiles from these).
  shotgunCycle = 0.94,
  reloadLoadTime = 0.60,
  shotgunPellets = 20,
  pelletDamage = 12,
  pelletSpread = 0.15,
  pelletVerticalSpread = 0.09,
  shotgunRange = 24,
  shotgunHeadMultiplier = 1.15,
  revolverHeadMultiplier = 1.35,
  -- Reload timelines (combat/reload.lua), s from the start of a full cycle.
  -- breech: the action opens (the spent cases fly) at open, the rounds go in
  -- at reloadLoadTime, it closes at close; a reload resumes at resume.afterShot
  -- (the automatic one), resume.closed (a manual reload of a closed gun),
  -- resume.open (opened, empty) or resume.loaded (opened, rounds in).
  -- cylinder: it swings out at open, a swung-out cylinder resumes at
  -- resume.open; loading and closing are the revolver's own times below.
  -- Presentation cues owned by the mechanism: HUD stage boundaries (labels),
  -- sound volumes and voices. Painted hand frames belong to content/weapon_art.
  reload = {
    breech = {
      open = 0.26,
      close = 0.82,
      resume = { afterShot = 0, closed = 0.15, open = 0.32, loaded = 0.68 },
      labels = { 0.32, 0.68 },
      sounds = { open = 0.56, load = 0.52, close = 0.62 },
      voices = { open = 'breakOpen', load = 'shellIn', close = 'breakClose' },
    },
    cylinder = {
      open = 0.20,
      resume = { open = 0.68 },
      -- A pull during the reload snaps a swung-out cylinder shut in this
      -- time (s) before the rounds still in it can fire.
      closeOnFire = 0.25,
      labels = { 0.38, 0.68 },
      sounds = { open = 0.48, load = 0.60, close = 0.65 },
      voices = { open = 'gateOpen', load = 'roundsIn', close = 'cylinderClose' },
    },
  },
  -- Expedition countdown before a wave (s).
  waveCountdown = 1.25,
  falloffStart = 4,
  falloffEnd = 18,
  pelletMinPower = 0.40,
  -- Ammunition economy: starting and pickup rounds.
  startReserve = 28,
  ammoPickup = 6,
  -- The floor's surface (m above the stone's base) that shots and thrown
  -- charges meet.
  floorSurface = 0.025,
  -- The Lua collector's pacing (app/application.lua): it starts a cycle when
  -- the heap grows by pause %, and works stepmul % as fast as memory is made.
  -- Smaller, steadier steps (qa benchmark: worst frame 15 ms -> 3 ms).
  collector = { pause = 100, stepmul = 400 },
  -- Distance fields (world/arena.lua: W.flow) kept for reuse, one per goal cell.
  flowFields = 16,
  -- Navigation at scale (plan v10 V3; world/arena.lua, world/navigation.lua):
  -- an exact field covers window cells around its goal (a map no larger is
  -- covered whole); beyond it bodies cross regions of sector x sector cells.
  -- classes: a body wider than classes[k] m in radius needs the open square
  -- of k cells around every cell of its route.
  navigation = { window = 32, sector = 16, classes = { 0.6, 1.6 } },
  -- Health of a supply that names no amount.
  healthPickup = 25,
  -- Reach (m): the Ember's rest and trade, a supply taken from the floor.
  reach = { ember = 2.8, supply = 0.7 },
  killAmmo = 4,
  sealAmmo = 8,
  revolverCapacity = 6,
  revolverStartReserve = 24,
  revolverMaxReserve = 72,
  revolverInterval = 0.38,
  revolverDamage = 70,
  revolverPenetration = 0.50,
  revolverImpact = 44,
  revolverFalloffStart = 12,
  revolverFalloffEnd = 36,
  revolverMinPower = 0.65,
  revolverRange = 42,
  revolverReload = 1.85,
  revolverLoadTime = 1.16,
  revolverCloseTime = 1.55,
  -- View: field of view (degrees) and internal render height (px).
  baseFov = 100,
  renderHeight = 540,
  -- Session clocks (systems/clocks.lua): zone banner time (s), its bell
  -- volume, and how fast the hurt and surge overlays fade (x per second).
  clocks = { zoneBanner = 3.5, zoneBell = 0.12, hurtFade = 1.6, surgeFade = 1.4 },
  -- The knight's body in motion (player/feel.lua): steering below input is
  -- no steering; turning rad/s with the keys; a slide needs slideFrom m/s; the
  -- momentum above the air cap decays at airDecay /s; a slide slows by
  -- slideDecel m/s each s and steers at slideSteer /s; a dodge or slide exits
  -- at exitShare of the walking speed; steering against a shove brakes it up to
  -- (1 + against); a shove under minPush m/s is spent; travel below moving m is
  -- standing; a crouch reaches crouch m (down at crouchDown, up at crouchUp /s).
  motion = {
    input = 0.1,
    turn = 2.2,
    slideFrom = 3,
    airDecay = 1.6,
    slideDecel = 6,
    slideSteer = 1.4,
    exitShare = 1.15,
    against = 0.8,
    minPush = 0.01,
    moving = 0.0001,
    crouch = 0.43,
    crouchDown = 4.3,
    crouchUp = 3.4,
  },
  -- The camera feel of moving (player/feel.lua, presentation state): recoil
  -- and landing springs (stiffness, damping), sway decay, the dodge's field of
  -- view kick and rate, steps per metre, bob and bank rates, the landing dip,
  -- and the sound volumes of slide, thud, jump, land and step.
  camera = {
    -- The view looks at most pitchLimit rad up or down (0.25: 69 degrees);
    -- the mouse turns it mouse rad per count on both axes (sensitivity 1).
    pitchLimit = 1.2,
    mouse = 0.0023,
    recoilSpring = { 270, 25 },
    landSpring = { 200, 20 },
    swayDecay = 13,
    dashFov = 6,
    dashFovRate = 45,
    steps = 2.5,
    bobRate = 8,
    bank = 0.015,
    bankRate = 0.11,
    landDip = 0.23,
    landDipMax = 2,
    stepEvery = 0.10,
    sounds = {
      slide = 0.32,
      thud = 0.55,
      jump = 0.16,
      land = 0.22,
      landGain = 0.03,
      landMax = 0.25,
      step = 0.10,
    },
  },
  -- The knight's dodge charges (systems/knight.lua).
  knight = { dashCharges = 2 },
  -- Score of a kill (session/listeners.lua): demon / boss points, the combo
  -- window (s), +comboStep per chained kill up to comboSteps; the classic
  -- arena (session/interactions.lua) drops ammunition every ammoEvery kills
  -- and health every healthEvery.
  rewards = {
    demon = 100,
    boss = 1000,
    comboWindow = 4,
    comboStep = 25,
    comboSteps = 5,
    ammoEvery = 2,
    healthEvery = 3,
    -- A health drop lies this far (m) beside an ammunition drop.
    dropSpacing = 0.15,
  },
  -- Feel of events (feedback/listeners.lua): flashes and punches (s), shake
  -- strength, heights (m). guardBreakStop: the world's hit-stop when the
  -- knight's guard breaks (a simulation pause, session/listeners.lua).
  -- A shot's presentation (feedback/shot_feedback.lua): powder smoke placement
  -- (m), drift (m/s), the hitmarker, shakes, sounds by damage and the share
  -- of blocked damage that reads as 'armour'.
  shot = {
    smokeReach = 0.8,
    smokeMax = 0.72,
    smokeMin = 0.02,
    smokeClearance = 0.12,
    smokeDrop = 0.13,
    smokeDrift = 0.13,
    smokeRise = 0.045,
    armorShare = 0.25,
    heavyDamage = 100,
    hitmarker = 0.13,
    hitmarkerWeight = 0.04,
    hitShake = 0.03,
    hitShakeWeight = 0.05,
    killPunch = 0.14,
    heavyHitSound = 60,
    grazeSound = 20,
  },
  -- Powder charge mechanics outside its definition (combat/explosives.lua):
  -- how far ahead of the eye it may appear (m) and its clearance from walls;
  -- a bounce reflects bounce x the normal speed and keeps keep of the rest; a
  -- charge rising slower than settle m/s on a floor rests; maxContacts bounds
  -- one frame's contacts; the blast is heard blastNoise m away and aims at a
  -- body's aimHeight m when its body names none. A charge resting on the floor
  -- slows by groundDrag /s and turns spin rad/s in flight.
  explosives = {
    groundDrag = 6,
    spin = 8,
    spawnReach = 0.32,
    spawnClearance = 0.08,
    bounce = 1.35,
    keep = 0.72,
    settle = 0.35,
    maxContacts = 24,
    blastNoise = 20,
    aimHeight = 1.1,
  },
  -- The fight's presentation (feedback/world_feedback.lua): landing dust height
  -- and tremor (shake within tremorReach m), slams, the knight's stagger, the
  -- volumes of a powder charge's throw and its lit fuse.
  world = {
    dustHeight = 0.12,
    tremor = 0.07,
    tremorReach = 5,
    knightSlamShake = 0.12,
    slamPunch = 0.06,
    staggerRecoil = 14,
    staggerFlash = 0.25,
    staggerShake = 0.16,
    blastShake = 0.09,
    throwSound = 0.45,
    fuseSound = 0.24,
    blastColor = { 0.72, 0.28, 0.06 },
    boltColor = { 1, 0.4, 0.1 },
  },
  feel = {
    hitmarker = 0.14,
    bloodHeight = 1.3,
    breakKillFlash = 0.45,
    breakKillPunch = 0.14,
    hurtFlash = 0.8,
    hurtShake = 0.1,
    perfectDodgeFlash = 0.5,
    perfectDodgeSurge = 0.6,
    perfectDodgeSound = 0.55,
    guardBreakStop = 0.06,
    sprayImpact = 110,
  },
}
