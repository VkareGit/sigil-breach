-- Every creature uses these when a field is missing from its archetype; the
-- shared constants of the rules (impulse, guard, balance, tiers, falls).
local Tuning = require('src.content.tuning')
return {
  -- One impulse law for every body (0.20): a blow of impulse J moves a body
  -- of mass m at v = vmax * (1 - exp(-J / scale)) / m. Soft saturation, not
  -- a hard cap: 20 pellets still throw harder than 9, never off the map.
  impulse = { vmax = 6, scale = 120 },
  -- Guard (poise): no recovery for regenDelay s after the last blow, then
  -- regenRate * guard per second (Souls). Each body may override both.
  regenDelay = 1.2,
  regenRate = 0.4,
  -- Losing balance (0.24), one formula for every body. The overshoot of the
  -- guard r = (G - P) / P picks a tier (Doom falter tiers): below heavy.from
  -- a light falter in place, t = base + gain * r, the braced feet keeping
  -- most of the shove (brace); from heavy.from a heavy stagger, the full
  -- throw and t = clamp(base + gain * (r - from), base, max). Every balance
  -- time (stagger, knockdown) is divided by the body's stability
  -- S = body.stability or sqrt(mass): big bodies regain their feet sooner.
  -- 0.25 (plan v5 G5): a broken guard holds the body a little longer (light
  -- 0.10 + 0.10 r -> 0.16 + 0.14 r; heavy 0.30 + 0.08 (r - 1), max 0.60 ->
  -- 0.36 + 0.10 (r - 1), max 0.70), time enough to finish what was broken.
  stagger = {
    light = { base = 0.16, gain = 0.14 },
    heavy = { from = 1.0, base = 0.36, gain = 0.10, max = 0.70 },
  },
  brace = 0.4,
  staggerLock = 1.15,
  -- Counter (0.24): momentum meets momentum. A blow on a body rushing at the
  -- shooter with closing speed u adds the body's own momentum to the guard
  -- damage, guardPerMomentum * m * u (at most cap * guard), and the shove is
  -- added to the rush velocity as a vector: a rush that the blow reverses
  -- stops dead and the body is knocked down. refSpeed: the closing speed
  -- assumed when a caller only says 'counter' (a lunging thrall).
  counter = { minSpeed = 0.5, refSpeed = 5.8, guardPerMomentum = 3.8, cap = 0.6 },
  -- Bosses have a large guard instead of none. Breaking it is a falter: the
  -- same balance time, but the committed attack is delayed, never cancelled,
  -- and an exposed window halves the armour. Then a long lock.
  bossExposed = 2.0,
  bossLock = 6,
  -- Hit zones (Call of Duty location table): wound and guard multipliers.
  -- Legs unbalance: less damage, more guard damage, and a leg blow worth half
  -- the body's guard cripples it (slower) for crippleTime seconds.
  zones = {
    head = { guard = 1.25 },
    torso = {},
    lower = { damage = 0.8, guard = 1.35, cripple = 0.5 },
  },
  crippleTime = 1.5,
  -- Recovery after an interrupted or cancelled action, and the pause before a
  -- body that lost sight of its committed target may commit again.
  interruptRecover = 0.35,
  -- Friction of a demon's feet against a shove (the knight's is in its body).
  drag = 14,
  -- A blow of at least hitPausePush impulse holds its victim for hitPause.
  hitPausePush = 36,
  cancelPause = 1.2,
  -- A leg blow of tripImpact guard damage stops a lunge, leap or charge:
  -- a demon is knocked down, a boss's charge ends short. A counter that
  -- breaks a guard or reverses a rush also knocks down. Knockdown lasts
  -- knockdown / stability (a boss with stability 1.5: 0.30 s).
  tripImpact = 40,
  knockdown = 0.45,
  -- Break kill: a demon killed while off balance heals the knight by
  -- heal * its guard (thrall 9, gardener 12.5). 0.25 (D5): a body whose
  -- guard broke, that fell or took a major wound within the last window s
  -- counts as off balance too: break it, then finish it (2 s: the skilled
  -- human models reach 16 % break kills; qa playtest-population).
  breakKill = { heal = 0.25, window = 2.0 },
  -- Guard recovery slows with wounds (Sekiro posture): the rate is scaled by
  -- (1 - healthShare) + healthShare * hp / maxHp.
  regenHealthShare = 0.5,
  -- Victim-only hit-stop of a major wound.
  woundPause = 0.07,
  -- Locomotion: a body accelerates toward its walking velocity at accel /
  -- sqrt(mass) m/s^2 (heavier bodies turn and start later). Brakes faster.
  accel = 16,
  brake = 2.0,
  -- Wave tiers (Risk of Rain 2 style coefficient), never longer telegraphs:
  -- tier t = wave number. Speed, damage, health and aggression grow a little;
  -- more demons may attack at once; aim lead and evasion unlock.
  tiers = {
    speed = 0.05,
    damage = 0.08,
    health = 0.06,
    aggression = 0.12,
    attackers = { 2, 2, 3, 3, 4 },
    spacing = 0.24,
    lead = { 0, 0.5, 0.75, 1, 1 },
  },
  woundTime = 0.55,
  -- A demon's major wound slows it for woundFor s (its stagger is woundTime);
  -- the flashes of a struck body, a broken guard and a major wound last
  -- hitFlash, breakFlash and woundFlash s. A contact with stone or with
  -- another body counts once per slamLock / collideLock s; a body struck by
  -- another flinches at least collideFlinch; bodies closer than
  -- contactMargin m beyond their radii touch.
  woundFor = 1.6,
  hitFlash = 0.065,
  breakFlash = 0.16,
  woundFlash = 0.18,
  slamLock = 0.3,
  collideLock = 0.25,
  collideFlinch = 0.7,
  contactMargin = 0.12,
  -- A killing blow (not a boss) throws the body further: the shove times
  -- base + gain x the blow's saturation n (overkill becomes visible weight).
  killThrow = { base = 1.35, gain = 0.65 },
  -- Two points closer than sameSpot m have no direction between them; a
  -- contact point more than flinchSide m off the body's axis picks its side.
  sameSpot = 0.01,
  flinchSide = 0.04,
  hitPause = 0.025,
  killPause = 0.06,
  -- momentum against the world: wall slam above slamSpeed m/s, and
  -- body-to-body collisions above collideSpeed m/s.
  slamSpeed = 3.2,
  slamDamage = 6,
  slamPoise = 16,
  collideSpeed = 2.6,
  collidePoise = 9,
  -- the fall of a killed body: a throw faster than liftFrom m/s lifts it
  -- (vertical = lift * horizontal, at most maxLift); it flies with air drag,
  -- lands (one bounce above bounceFrom m/s) and slides with ground drag.
  fall = {
    life = 0.9,
    -- One world gravity (the knight's jump, leaps, charges, corpses).
    gravity = Tuning.gravity,
    airDrag = 3,
    groundDrag = 8,
    lift = 0.22,
    liftFrom = 3,
    maxLift = 2.4,
    bounce = 0.22,
    bounceFrom = 1.6,
  },
  -- Walking and routing (enemies/ai.lua): a walk ends within arrive m of its
  -- target; a stride older than resume frames starts again from rest; a body
  -- covering less than stuckShare of its stride for stuckTime s turns to its
  -- other side and holds it for sideHold s (also after a cancelled attack);
  -- a route is re-flowed every replan s; a shove under minPush m/s is spent.
  walk = {
    arrive = 0.06,
    resume = 1.5,
    stuckShare = 0.15,
    stuckTime = 0.22,
    sideHold = 1.25,
    replan = 0.65,
    minPush = 0.01,
    -- Out of sight, a body walks straight to the furthest of the next
    -- lookahead cells of its route it can reach without touching stone.
    lookahead = 5,
  },
  -- Movement style 'flank': beyond far m close in beside the player (lateral
  -- m off the line); within near m step aside (swing rad around the player,
  -- step m out, at slow of its speed); in between circle at claw range
  -- (orbit rad off the line, ring m from the player).
  flank = {
    far = 3.8,
    lateral = 0.9,
    near = 1.25,
    swing = 1.2,
    step = 1.6,
    slow = 0.6,
    orbit = 0.6,
    ring = 1.0,
  },
  -- Movement style 'keep': switch side every hold + (id mod 3) * holdStep s;
  -- hold the ideal distance within slack m; strafe m sideways; holdSpeed: the
  -- share of speed while holding; minDistance guards the direction.
  keep = {
    hold = 1.6,
    holdStep = 0.25,
    slack = 1,
    strafe = 0.7,
    holdSpeed = 0.65,
    minDistance = 0.1,
  },
  -- Senses: sight checked every interval + (id mod 3) * stagger s; alerted
  -- within alertRange m, remembering the last sighting for memory s; facing
  -- turns at turnRate per s; threat counted within threatRange m; a sidestep
  -- considered within evadeRange m.
  senses = {
    interval = 0.10,
    stagger = 0.015,
    alertRange = 12,
    memory = 5,
    turnRate = 10,
    -- A knight this near (m) counts as close (enemies/answers.lua: hugging).
    closeRange = 2.4,
    -- Within this many radians of its facing a body has its front to a knight.
    frontCone = 1.1,
    threatRange = 13,
    evadeRange = 16,
  },
  -- Living bodies stay minimum m apart (or their radii), pushed apart by at
  -- most step m a frame, rate m/s, or share of the overlap.
  -- margin: of the spatial index (m; plan v10 V3), not a rule of the game. A
  -- body that moved farther during its own pass gathers its neighbours again,
  -- so the indexed pass equals the pass over every pair.
  separation = { minimum = 0.75, step = 0.035, rate = 1.4, share = 0.5, margin = 0.5 },
  -- The height (m) a creature whose body states none keeps under a deck
  -- (plan v10 V3): a standing one, or one of large stature. One number, not
  -- its painted pose, so a step of its walk never strikes a deck it fit under.
  stature = { standing = 2.2, large = 3.4 }, -- Attacks (enemies/actions.lua). A bolt leaves muzzle m in front of the
  -- body, rises toward the knight's chest (aimHeight m), lives boltLife s and
  -- collides with boltRadius (bigBoltRadius) m. A charge runs chargeMargin s
  -- past its target; a leap flies at most leapSpeed m/s and misses a knight
  -- above its action's landVolume; a fan rages below rageAt of health. An attack from
  -- outside the knight's view (cosine under viewCos) is announced
  -- unseenWindup s longer. A predicted target keeps aimClearance m from
  -- walls, pulled back by halves up to aimTries times; leadPasses refine an
  -- intercept.
  attacks = {
    -- Where a blink lands around its target, in the order they are tried.
    blinkBearings = { 2.4, -2.4, 1.2, -1.2, 3.14, 0.6, -0.6 },
    -- A traced blow leans the body toward the side it starts from (rad).
    swingLean = 0.14,
    muzzle = 0.30,
    aimHeight = 1.15,
    boltLife = 5,
    boltRadius = 0.12,
    bigBoltRadius = 0.26,
    chargeMargin = 0.08,
    leapSpeed = 11,
    rageAt = 0.5,
    viewCos = 0.25,
    unseenWindup = 0.26,
    aimClearance = 0.18,
    aimTries = 4,
    leadPasses = 2,
  },
  -- A claw (combat/melee.lua): active between active[1] and active[2] s of
  -- the strike unless the attack says otherwise, sweeping arc rad to each side
  -- of the lunge, sampled at reach (m from the body) every step s, as a
  -- sphere of radius m at height m.
  claw = {
    active = { 0.055, 0.18 },
    arc = 0.72,
    step = require('src.core.rate').step,
    reach = { 0.25, 0.55, 0.86 },
    height = 0.94,
    radius = 0.18,
    -- A traced blow (content/defs/action.lua: trace) meets at these shares of
    -- its reach, tip first, as spheres of bladeRadius m: a blade, not its point.
    blade = { 1, 0.7, 0.4 },
    bladeRadius = 0.32,
  },
  -- Missiles (combat/projectiles.lua): a near miss is heard within nearMiss m
  -- of the knight's chest (chest m above the feet); a bolt without a packet
  -- deals boltDamage (bigBoltDamage).
  -- A knight's bolt keeps its full power at any range (flat: its damage curve).
  missiles = {
    chest = 1.05,
    nearMiss = 1.25,
    boltDamage = 14,
    bigBoltDamage = 22,
    flat = { falloffStart = 0, falloffEnd = 1, minPower = 1 },
  },
  -- Ground hazards (enemies/hazards.lua): placed at least clearance m from
  -- walls; pools pulse every pulse s (without a packet: damage), miss a knight
  -- above their authored volume (defs/area.lua), and their condition outlasts
  -- a pulse by linger s.
  hazards = { clearance = 0.18, pulse = 0.45, damage = 8, linger = 0.6 },
  -- Between a duellist's blows (enemies/ai.lua: Styles.duel): shares of its speed, the
  -- length of a step, how strongly a circle pulls back to the ideal distance.
  duel = { closing = 0.8, giving = 0.7, circling = 0.6, step = 2, pull = 0.3, nearest = 0.1 },
  -- A counter (Rules.parried): a shot of at least impact, from within reach m, in the
  -- window a blow opens (content/defs/action.lua: parry), holds a body stun s.
  parry = { impact = 40, reach = 6, stun = 1.6 },
  -- What a blow took can be fought back: a share of it stays open for time s, and
  -- damage dealt brings it back at rate per point (session/listeners.lua).
  rally = { share = 0.6, time = 3.5, rate = 0.04 },
  -- An execution (combat/execution.lua): within reach m of the body's edge,
  -- looking at it (cosine above cone); the knight is untouchable iframes s, the
  -- world stops stop s, the body rises after rise s.
  execution = { reach = 2.1, cone = 0.5, iframes = 0.8, stop = 0.18, rise = 0.6, cue = 0.8 },
  -- A killed body (enemies/corpse.lua). Its death strength counts overkill
  -- up to overkill x its health and a killing contact's impact against
  -- impactRef; when it first touches the floor and when it has settled are
  -- its body's own (body.corpse: landing, settle); a grounded collapse falls
  -- from fallShare of its aim height (aimHeight when the body names none), and
  -- a shove adds pushShare of its square to the landing energy. The painted
  -- collapse is its atlas's collapse pose; its lean starts at lean + strength
  -- x leanGain and settles over settle s.
  corpse = {
    overkill = 0.5,
    impactRef = 110,
    fallShare = 0.45,
    aimHeight = 1.1,
    pushShare = 0.18,
    lean = 0.035,
    leanGain = 0.045,
    settle = 0.33,
    -- A corpse is drawn for visible s after death. Settled and at rest after
    -- that, it leaves every simulation step for the remains (plan v10 V1).
    visible = 25,
  },
  -- A body climbing out of a portal does not decide for spawnPause s.
  spawnPause = 0.6,
  -- hit flinch spring: lean impulse per unit of flinch, stiffness, damping
  flinch = { impulse = 1.5, stiffness = 420, damping = 18, scale = 80, decay = 7 },
  -- A volley: rays of one shot and bodies of one shot apart in their seeds;
  -- the shortest length a contact's normal is taken from.
  volley = { seedStride = 31, nearest = 0.001 },
  -- A grip is renewed each step for this long, so a holder that falters lets go.
  gripHold = 0.08,
}
