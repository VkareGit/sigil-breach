-- Fresh session data. Every mutable table belongs to one session; defaults are
-- not shared with the renderer, saves, test field or another game instance.
local World = require('src.world.arena')
local SessionWorld = require('src.session.world')
local EventCatalog = require('src.session.event_catalog')
local Rng = require('src.core.rng')
local Roles = require('src.core.roles')
local State = {}
-- Seed of a session's simulation stream (deterministic; replays and the
-- golden master depend on it). Presentation draws from its own stream.
State.seed = 1

-- mapId: the map it is built on (content/maps).
function State.new(mapId)
  local session = {
    world = World.new(mapId),
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
    -- Corpses at rest, out of every step (session/world.lua: Pools.retire).
    remains = {},
    bullets = {},
    pickups = {},
    charges = {},
    things = {},
    events = {},
    hazards = {},
    state = 'menu',
    time = 0,
    elapsed = 0,
    step = 0,
    nextId = 0,
    -- The encounter's guardian (session/encounter.lua).
    encounter = { guardianSpawned = false, guardianDead = false },
    flowTimer = 0,
    threat = 0,
    nextAttack = 0,
    zone = '',
    zoneTimer = 0,
    map = false,
    help = false,
  }
  -- The session's ECS world over its own arrays, its event bus and its two
  -- random streams (core/ecs, core/events, core/rng).
  session.ecs = SessionWorld.new(session)
  -- The knight from its prefab (session/components.lua: knight); health from
  -- its character, its loadout and arsenal from the weapon definitions.
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
  -- Knights are a pool (1..n); g.player is the one this session controls.
  session.knights = {}
  session.player = session.ecs:create('knight', {
    id = 'knight1',
    -- The knight stands at the map's spawn.
    x = session.world.spawn.x,
    z = session.world.spawn.z,
    yaw = session.world.spawn.yaw,
    loadout = loadout,
    arsenal = Weapons.arsenal(loadout),
    abilities = abilities,
    abilityState = Abilities.kit(abilities),
  })
  session.bus = EventCatalog.newBus()
  require('src.session.listeners').attach(session)
  session.rng = { sim = Rng:new(State.seed), present = Rng:new(State.seed + 1) }
  return session
end

return State
