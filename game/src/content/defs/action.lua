-- Action: what a body does to the world — a demon attack today, the
-- knight's equipment (one format for both). An action is
-- a DELIVERY (kind: lunge, charge, leap, bolt, fan, pool, strike...) plus
-- a payload (packet) and a telegraph (windup). Every kind has its own
-- fields and defaults here; its behaviour lives in enemies/actions.lua
-- (Attacks.kinds) and is checked against this list.
local Schema = require('src.core.schema')
local Registry = require('src.core.registry')
local Packet = require('src.content.defs.packet')
local Claw = require('src.content.combat_defaults').claw
local Action = {}
-- Fields of every action, whatever its delivery.
Action.common = {
  id = { type = 'string', required = true },
  kind = { type = 'string', required = true, desc = 'delivery kind (Action.kinds)' },
  range = { type = 'number', required = true, min = 0, desc = 'longest use distance (m)' },
  minRange = { type = 'number', default = 0, min = 0 },
  maxRange = { type = 'number', min = 0, desc = 'preferred only below this distance' },
  windup = { type = 'number', required = true, min = 0, desc = 'telegraph (s), never shortened' },
  duration = { type = 'number', default = 0.23, min = 0, desc = 'strike state length (s)' },
  recover = { type = 'number', default = 0.48, min = 0, desc = 'pause after the strike (s)' },
  cooldown = { type = 'number', default = 1.6, min = 0, desc = 'before the next attack (s)' },
  rest = { type = 'number', min = 0, desc = 'own cooldown of this action (s)' },
  every = { type = 'number', min = 1, desc = 'only every n-th attack' },
  lead = { type = 'number', min = 0, desc = 'aim this far ahead of the player (s)' },
  aimLead = { type = 'number', default = 0, min = 0, desc = 'intercept share (tier-scaled)' },
  hyper = { type = 'number', min = 1, desc = 'guard multiplier while winding up and striking' },
  sound = { type = 'string' },
  packet = { type = 'table', schema = Packet.schema },
}
-- A projectile as part of an action (bolt, pool's spit, fan orbs).
Action.projectile = {
  speed = { type = 'number', required = true, min = 0 },
  height = { type = 'number', default = 1.4, desc = 'launch height (m)' },
  color = { type = 'table' },
  radius = { type = 'number', min = 0, desc = 'collision radius (default by size)' },
  big = { type = 'boolean', default = false },
  packet = { type = 'table', schema = Packet.schema },
}
local function kind(name, fields, required)
  local merged = {}
  for k, v in pairs(Action.common) do
    merged[k] = v
  end
  for k, v in pairs(fields) do
    merged[k] = v
  end
  for _, k in ipairs(required or {}) do
    local spec = {}
    for field, value in pairs(merged[k]) do
      spec[field] = value
    end
    spec.required = true
    merged[k] = spec
  end
  return Schema:new('action ' .. name, merged)
end
local Line = Schema:new('hazard line', {
  every = { type = 'number', required = true, min = 1 },
  count = { type = 'number', required = true, min = 1 },
  step = { type = 'number', required = true },
  delay = { type = 'number', required = true, min = 0 },
  radius = { type = 'number', required = true, min = 0 },
  life = { type = 'number', required = true, min = 0 },
  pulse = { type = 'number', required = true, min = 0 },
  packet = { type = 'table', required = true, schema = Packet.schema },
})
local Pool = Schema:new('hazard pool', {
  delay = { type = 'number', required = true, min = 0 },
  radius = { type = 'number', required = true, min = 0 },
  life = { type = 'number', required = true, min = 0 },
  pulse = { type = 'number', required = true, min = 0 },
  packet = { type = 'table', required = true, schema = Packet.schema },
  condition = { type = 'string', desc = 'condition applied while standing in it' },
})
-- Delivery kinds and their own fields (behaviour: enemies/actions.lua).
Action.kinds = Registry:new('action kinds')
Action.kinds:register(
  'lunge',
  kind('lunge', {
    lungeSpeed = { type = 'number', min = 0 },
    lungeTime = { type = 'number', min = 0 },
    active = { type = 'table', default = Claw.active, desc = 'active claw window (s)' },
    contactAnchor = { type = 'string', default = 'claw', desc = 'named source-art contact point' },
    contactRadius = {
      type = 'number',
      default = Claw.radius,
      min = 0,
      desc = 'contact sphere radius (m)',
    },
    contactReach = {
      type = 'table',
      default = Claw.reach,
      desc = 'forward depth samples from the painted contact (m)',
    },
  }, { 'lungeSpeed', 'lungeTime', 'packet' })
)
Action.kinds:register(
  'charge',
  kind('charge', {
    speed = { type = 'number', min = 0 },
    minTime = { type = 'number', min = 0 },
    maxTime = { type = 'number', min = 0 },
    reach = { type = 'number', min = 0 },
    contactY = { type = 'number' },
    contactRadius = { type = 'number', min = 0 },
  }, { 'speed', 'minTime', 'maxTime', 'reach', 'contactY', 'contactRadius', 'packet' })
)
Action.kinds:register(
  'leap',
  kind('leap', {
    height = { type = 'number', default = 1, min = 0, desc = 'apex of the arc (m)' },
    leadShare = { type = 'number', min = 0, max = 1, desc = 'predicted share of player motion' },
    landRadius = { type = 'number', default = 0.65, min = 0 },
  }, { 'packet' })
)
local bolt = {}
for k, v in pairs(Action.projectile) do
  bolt[k] = v
end
Action.kinds:register('bolt', kind('bolt', bolt, { 'speed', 'packet' }))
local fan = {}
for k, v in pairs(Action.projectile) do
  fan[k] = v
end
fan.rageSpeed = { type = 'number', min = 0 }
fan.count = { type = 'number', min = 1 }
fan.rageCount = { type = 'number', min = 1 }
fan.spread = { type = 'number', min = 0 }
fan.line = { type = 'table', schema = Line }
Action.kinds:register('fan', kind('fan', fan, { 'speed', 'count', 'spread', 'packet' }))
Action.kinds:register(
  'pool',
  kind('pool', {
    pool = { type = 'table', schema = Pool },
    bolt = { type = 'table', schema = Schema:new('pool spit', Action.projectile) },
  }, { 'pool', 'bolt' })
)
Action.kinds:register(
  'strike',
  kind('strike', {
    radius = { type = 'number', min = 0 },
    life = { type = 'number', min = 0 },
  }, { 'radius', 'life', 'packet' })
)
-- The blast of an area action: a full damage profile (combat/damage.lua).
Action.blast = Schema:new('blast', {
  base = { type = 'number', required = true, min = 0 },
  impact = { type = 'number', required = true, min = 0 },
  push = { type = 'number', min = 0 },
  damageType = { type = 'string', default = 'physical' },
  penetration = { type = 'number', default = 0, min = 0, max = 1 },
  falloffStart = { type = 'number', default = 0, min = 0 },
  falloffEnd = { type = 'number', required = true, min = 0 },
  minPower = { type = 'number', default = 0, min = 0, max = 1 },
})
-- throw: the knight's thrown charge (combat/explosives.lua). A ballistic
-- throw under world gravity, a fuse, a blast in a radius, a self-blast.
Action.kinds:register(
  'throw',
  kind('throw', {
    speed = { type = 'number', min = 0, desc = 'throw speed under the reference gravity' },
    lift = { type = 'number', min = 0, desc = 'extra upward speed' },
    referenceGravity = { type = 'number', default = 12, desc = 'gravity the throw was tuned for' },
    fuse = { type = 'number', min = 0, desc = 'seconds to the blast' },
    radius = { type = 'number', min = 0, desc = 'blast radius (m)' },
    noise = { type = 'number', default = 8, min = 0, desc = 'demons hearing the throw (m)' },
    blast = { type = 'table', schema = Action.blast },
    selfBlast = { type = 'table', schema = Action.blast, desc = 'what the knight takes' },
  }, { 'speed', 'lift', 'fuse', 'radius', 'blast', 'selfBlast' })
)
-- A new delivery kind without editing this file: its own fields (the common
-- ones are added), the ones it requires, and a builder Action.<name>. Its
-- behaviour is an entry in Attacks.kinds (enemies/actions.lua).
function Action.defineKind(name, fields, required)
  Action.kinds:register(name, kind(name, fields, required))
  Action[name] = function(def)
    def.kind = name
    return def
  end
end
-- Complete and validate one action (where: for the message).
function Action.build(def, where)
  local schema = Action.kinds:get(def.kind)
  local path = where or ('action ' .. tostring(def.id))
  local built = schema:build(def, path)
  if built.kind == 'throw' then
    assert(built.referenceGravity > 0, path .. '.referenceGravity: must be positive')
  end
  if built.kind == 'lunge' then
    assert(#built.contactReach > 0, path .. '.contactReach: at least one depth sample required')
    local count = 0
    for key, value in pairs(built.contactReach) do
      count = count + 1
      assert(
        type(key) == 'number' and key % 1 == 0 and key >= 1 and key <= #built.contactReach,
        path .. '.contactReach: expected a dense array'
      )
      assert(
        type(value) == 'number' and value == value and value >= 0 and value < math.huge,
        path .. '.contactReach[' .. key .. ']: expected a finite nonnegative depth'
      )
    end
    assert(count == #built.contactReach, path .. '.contactReach: expected a dense array')
  end
  return built
end
-- Builders by kind: Action.lunge({...}) == Action.build({ kind = 'lunge', ... })
for name in Action.kinds:each() do
  Action[name] = function(def)
    def.kind = name
    return def
  end
end
return Action
