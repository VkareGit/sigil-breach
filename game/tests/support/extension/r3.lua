-- Plan v12 R3: weapons that do not look like the two that exist, through public
-- registries alone, each kept by a save and shown by the same interface.
local Proof = require('tests.support.extension.proof')
local Ammo = require('src.content.ammo.index')
local Ballistics = require('src.combat.ballistics')
local Deliveries = require('src.combat.weapon_delivery')
local Delivery = require('src.content.defs.delivery')
local Intent = require('src.player.intent')
local Pools = require('src.session.world')
local Reload = require('src.combat.reload')
local Save = require('src.storage.session_save')
local Schema = require('src.core.schema')
local Triggers = require('src.content.triggers')
local Volley = require('src.combat.volley')
local Weapons = require('src.content.weapons')
local R = {}
local function always()
  return true
end
local function nothing() end
local function zero()
  return 0
end
-- Holds nothing: a blade is always ready.
local none = {
  schema = Schema:new('no ammunition', { kind = { type = 'string', required = true } }),
  newState = function()
    return {}
  end,
  valid = always,
  canFire = always,
  full = always,
  stocked = function()
    return false
  end,
  spend = function(_, _, count)
    return count
  end,
  pending = zero,
  load = zero,
  room = zero,
  refill = zero,
  fill = nothing,
  clear = nothing,
  restock = nothing,
  left = function()
    return 1
  end,
  meter = function()
    return 1, 0, 1
  end,
  offer = function()
    return 0, 0, 0
  end,
  pack = function()
    return {}
  end,
  list = function()
    return {}
  end,
  unpack = function()
    return {}
  end,
}
-- A gauge that fills with each shot and cools with time.
local heat = {}
for key, value in pairs(none) do
  heat[key] = value
end
heat.schema = Schema:new('heat', {
  kind = { type = 'string', required = true },
  limit = { type = 'number', required = true },
  shot = { type = 'number', required = true },
  cooling = { type = 'number', required = true },
})
function heat.newState()
  return { heat = 0 }
end
function heat.canFire(spec, state)
  return state.heat + spec.shot <= spec.limit
end
function heat.spend(spec, state, count)
  state.heat = state.heat + spec.shot
  return count
end
function heat.tick(spec, state, dt)
  state.heat = math.max(0, state.heat - spec.cooling * dt)
end
function heat.meter(spec, state)
  return spec.limit - state.heat, 0, spec.limit
end
local function gun(id, changes)
  local def = Schema.copy(Weapons.get('judge'))
  def.id, def.art = id, 'judge'
  for key, value in pairs(changes) do
    def[key] = value or nil
  end
  return def
end
local function armed(g, id)
  local p = g.player
  Weapons.give(g, id, p)
  p.weapon = Weapons.slotOf(g, id, p)
  p.yaw, p.pitch, p.cooldown, p.reload = 0, 0, 0, 0
  p.x, p.z = 10, 20
  return p
end
local function run(g, seconds, input)
  for _ = 1, math.floor(seconds * 120 + 0.5) do
    g:update(1 / 120, input or {})
  end
end
function R.run(Game, check, session)
  local refused = function(name, changes)
    check(name, not pcall(Weapons.define, gun('proof_wrong', changes)))
  end
  refused('a field outside its model is refused', {
    ammo = {
      kind = 'magazine',
      capacity = 1,
      startReserve = 0,
      maxReserve = 1,
      packSize = 1,
      heat = 3,
    },
  })
  refused('a magazine without a reload is refused', { reload = false })
  refused('an unknown mechanism is refused at definition', { reload = { mechanism = 'nothing' } })
  refused('an unknown trigger mode is refused', { trigger = { mode = 'nothing' } })
  refused('an unknown ammunition is refused', { ammo = { kind = 'nothing' } })
  local weapons = {
    'proof_blade',
    'proof_furnace',
    'proof_single',
    'proof_triple',
    'proof_lantern',
    'proof_quick',
    'proof_double',
  }
  Proof.with({
    function()
      for _, id in ipairs(weapons) do
        Weapons.registry:unregister(id)
      end
      Ammo:unregister('proof_none')
      Ammo:unregister('proof_heat')
      Deliveries:unregister('proof_melee')
      Delivery.kinds:unregister('proof_melee')
      for _, id in ipairs({ 'proof_semi', 'proof_burst', 'proof_charged' }) do
        Triggers:unregister(id)
        Intent.modes:unregister(id)
      end
    end,
  }, function()
    Ammo:register('proof_none', none)
    Ammo:register('proof_heat', heat)
    -- A blade: no rounds, no reload, its own way of reaching a body.
    Delivery.defineKind('proof_melee', {})
    Deliveries:register('proof_melee', {
      fire = function(g, shot)
        local volley = Volley.new(g, shot.profile, shot.attack, 1, shot.shooter)
        volley.origin, volley.sequence = shot.origin, shot.sequence
        local dx, dy, dz = Ballistics.spreadDirection(shot.yaw, shot.pitch, 0, 0)
        for _, e in ipairs(Pools.of(g, 'enemies')) do
          local d = math.sqrt((e.x - shot.shooter.x) ^ 2 + (e.z - shot.shooter.z) ^ 2)
          if d < 3 then
            volley:contact(e, d, e.x, 1, e.z, { 0, 1, 0 }, 'torso', 1, dx, dy, dz)
          end
        end
        volley:apply()
      end,
    })
    Weapons.define(gun('proof_blade', {
      ammo = { kind = 'proof_none' },
      reload = false,
      delivery = { kind = 'proof_melee' },
    }))
    local g = session(Game)
    local p = armed(g, 'proof_blade')
    local dx, _, dz = Ballistics.spreadDirection(p.yaw, p.pitch, 0, 0)
    local e = g:spawn('imp', p.x + dx * 2, p.z + dz * 2)
    e.awake = false
    local shots = p.shots
    run(g, 1.5, { shoot = true })
    check('a blade strikes with no rounds at all', p.shots > shots + 1 and e.hp < e.maxHp)
    check('and does not reload', p.reload == 0)
    local a, b, c = Weapons.meter(g, nil, p)
    check('the interface reads it through the model', a == 1 and b == 0 and c == 1)
    local copy = session(Game)
    Save.restore(copy, assert(Save.decode(Save.encode(g))))
    check('a save keeps it', copy.player.loadout[#copy.player.loadout] == 'proof_blade')
    -- A rifle that overheats.
    Weapons.define(gun('proof_furnace', {
      ammo = { kind = 'proof_heat', limit = 3, shot = 1, cooling = 2 },
      reload = false,
    }))
    g = session(Game)
    p = armed(g, 'proof_furnace')
    shots = p.shots
    run(g, 2, { shoot = true })
    local hot = p.shots - shots
    check('heat stops a rifle ' .. hot, hot >= 3)
    local value = Weapons.meter(g, nil, p)
    run(g, 2.5)
    check('and it cools', Weapons.meter(g, nil, p) > value)
    -- What a press means.
    Triggers.define('proof_semi')
    Intent.modes:register('proof_semi', function(p2, held)
      local state = p2.trigger or {}
      p2.trigger = state
      local pressed = held and not state.held
      state.held = held
      return pressed
    end)
    Triggers.define('proof_burst', { count = { type = 'number', required = true } })
    Intent.modes:register('proof_burst', function(p2, held, _, trigger)
      local state = p2.trigger or { left = 0, shots = p2.shots }
      p2.trigger = state
      state.left = math.max(0, state.left - (p2.shots - state.shots))
      state.shots = p2.shots
      if held and not state.held then
        state.left = trigger.count
      end
      state.held = held
      return state.left > 0
    end)
    Triggers.define('proof_charged', { time = { type = 'number', required = true } })
    Intent.modes:register('proof_charged', function(p2, held, dt, trigger)
      local state = p2.trigger or { charge = 0 }
      p2.trigger = state
      if held then
        state.charge = state.charge + dt
        return false
      end
      local ready = state.charge >= trigger.time
      state.charge = 0
      return ready
    end)
    Weapons.define(gun('proof_single', { trigger = { mode = 'proof_semi' } }))
    g = session(Game)
    p = armed(g, 'proof_single')
    shots = p.shots
    run(g, 1.5, { shoot = true })
    check('a held trigger of a single shot fires once', p.shots == shots + 1)
    Weapons.define(gun('proof_triple', { trigger = { mode = 'proof_burst', count = 3 } }))
    g = session(Game)
    p = armed(g, 'proof_triple')
    shots = p.shots
    run(g, 2.5, { shoot = true })
    check('a burst of three fires three ' .. (p.shots - shots), p.shots == shots + 3)
    Weapons.define(gun('proof_lantern', { trigger = { mode = 'proof_charged', time = 0.5 } }))
    g = session(Game)
    p = armed(g, 'proof_lantern')
    shots = p.shots
    run(g, 0.2, { shoot = true })
    run(g, 0.05)
    check('a charge too short goes nowhere', p.shots == shots)
    run(g, 0.6, { shoot = true })
    run(g, 0.05)
    check('a full charge goes off on release', p.shots == shots + 1)
    -- Its own reload.
    Weapons.define(gun('proof_quick', { reload = { mechanism = 'cylinder', speed = 2 } }))
    g = session(Game)
    p = armed(g, 'proof_quick')
    local state = Weapons.state(g, nil, p)
    state.mag = 0
    local mechanism = Reload.mechanisms.cylinder
    g:reloadGun(p.id)
    run(g, mechanism.duration * 0.55)
    check('a reload runs at its own speed', p.reload == 0 and state.mag > 0)
    -- A second mode of the same gun.
    local strong = Schema.copy(Weapons.get('judge').attack)
    strong.base = strong.base * 3
    Weapons.define(gun('proof_double', { secondary = { attack = strong, cycle = 1 } }))
    g = session(Game)
    p = armed(g, 'proof_double')
    local body = g:spawn('boss', p.x + dx * 3, p.z + dz * 3)
    body.awake = false
    run(g, 0.01, { shoot = true })
    local plain = body.maxHp - body.hp
    local before = body.hp
    p.cooldown = 0
    Weapons.state(g, nil, p).readyAt = 0
    run(g, 0.01, { altFire = true })
    check('a second mode has its own attack', before - body.hp > plain * 1.5)
  end)
  check('new weapons leave with their proof', not Weapons.registry:has('proof_blade'))
end
return R
