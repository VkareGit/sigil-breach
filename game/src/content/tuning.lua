-- Named numbers of the knight and the session. Where values live:
--   content/tuning.lua          the knight's movement, weapons, economy (flat,
--                               historical names) and grouped session tables
--   content/combat_defaults.lua the shared rules of bodies and demon behaviour
--                               (impulse, guard, walking, senses, attacks...)
--   content/field.lua, content/pilgrimage.lua, content/shop.lua  mode data
--   content/ballistic_surfaces.lua  materials of a body's surface
--   content/art/anatomy/*       painted regions of every demon frame
--   physics/collision.lua       tile heights and pillar radius
--   ui/palette.lua              interface colours
-- tools/check refuses new unnamed numbers in simulation code (KONWENCJE).
return {
  -- A new view's shot age (long after any shot: no flash, no kick, the
  -- hands quiet), the view kick's rate before a first shot, the flash colour.
  viewDefaults = { shotAge = 10, aimKickRate = 30, flash = { 1, 0.45, 0.12 } },
  -- Heightfield support: largest walkable riser (m), segment length (m).
  -- Sight is queried between observers' eye planes, independently of walking.
  terrain = { stepHeight = 0.32, segment = 0.25, eye = 1.15 },
  -- A displayed input may survive one capped 200 ms catch-up plus a 120 ms tap.
  observation = { maxAge = 0.20 + 0.35 },
  -- Optional command recording: estimated serialized text, not Lua heap bytes.
  -- Stop after the complete command that reaches either bound: 10 min of
  -- 120 updates/s and one aim per displayed frame up to 240 frames/s.
  -- recall: the views a journal keeps searchable for the shot that uses them.
  recording = { maxBytes = 64 * 1024 * 1024, maxCommands = 10 * 60 * (120 + 240), recall = 16 },
  -- A world's gravity; how a body moves is its character's (content/knight.lua).
  gravity = 18.5,
  -- Weapons (content/weapons.lua builds the profiles from these).
  shotgunCycle = 0.94,
  reloadLoadTime = 0.60,
  shotgunPellets = 20,
  pelletDamage = 12,
  pelletImpact = 6,
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
  -- of k cells around every cell of its route. heights: on a world with
  -- decks, a body up to heights[1] m tall walks where heights[1] m of room
  -- is left under a deck, up to heights[2] where that much is; a taller one
  -- never under a deck.
  navigation = {
    window = 32,
    sector = 16,
    classes = { 0.6, 1.6 },
    heights = { 2.4, 3.6 },
    -- Route fields kept before the cache starts again: each is a table of every region.
    fieldsKept = 64,
  },
  -- How long a press waits for the moment it can happen (s), and how a refusal is told.
  input = {
    jumpWindow = 0.12,
    fireWindow = 0.35,
    -- A press older than this has waited, and takes the aim of the moment it fires.
    freshAim = 0.12,
    dashWindow = 0.25,
    refusalTime = 0.7,
    refusalVolume = 0.25,
  },
  -- Corpses at rest a session keeps.
  remainsKept = 128,
  -- Health of a supply that names no amount.
  healthPickup = 25,
  -- Rounds found by a knight with none left before a guardian, and where.
  mercy = {
    rounds = 6,
    offsets = { { 2, 0 }, { -2, 0 }, { 0, 2 }, { 0, -2 }, { 1, 1 }, { -1, -1 } },
  },
  -- Reach (m): the Ember's rest and trade, a supply taken from the floor.
  reach = { ember = 2.8, supply = 0.7 },
  revolverCapacity = 6,
  revolverStartReserve = 24,
  revolverMaxReserve = 72,
  -- 0.42: the Judge's engravings (content/weapons.lua) and a rank of tempering, either gun.
  judgeBreakerImpact = 1.25,
  judgePrecisionHead = 1.6,
  temperDamage = 1.08,
  -- 0.42: the Judge never stays dry: below a cylinder in all, a round a second comes back.
  revolverSpare = 6,
  revolverSpareEvery = 1,
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
  renderHeight = 1080,
  -- combat/destruction.lua: a blow reaches a thing this near a ray; a body this
  -- near a fragile thing breaks it unless it passes this high; the listeners'
  -- place after a shot's own consequences.
  scenery = { rayGrace = 0.03, bodyGrace = 0.3, clearance = 0.5, listenerOrder = 40 },
  -- A thing of the world (session/entities.lua) without its own measures: a post,
  -- and how near its use reaches.
  entities = { radius = 0.4, height = 1.8, reach = 2 },
  -- Reactions (combat/reactions.lua) come after every other consequence.
  reactionOrder = 50,
  -- Session clocks (systems/clocks.lua): zone banner time (s), its bell
  -- volume, and how fast the hurt and surge overlays fade (x per second).
  -- The damage trail on a target's bar: its sum holds trailHold s after the last blow, then
  -- the pale share falls trailFall of the bar per s.
  clocks = {
    zoneBanner = 3.5,
    zoneBell = 0.12,
    hurtFade = 1.6,
    surgeFade = 1.4,
    trailHold = 0.7,
    trailFall = 0.8,
    -- What rests over the scene (0.45, owner D18): an ordinary body's bar after a hit, the keys
    -- and clock at the start of a game, a place's name after it changes (s).
    foeBar = 4,
    helpFor = 90,
    placeFor = 4,
    -- A lesson stands this long once nothing hunts the knight (s).
    lessonTime = 6,
  },
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
    -- The hands after a shot (feedback/weight.lua): roll, rise and shove back,
    -- each a spring (stiffness, damping) held within its limits.
    hands = {
      rollPunch = { 230, 21, limits = { -0.06, 0.06 } },
      viewPunch = { 300, 24, limits = { -0.05, 0.05 } },
      kickBack = { 900, 30, limits = { -1.5, 2.5 } },
    },
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
  -- The share of health every wounded look starts from, and the share the
  -- frame begins to drain at.
  lowHealth = 0.30,
  lowHealthFade = 0.40,
  -- Score of a kill (session/listeners.lua): demon / boss points, the combo
  -- window (s), +comboStep per chained kill up to comboSteps.
  rewards = {
    demon = 100,
    boss = 1000,
    comboWindow = 4,
    comboStep = 25,
    comboSteps = 5,
    -- Drops of a phase lie dropSpacing m apart, side by side, dropOut m beyond the body's edge
    -- toward the knight (session/listeners.lua: spill).
    dropSpacing = 0.5,
    dropOut = 0.8,
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
    hitmarker = 0.1,
    killHitmarker = 0.3,
    killPop = 0.08,
    -- How loud a hit's tick is, and how much more for a heavy one.
    tickVolume = 0.6,
    tickWeight = 0.3,
    killVolume = 0.9,
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
    -- A blast shakes the view in full within blastNear m, fading to blastFar of it at
    -- blastReach m and not at all beyond (0.43, audit D03: it shook as hard from across a hall).
    blastShake = 0.09,
    blastNear = 3,
    blastReach = 16,
    blastFar = 0.2,
    throwSound = 0.45,
    fuseSound = 0.24,
    blastColor = { 0.72, 0.28, 0.06 },
    boltColor = { 1, 0.4, 0.1 },
  },
  feel = {
    hitmarker = 0.14,
    -- How long what a kill paid stays by the purse (s); kills inside it add up.
    soulsGain = 1.4,
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
