-- Fresh session data. Every mutable table belongs to one session; defaults are
-- not shared with the renderer, saves, test field or another game instance.
local World = require('src.world.arena')
local SessionWorld = require('src.session.world')
local EventCatalog = require('src.session.event_catalog')
local Rng = require('src.core.rng')
local State = {}
-- Seed of a session's simulation stream (deterministic; replays and the
-- golden master depend on it). Presentation draws from its own stream.
State.seed = 1

-- mode: the session kind; mapId: the map it is built on (content/maps).
function State.new(mode, mapId)
  local session = {
    world = World.new(mode, mapId),
    -- What the session looks and sounds like (camera, weapon motion, effects,
    -- messages): presentation state, never read by the simulation's rules.
    -- Its fields are declared in session/fields.lua (Fields.view).
    view = {
      particles = {},
      muzzle = 0,
      hurt = 0,
      surge = 0,
      hitmarker = 0,
      shake = 0,
      message = '',
      messageTimer = 0,
      feedback = '',
      feedbackTimer = 0,
      damageDir = 0,
    },
    enemies = {},
    bullets = {},
    pickups = {},
    charges = {},
    events = {},
    hazards = {},
    state = 'menu',
    time = 0,
    elapsed = 0,
    step = 0,
    weapon = 1,
    cooldown = 0,
    reload = 0,
    kills = 0,
    shots = 0,
    hits = 0,
    seals = 0,
    nextId = 0,
    bossSpawned = false,
    bossDead = false,
    secretFound = false,
    flowTimer = 0,
    threat = 0,
    nextAttack = 0,
    damageTaken = 0,
    score = 0,
    combo = 0,
    comboTimer = 0,
    zone = '',
    zoneTimer = 0,
    map = false,
    help = false,
  }
  -- The session's ECS world over its own arrays, its event bus and its two
  -- random streams (core/ecs, core/events, core/rng).
  session.ecs = SessionWorld.new(session)
  -- The knight from its prefab (session/components.lua: knight); health from
  -- its body definition, its loadout and arsenal from the weapon definitions.
  local Weapons = require('src.content.weapons')
  local loadout = {}
  for i, id in ipairs(Weapons.defaultLoadout) do
    loadout[i] = id
  end
  local Abilities = require('src.content.abilities')
  local abilities = {}
  for i, id in ipairs(Abilities.defaultLoadout) do
    abilities[i] = id
  end
  session.player = session.ecs:create('knight', {
    hp = require('src.content.enemies').player.body.hp,
    -- The knight stands at the map's spawn.
    x = session.world.spawn.x,
    z = session.world.spawn.z,
    yaw = session.world.spawn.yaw,
    loadout = loadout,
    arsenal = Weapons.arsenal(loadout),
    abilities = abilities,
    abilityState = Abilities.kit(abilities),
  }, false)
  session.bus = EventCatalog.newBus()
  require('src.session.listeners').attach(session)
  session.rng = { sim = Rng:new(State.seed), present = Rng:new(State.seed + 1) }
  return session
end

return State
