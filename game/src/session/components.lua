-- Components of the session's entities: every field an entity may carry,
-- declared once with its default and meaning. Systems read and write these
-- fields directly (flat entities, core/ecs.lua); strict mode in the tests
-- rejects a field that no component of the entity declares.
-- A field with no default starts absent (nil means "not now": no target,
-- not leaping, no pending strike).
local Characters = require('src.content.characters')
local C = {}
local function f(default, desc)
  return { default = default, desc = desc }
end
C.schemas = {
  identity = {
    id = f(nil, 'unique per session'),
    kind = f(nil, 'creature family (atlas, AI)'),
    archetype = f(nil, 'the creature definition (Type Object)'),
    variant = f(nil, 'the variant of its kind it is (creature id; content/creatures)'),
    displayName = f(nil),
    rewardSouls = f(nil),
    bornAt = f(0, 'session time of arrival (time to kill)'),
    killCounted = f(nil, 'its death is in the session counters (combat/telemetry.lua)'),
    faction = f(nil, "own side, else its definition's (content/factions.lua)"),
    dummy = f(nil, 'proving-ground training dummy: physics only'),
    previewFrame = f(nil, 'catalogue pose override'),
    fieldKind = f(nil, 'proving-ground catalogue entry'),
  },
  transform = {
    x = f(0),
    y = f(nil, 'height (projectiles, charges)'),
    z = f(0),
    level = f(nil, 'the surface it stands on, on a world with decks (physics/ground.lua)'),
    facing = f(math.pi, 'body yaw (rad)'),
  },
  health = {
    hp = f(1),
    maxHp = f(1),
    armorRating = f(0),
    resistances = f(nil),
    immune = f(nil),
    soak = f(0),
    locationArmor = f(nil),
    zones = f(nil),
    mass = f(1),
    boss = f(false),
    speed = f(0, 'walking speed of the definition'),
    conditions = f(nil, 'named states and their remaining time'),
    effectState = f(nil, 'ordered ongoing effect instances, clocks and source ids'),
    woundFlash = f(0),
  },
  guard = {
    poise = f(0, 'guard damage taken'),
    guardQuiet = f(nil, 'time since the last blow'),
    staggerLock = f(0),
    stun = f(0),
    heavyStagger = f(nil),
    knockedDown = f(nil),
    knockTime = f(nil),
    breakFlash = f(0),
    hitPause = f(0, 'victim-only hit-stop'),
    brokenAge = f(nil, 'its spawnAge when its guard last broke, it fell or was wounded'),
    brokenBy = f(nil, 'what broke it at brokenAge: guard, wound, knockdown'),
    stunCause = f(nil, 'what set a stun that is no lost balance: micro, trip'),
    guardFalling = f(nil, 'its guard broke in a steady blow: it falls when the blow ends'),
    swingSide = f(nil, 'the side a mirrored blow comes from this time'),
    closeFor = f(nil, 'how long a knight has stood close (s)'),
    home = f(nil, 'the post it goes back to'),
    leash = f(nil, 'how far it follows from there (m)'),
    alertRange = f(nil, 'how near it notices a knight (m)'),
    post = f(nil, 'its place in the garrison'),
    patrol = f(nil, 'the points it walks between'),
    patrolAt = f(nil, 'the point it walks to'),
    frontOn = f(nil, 'it faces the body it fights'),
    answered = f(nil, 'event -> when it may be answered again'),
    duelMove = f(nil, 'what it does between blows'),
    duelLeft = f(nil, 'for how much longer (s)'),
  },
  motion = {
    pushX = f(0, 'shove velocity (m/s)'),
    pushOwner = f(nil, 'the owner of the blow that shoves it (plan v11 E3d: slams, collisions)'),
    pushZ = f(0),
    walk = f(0, 'distance walked (animation)'),
    walkSpeed = f(0),
    walkVX = f(nil),
    walkVZ = f(nil),
    walkAt = f(nil),
    blocked = f(nil),
    slamLock = f(nil),
    collideLock = f(nil),
  },
  brain = {
    phaseIndex = f(nil, 'encounter phase (nil means first); not the action clock'),
    phaseEnteredAt = f(nil, 'simulation time of the current encounter phase transition'),
    phaseBaseHp = f(nil, 'spawn HP, basis of later health stocks'),
    ai = f('idle', 'state: idle, move, windup, strike, recover, hurt'),
    streamHits = f(nil, 'bodies already met by the current finite exhale'),
    harvestMarks = f(nil, 'owned patches committed to an eruption; shared save references'),
    phase = f(0, 'time in the state'),
    recover = f(0),
    spent = f(0, 'what is left of the recovery after a blow: it moves but cannot strike (s)'),
    attack = f(1.5, 'time until the next attack may begin'),
    decision = f(0),
    side = f(1, 'circling side'),
    hit = f(0, 'hit flash'),
  },
  perception = {
    sense = f(0, 'time to the next sight check'),
    visible = f(nil),
    memory = f(0, 'seconds the last sighting is remembered'),
    awake = f(false),
    lastX = f(nil),
    lastZ = f(nil),
    lastLevel = f(nil, 'the surface of the last sighting, on a world with decks'),
    path = f(nil),
    pathTimer = f(nil),
    lineClear = f(nil, 'whether its goal was last found in a straight walk (enemies/walking.lua)'),
    lineTimer = f(nil, 'seconds before that is asked again'),
    target = f(nil, 'id of the body it fights (enemies/target.lua)'),
  },
  attacker = {
    slotWaitAt = f(nil, 'when the ready body first waited for an attack slot'),
    slotWaitTarget = f(nil, 'the target of that optional waiting claim'),
    attackSpec = f(nil),
    attackKind = f(nil),
    attackCount = f(0),
    lastAttack = f(nil, 'last committed attack, for contextual selection'),
    attackRepeats = f(nil, 'consecutive commitments of that attack'),
    finishedAttack = f(nil, 'completed attack offering a finite follow-up'),
    finishedAt = f(nil, 'simulation time of completion, not windup or release'),
    finishedTarget = f(nil, 'target locked at the predecessor commitment; retained at completion'),
    restUntil = f(nil),
    aimX = f(nil),
    aimZ = f(nil),
    aimLevel = f(nil, 'the surface under the aim, on a world with decks'),
    windup = f(0),
    windupDuration = f(nil),
    didHit = f(nil),
    pendingHazard = f(nil),
    holdLeft = f(nil, 'stillness left after the windup (s)'),
    holdSpan = f(nil, 'the whole of that stillness (s): the pose and tell reach the blow with it'),
    chain = f(nil, 'id of the attack its string flows into'),
    chainFrom = f(nil, 'the attack that string came from'),
    holding = f(nil, 'id of the body in its grip'),
    holdUntil = f(nil, 'when that grip closes, on the strike clock'),
    trailed = f(nil, 'its cut already left its trail'),
    released = f(nil, 'missiles or bolts of this strike so far'),
    turnsLeft = f(nil, 'new rushes left in this charge'),
    turnAt = f(nil, 'when the next rush begins, on the strike clock'),
    turnStart = f(nil, 'start of a planted return on the strike clock'),
    summoner = f(nil, 'id of the body that called it'),
  },
  rush = {
    rushVX = f(nil, 'velocity of the attack moving the body'),
    rushVZ = f(nil),
    rushScale = f(nil),
    lungeX = f(nil),
    lungeZ = f(nil),
    chargeTime = f(nil),
    clawFrom = f(nil),
    clawTo = f(nil),
  },
  flight = {
    leaping = f(nil),
    leapY = f(nil),
    leapVX = f(nil),
    leapVY = f(nil),
    leapVZ = f(nil),
    leapFlight = f(nil),
    landings = f(nil),
  },
  evade = {
    evadeTime = f(nil),
    evadeReady = f(nil),
    evadeSide = f(nil),
    evadeX = f(nil),
    evadeZ = f(nil),
    evades = f(nil),
  },
  corpse = {
    deathTime = f(0),
    fallY = f(nil),
    fallVY = f(nil),
    fallLanded = f(nil),
    deathResponse = f(nil),
  },
  appearance = {
    spawnAge = f(1, 'time since leaving the portal'),
    flinch = f(0),
    flinchSide = f(nil),
    flinchLean = f(nil),
    flinchLeanV = f(nil),
    flinchOwner = f(nil, 'body defining the painted reaction basis, never the current viewer'),
    flinchOriginX = f(nil, 'contact origin retained after the source leaves'),
    flinchOriginZ = f(nil),
  },
}
-- A projectile in flight (enemies/actions.lua: projectile).
C.schemas.projectile = {
  gravity = f(nil, 'optional ballistic downward acceleration'),
  deposit = f(nil, 'reserved ground payload, delivered only on a floor contact'),
  art = f(nil, 'painted projectile family'),
  x = f(0),
  y = f(0),
  z = f(0),
  vx = f(0),
  vy = f(0),
  vz = f(0),
  life = f(5, 'seconds before it expires'),
  big = f(false),
  color = f(nil),
  owner = f(nil, 'id of the body that fired it: a demon, or a knight (plan v11 E3d)'),
  side = f('demons', "the shooter's side (content/factions.lua): it hurts bodies of a hostile one"),
  packet = f(nil, 'damage it delivers'),
  radius = f(nil, 'collision radius (m)'),
  whooshed = f(nil, 'a near miss was already heard'),
  shot = f(nil, 'shared weapon discharge: definition, payload, origin and hit accounting'),
  travelled = f(nil, 'weapon projectile path length for damage falloff (m)'),
  retain = f(nil, 'share of its power a piercing round still has'),
  passed = f(nil, 'bodies a piercing round went through'),
  through = f(nil, 'ids of those bodies'),
}
-- A thing of the world (session/entities.lua).
C.schemas.entity = {
  entity = f(nil, 'its kind'),
  x = f(0),
  z = f(0),
  level = f(nil, 'the surface it stands on, on a world with decks'),
  hp = f(nil, 'absent: it cannot be destroyed'),
  maxHp = f(nil),
  state = f(nil, 'what its kind keeps'),
}
-- A marked ground hazard: pool, line, lightning (enemies/hazards.lua).
C.schemas.hazard = {
  garden = f(nil, 'owned deposit family counted against its capacity'),
  harvest = f(nil, 'pending eruption warning bound to the owner windup'),
  erupting = f(nil, 'a consumed deposit in its final brief contact'),
  x = f(0),
  z = f(0),
  level = f(nil, 'the surface it lies on, on a world with decks'),
  delay = f(0, 'telegraph left (s)'),
  maxDelay = f(0),
  radius = f(0),
  volume = f(nil, 'finite ground cylinder: bottom/top, feet/body sample and radius policy'),
  life = f(0),
  pulse = f(0, 'time to the next damage pulse'),
  interval = f(nil),
  packet = f(nil),
  condition = f(nil),
  kind = f(nil, 'content/hazards.lua; none: a pool'),
  art = f(nil, 'painted ground rite style'),
  impactSound = f(nil, 'voice of the released ground contact'),
  reach = f(nil, 'where a wave dies out (m)'),
  spread = f(nil, 'how fast a wave grows (m/s)'),
  width = f(nil, 'depth of a wave or full width of a floor tear (m)'),
  angle = f(nil, 'where a sweeping line points (radians)'),
  spin = f(nil, 'how fast it turns (radians/s)'),
  centerX = f(nil, 'the place a safe circle wanders around'),
  centerZ = f(nil),
  orbit = f(nil, 'how far from it (m)'),
  hits = f(nil, 'ids of the bodies already struck'),
  owner = f(nil),
  side = f('demons', "its maker's side (content/factions.lua): it hurts bodies of a hostile one"),
  damage = f(nil),
  waitForCast = f(nil),
  cancelled = f(nil),
  justReleased = f(nil),
  struck = f(nil),
}
-- A supply or a soul on the floor.
C.schemas.pickup = {
  x = f(0),
  z = f(0),
  level = f(nil, 'the surface it lies on, on a world with decks'),
  kind = f(nil, 'health, ammo, soul'),
  amount = f(nil),
  slot = f(nil, 'weapon slot of ammunition'),
  weapon = f(nil, 'weapon id of ammunition (before slot)'),
  offer = f(nil, 'the shop offer a relic is (0.43, D8)'),
  rewardId = f(nil),
  owner = f(nil, 'whose kill left it (plan v11 E3d: the reward noted with its owner)'),
}
-- A thrown powder charge (combat/explosives.lua).
C.schemas.charge = {
  action = f(nil, 'immutable throw definition: flight, fuse and blast'),
  owner = f(nil, 'id of the knight that threw it (plan v11 E3d)'),
  x = f(0),
  y = f(0),
  z = f(0),
  vx = f(0),
  vy = f(0),
  vz = f(0),
  fuse = f(0, 'seconds to the blast'),
  maxFuse = f(0),
  spin = f(0),
  grounded = f(nil),
  pillarRadius = f(nil),
}
-- The knight: body, motion, weapons in hand and abilities.
C.schemas.knight = {
  id = f(nil, "unique per session: 'knight' .. n (pool 'knights')"),
  faction = f(nil, "own side, else 'knight' (content/factions.lua)"),
  x = f(16),
  z = f(27.5),
  level = f(nil, 'the surface he stands on, on a world with decks (physics/ground.lua)'),
  yaw = f(math.pi),
  pitch = f(0),
  character = f('knight', 'id in content/characters.lua'),
  hp = f(nil, 'from its character (Characters.born)'),
  maxHp = f(nil),
  armor = f(nil, 'ward: consumable shield pool'),
  maxArmor = f(nil),
  souls = f(0),
  essence = f(nil),
  resist = f(nil),
  conditions = f(nil),
  effectState = f(nil, 'ordered ongoing effect instances, clocks and source ids'),
  poise = f(nil),
  guardQuiet = f(nil),
  pushX = f(nil),
  pushOwner = f(nil, 'the owner of the blow that shoves him'),
  pushZ = f(nil),
  slamLock = f(nil),
  invuln = f(0),
  -- motion
  vx = f(0),
  vz = f(0),
  jump = f(0),
  jumpV = f(0),
  jumpBuffer = f(nil),
  dashBuffer = f(nil),
  crouch = f(0),
  airCap = f(nil),
  dashTimer = f(0),
  dashX = f(nil),
  dashZ = f(nil),
  perfectUsed = f(nil),
  dodgeFromX = f(nil, 'where the dodge began: its afterimage (perfect dodge)'),
  dodgeEnds = f(nil, 'when the safety of this dodge ends: a shot gives up what is left'),
  recoverAt = f(nil, 'when the body is back from its last shot and can dodge'),
  chainCount = f(nil, 'kills in the chain running (combat/chain.lua)'),
  chainLeft = f(nil, 'seconds the chain has left'),
  chainWeapon = f(nil, 'the weapon that made the chain: only it has the edge'),
  dodgeFromZ = f(nil),
  slideTimer = f(0),
  slideCooldown = f(0),
  slideAge = f(0),
  slideX = f(nil),
  slideZ = f(nil),
  -- weapons: the loadout (ordered weapon ids) and the arsenal, one live
  -- record per weapon (content/weapons.lua: W.newState)
  loadout = f(nil, 'weapon ids in slot order'),
  arsenal = f(nil, 'weapon id -> { mag, reserve, open, loaded, spent, readyAt }'),
  -- abilities: the loadout (ordered ability ids; Q casts the first) and one
  -- live record per ability (content/abilities.lua: newState)
  abilities = f(nil, 'ability ids in slot order'),
  abilityState = f(nil, 'ability id -> { uses, readyAt }'),
  resources = f(nil, 'resource id -> amount (content/resources.lua)'),
  resourcePause = f(nil, 'resource id -> seconds before it comes back'),
  rally = f(nil, 'health a blow took that can still be fought back'),
  rallyLeft = f(nil, 'for how much longer (s)'),
  sigilRanks = f(nil, 'copies equipped at the fire, keyed by sigil id'),
  sigilState = f(nil, 'transient verdict, reprisal and first-shot charges'),
  casting = f(nil, 'the cast in progress (combat/abilities.lua)'),
  trigger = f(nil, 'what the trigger mode of the weapon keeps (player/intent.lua)'),
  -- The actor's hands and trigger (plan v11 E3: the session kept them for
  -- its one knight until 0.33): the slot in hand, its cadence, the reload
  -- timeline (combat/reload.lua), the trigger buffer (player/intent.lua),
  -- its shots and its own shot sequence (the pellet pattern and contact
  -- seeds of its shots, combat/combat.lua).
  weapon = f(1, 'the loadout slot in hand'),
  cooldown = f(0, 'seconds until the weapon may fire'),
  reload = f(0, 'seconds of the reload left'),
  reloadWeapon = f(nil, 'the slot being reloaded'),
  reloadStage = f(0),
  reloadDuration = f(0),
  reloadOffset = f(0),
  fireBuffer = f(0, 'seconds a pull waits for the weapon'),
  fireCommand = f(nil, 'the buffered pull (observation and aim)'),
  shots = f(0),
  hits = f(0),
  shotSequence = f(0, "this actor's shots: its pellet pattern and contact seeds"),
  -- His observations' generation (plan v11 E4: combat/observation.lua).
  observationGeneration = f(0),
}
-- Weapon fields of the knight before the arsenal (0.24 F3).
require('src.core.strict').retire('knight', {
  'mag',
  'reserve',
  'revolverMag',
  'revolverReserve',
  'breechOpen',
  'spentShells',
  'cylinderOpen',
  'cylinderLoaded',
}, 'weapon state lives in player.arsenal[id] (content/weapons.lua)')
require('src.core.strict').retire(
  'knight',
  { 'charges' },
  'ability uses live in player.abilityState[id] (content/abilities.lua)'
)
require('src.core.strict').retire(
  'knight',
  { 'dash' },
  'a dodge is paid with stamina alone (0.42): player.resources.stamina'
)
-- Fields that are caches of a member, rebuilt rather than saved (plan v10
-- V4): a route's distance field belongs to the world's field cache.
C.transient = { path = true }
-- What every member of a pool has.
C.pools = {
  enemies = {
    'identity',
    'transform',
    'health',
    'guard',
    'motion',
    'brain',
    'perception',
    'attacker',
    'rush',
    'flight',
    'evade',
    'corpse',
    'appearance',
  },
  projectiles = { 'projectile' },
  hazards = { 'hazard' },
  pickups = { 'pickup' },
  charges = { 'charge' },
  knights = { 'knight' },
  entities = { 'entity' },
}
-- Pools whose members are still created by their systems (no strict schema
-- yet): their component is a tag without declared fields.
local tags = {}
function C.declare(world)
  for name, fields in pairs(C.schemas) do
    world:component(name, fields)
  end
  for _, tag in ipairs(tags) do
    world:component(tag, {})
  end
end
function C.prefabs(world)
  -- A demon of any creature definition.
  world:prefab('creature', { pool = 'enemies' })
  world:prefab('projectile', { pool = 'projectiles' })
  world:prefab('hazard', { pool = 'hazards' })
  world:prefab('pickup', { pool = 'pickups' })
  world:prefab('charge', { pool = 'charges' })
  world:prefab('entity', { pool = 'entities' })
  world:prefab('knight', { pool = 'knights', born = Characters.born })
end
return C
