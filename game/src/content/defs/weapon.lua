-- Weapon: the TYPE OBJECT of a firearm, known by its id. A weapon file gives
-- only what differs from the firearm template: the attack payload (one pellet
-- or round), how a trigger pull fires, the reload mechanism, the ammunition
-- and the physical weight of the gun for the recoil. Its live state (rounds,
-- reserve, open action, ready time) is a record in the knight's arsenal
-- (content/weapons.lua: W.newState), never a field of the knight.
local Schema = require('src.core.schema')
local Id = require('src.core.id')
local Delivery = require('src.content.defs.delivery')
local Effect = require('src.content.defs.effect')
local Weapon = {}
Weapon.pierce = Schema:new('body penetration', {
  bodies = { type = 'number', required = true, min = 0 },
  retain = { type = 'number', required = true, min = 0, max = 1 },
  armorCost = { type = 'number', required = true, min = 0 },
  minRetain = { type = 'number', required = true, min = 0, max = 1 },
})
Weapon.glyph = Schema:new('weapon modifier', {
  spread = { type = 'number', min = 0, max = 4 },
  set = { type = 'table', default = {} },
  scale = { type = 'table', default = {} },
})
Weapon.hud = Schema:new('weapon labels', {
  title = { type = 'string', required = true },
  kind = { type = 'string', required = true },
  tab = { type = 'string', required = true },
  draw = { type = 'string', required = true },
  partial = { type = 'string' },
  partialShort = { type = 'string' },
})
Weapon.attack = Schema:new('weapon attack', {
  effects = { type = 'table', list = Effect.schema, desc = 'effects after a damaging body contact' },
  base = { type = 'number', required = true, min = 0 },
  impact = { type = 'number', required = true, min = 0, desc = 'guard damage' },
  push = { type = 'number', min = 0, desc = 'physical impulse when it differs from impact' },
  headMultiplier = { type = 'number', default = 1, min = 0 },
  damageType = { type = 'string', default = 'physical' },
  penetration = { type = 'number', default = 0, min = 0, max = 1 },
  falloffStart = { type = 'number', required = true, min = 0 },
  falloffEnd = { type = 'number', required = true, min = 0 },
  minPower = { type = 'number', required = true, min = 0, max = 1 },
  pierce = {
    type = 'table',
    schema = Weapon.pierce,
    desc = '{ bodies, retain, armorCost, minRetain }',
  },
})
Weapon.fire = Schema:new('trigger pull', {
  heavy = { type = 'boolean', default = false, desc = 'two-handed (recoil, trails)' },
  rounds = { type = 'number', default = 1, min = 1, desc = 'rounds spent by one pull' },
  pellets = { type = 'number', default = 1, min = 1, desc = 'pellets of a full pull' },
  spread = {
    type = 'number',
    default = 1,
    min = 0,
    max = 4,
    desc = 'angular cone scale before modifiers',
  },
  ejects = { type = 'boolean', default = false, desc = 'spent cases stay until the action opens' },
  autoReload = { type = 'boolean', default = false },
  noise = {
    type = 'number',
    default = 14,
    min = 0,
    desc = 'demons within this distance hear it (m)',
  },
  muzzle = { type = 'number', required = true, min = 0 },
  shake = { type = 'number', required = true, min = 0 },
  flash = { type = 'table', required = true },
  sound = { type = 'string', required = true },
  volume = { type = 'number', default = 0.65, min = 0 },
  volumePower = { type = 'number', default = 0, min = 0 },
  smoke = { type = 'number', required = true, min = 0 },
  smokeTime = { type = 'number', required = true, min = 0 },
  surfaceEvery = {
    type = 'number',
    default = 1,
    min = 1,
    desc = 'every n-th pellet marks a surface',
  },
  trailEvery = { type = 'number', default = 1, min = 1, desc = 'every n-th pellet draws a trail' },
})
Weapon.weight = Schema:new('weapon weight', {
  mass = { type = 'number', required = true, min = 0 },
  momentum = { type = 'number', required = true, min = 0 },
  fov = { type = 'number', required = true },
  roll = { type = 'number', required = true },
  aim = { type = 'number', required = true },
  carry = { type = 'number', required = true },
  punch = { type = 'number', required = true },
  back = { type = 'number', required = true },
  flip = { type = 'number', required = true },
  tail = { type = 'number', required = true },
  wrist = { type = 'number', required = true },
  wristK = { type = 'number', required = true },
  wristD = { type = 'number', required = true },
  wristLimit = { type = 'number', required = true },
  -- The shot felt in the eyes and the gut (0.26 G6; presentation only): the
  -- view climbs viewKick rad and settles at rate (1/s, critically damped,
  -- always back before the next pull), and a low thump plays at this volume.
  viewKick = { type = 'number', default = 0, min = 0 },
  viewKickRate = { type = 'number', default = 30, min = 1 },
  thump = { type = 'number', default = 0, min = 0 },
})
Weapon.schema = Schema:new('weapon', {
  id = { type = 'string', required = true, desc = 'registry id (saves, loadouts)' },
  name = { type = 'string', required = true },
  art = { type = 'string', desc = 'hands sheet (content/weapon_art.lua); default: the id' },
  hud = {
    type = 'table',
    required = true,
    schema = Weapon.hud,
    desc = 'labels: title, kind, tab, draw; partial / partialShort when a pull is short',
  },
  capacity = { type = 'number', required = true, min = 1 },
  startReserve = { type = 'number', required = true, min = 0 },
  maxReserve = { type = 'number', required = true, min = 0 },
  packSize = { type = 'number', required = true, min = 1 },
  unitPrice = { type = 'number', default = 3, min = 0 },
  cycle = { type = 'number', required = true, min = 0, desc = 'time between pulls (s)' },
  range = { type = 'number', required = true, min = 0 },
  mechanism = { type = 'string', required = true, desc = 'reload mechanism (combat/reload.lua)' },
  delivery = {
    type = 'table',
    default = { kind = 'hitscan' },
    desc = 'transport, independent of damage type',
  },
  fire = { type = 'table', required = true, schema = Weapon.fire },
  attack = { type = 'table', required = true, schema = Weapon.attack },
  glyphs = { type = 'table', default = {} },
  weight = { type = 'table', required = true, schema = Weapon.weight },
})
function Weapon.define(def)
  local parent = def.extends
  local own = {}
  for k, v in pairs(def) do
    if k ~= 'extends' then
      own[k] = v
    end
  end
  local merged = parent and Schema.inherit(parent, own) or Schema.copy(own)
  if parent and own.art == nil then
    merged.art = parent.art or parent.id
  end
  -- Different delivery variants have different fields. Switching the kind
  -- replaces its record; tuning the same kind inherits unspecified parameters.
  if
    parent
    and own.delivery
    and own.delivery.kind
    and own.delivery.kind ~= (parent.delivery and parent.delivery.kind or 'hitscan')
  then
    merged.delivery = Schema.copy(own.delivery)
  end
  local built = Weapon.schema:build(merged, 'weapon ' .. tostring(def.id))
  Id.check(built.id, 'weapon.id')
  built.delivery = Delivery.build(built.delivery, 'weapon ' .. built.id .. '.delivery')
  for channel = 1, 3 do
    local value = built.fire.flash[channel]
    assert(
      type(value) == 'number' and value >= 0 and value <= 1,
      'weapon ' .. built.id .. '.fire.flash: expected RGB channels in [0, 1]'
    )
  end
  if built.fire.rounds > 1 then
    built.hud.partial = built.hud.partial or 'PARTIAL DISCHARGE'
    built.hud.partialShort = built.hud.partialShort or 'PARTIAL'
  end
  assert(
    built.delivery.kind ~= 'projectile' or not built.attack.pierce,
    'weapon ' .. built.id .. ': finite projectiles stop at first contact; pierce belongs to hitscan'
  )
  for _, key in ipairs({ 'capacity', 'startReserve', 'maxReserve', 'packSize' }) do
    assert(built[key] % 1 == 0, 'weapon ' .. built.id .. '.' .. key .. ': expected integer')
  end
  for _, key in ipairs({ 'rounds', 'pellets', 'surfaceEvery', 'trailEvery' }) do
    assert(
      built.fire[key] % 1 == 0,
      'weapon ' .. built.id .. '.fire.' .. key .. ': expected integer'
    )
  end
  assert(
    built.fire.pellets % built.fire.rounds == 0,
    'weapon ' .. built.id .. ': pellets must divide into whole rounds'
  )
  assert(
    built.startReserve <= built.maxReserve,
    'weapon ' .. built.id .. ': reserve exceeds maximum'
  )
  assert(
    built.attack.falloffEnd > built.attack.falloffStart,
    'weapon ' .. built.id .. ': invalid damage curve'
  )
  assert(
    built.weight.mass > 0 and built.cycle > 0 and built.range > 0,
    'weapon ' .. built.id .. ': mass, cycle and range must be positive'
  )
  local function validateAttack(attack, path)
    Weapon.attack:validate(attack, path)
    assert(attack.falloffEnd > attack.falloffStart, path .. ': invalid damage curve')
    assert(
      not attack.pierce or attack.pierce.bodies % 1 == 0,
      path .. ': pierce.bodies must be integer'
    )
    assert(
      built.delivery.kind ~= 'projectile' or not attack.pierce,
      path .. ': finite projectiles do not support pierce'
    )
  end
  validateAttack(built.attack, 'weapon ' .. built.id .. '.attack')
  for id, source in pairs(built.glyphs) do
    local path = 'weapon ' .. built.id .. '.glyphs.' .. tostring(id)
    assert(type(id) == 'string', path .. ': modifier id must be a string')
    local mod = Weapon.glyph:build(source, path)
    local attack = Schema.copy(built.attack)
    for key, value in pairs(mod.set) do
      attack[key] = Schema.copy(value)
    end
    for key, scale in pairs(mod.scale) do
      assert(
        Weapon.attack.fields[key] and Weapon.attack.fields[key].type == 'number',
        path .. '.scale.' .. tostring(key) .. ': expected a numeric attack field'
      )
      assert(
        type(scale) == 'number' and scale >= 0 and scale < math.huge,
        path .. '.scale.' .. key .. ': expected finite nonnegative scale'
      )
      assert(
        type(attack[key]) == 'number',
        path .. '.scale.' .. key .. ': field has no numeric value'
      )
      attack[key] = attack[key] * scale
    end
    validateAttack(attack, path)
    built.glyphs[id] = mod
  end
  return built
end
return Weapon
