-- Components of the session's entities: every field an entity may carry,
-- declared once with its default and meaning. Systems read and write these
-- fields directly (flat entities, core/ecs.lua); strict mode in the tests
-- rejects a field that no component of the entity declares.
-- A field with no default starts absent (nil means "not now": no target,
-- not leaping, no pending strike).
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
    rewardId = f(nil, 'expedition reward slot'),
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
  tier = {
    tier = f(1),
    tierSpeed = f(1),
    tierDamage = f(1),
    tierPace = f(1),
    tierLead = f(0),
    packetCache = f(nil, 'tier-scaled copies of attack packets'),
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
    ai = f('idle', 'state: idle, move, windup, strike, recover, hurt'),
    phase = f(0, 'time in the state'),
    recover = f(0),
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
    target = f(nil, 'id of the body it fights (enemies/target.lua)'),
  },
  attacker = {
    attackSpec = f(nil),
    attackKind = f(nil),
    attackCount = f(0),
    restUntil = f(nil),
    aimX = f(nil),
    aimZ = f(nil),
    aimLevel = f(nil, 'the surface under the aim, on a world with decks'),
    windup = f(0),
    windupDuration = f(nil),
    didHit = f(nil),
    pendingHazard = f(nil),
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
  },
}
-- A projectile in flight (enemies/actions.lua: projectile).
C.schemas.projectile = {
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
}
-- A marked ground hazard: pool, line, lightning (enemies/hazards.lua).
C.schemas.hazard = {
  x = f(0),
  z = f(0),
  level = f(nil, 'the surface it lies on, on a world with decks'),
  delay = f(0, 'telegraph left (s)'),
  maxDelay = f(0),
  radius = f(0),
  life = f(0),
  pulse = f(0, 'time to the next damage pulse'),
  interval = f(nil),
  packet = f(nil),
  condition = f(nil),
  kind = f(nil, 'lightning or a pool'),
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
  hp = f(100),
  armor = f(40, 'ward: consumable shield pool'),
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
  crouch = f(0),
  airCap = f(nil),
  dash = f(2, 'dodge charges'),
  dashTimer = f(0),
  dashX = f(nil),
  dashZ = f(nil),
  perfectUsed = f(nil),
  dodgeFromX = f(nil, 'where the dodge began: its afterimage (perfect dodge)'),
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
  -- legacy expedition state kept by saves (run/descent.lua restore)
  heat = f(nil),
  heatDelay = f(nil),
  overheat = f(nil),
  -- abilities: the loadout (ordered ability ids; Q casts the first) and one
  -- live record per ability (content/abilities.lua: newState)
  abilities = f(nil, 'ability ids in slot order'),
  abilityState = f(nil, 'ability id -> { uses, readyAt }'),
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
-- Fields that are caches of a member, rebuilt rather than saved (plan v10
-- V4): a route's distance field belongs to the world's field cache.
C.transient = { path = true }
-- What every member of a pool has.
C.pools = {
  enemies = {
    'identity',
    'transform',
    'tier',
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
  world:prefab('knight', { pool = 'knights' })
end
return C
