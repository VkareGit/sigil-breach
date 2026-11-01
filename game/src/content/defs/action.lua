-- Action: what a body does to the world — a demon attack today, the
-- knight's equipment (one format for both). An action is
-- a DELIVERY (kind: lunge, charge, leap, bolt, fan, pool, strike...) plus
-- a payload (packet) and a telegraph (windup). Every kind has its own
-- fields and defaults here; its behaviour lives in combat/action_kinds.lua
-- and is checked against this list.
local Conditions = require('src.content.conditions')
local Schema = require('src.core.schema')
local Types = require('src.content.damage_types')
local HazardKinds = require('src.content.hazards')
local Registry = require('src.core.registry')
local Packet = require('src.content.defs.packet')
local Claw = require('src.content.combat_defaults').claw
local Area = require('src.content.defs.area')
local AttackDefaults = require('src.content.combat_defaults').attacks
local Action = { hooks = {} }
-- A blow that flows into the next one instead of a full rest. every: only each
-- n-th time, so the short and the long string alternate in a fixed order.
local Branch = Schema:new('attack branch', {
  into = { type = 'string', desc = 'the blow it goes on with; none: it stops here' },
  weight = { type = 'number', default = 1, min = 0 },
})
local Flow = Schema:new('attack string', {
  into = { type = 'string', desc = 'the attack it flows into' },
  branches = { type = 'table', list = Branch, desc = 'or a roll among these' },
  gap = { type = 'number', default = 0.12, min = 0, desc = 'the beat between them (s)' },
  every = { type = 'number', min = 1, desc = 'flows only every n-th time' },
})
-- Fields of every action, whatever its delivery.
Action.common = {
  id = { type = 'string', required = true },
  kind = { type = 'string', required = true, desc = 'delivery kind (Action.kinds)' },
  range = { type = 'number', required = true, min = 0, desc = 'longest use distance (m)' },
  minRange = { type = 'number', default = 0, min = 0 },
  maxRange = {
    type = 'number',
    min = 0,
    desc = 'preferred only below this distance (the last of a list is the fallback)',
  },
  windup = { type = 'number', required = true, min = 0, desc = 'telegraph (s), never shortened' },
  duration = { type = 'number', default = 0.23, min = 0, desc = 'strike state length (s)' },
  recover = { type = 'number', default = 0.48, min = 0, desc = 'pause after the strike (s)' },
  cooldown = { type = 'number', default = 1.6, min = 0, desc = 'before the next attack (s)' },
  rest = { type = 'number', min = 0, desc = 'own cooldown of this action (s)' },
  every = {
    type = 'number',
    min = 1,
    desc = 'preferred only every n-th attack (the last of a list is the fallback)',
  },
  lead = { type = 'number', min = 0, desc = 'aim this far ahead of the player (s)' },
  aimLead = { type = 'number', default = 0, min = 0, desc = 'intercept share (tier-scaled)' },
  leadFloor = {
    type = 'number',
    default = 0,
    min = 0,
    max = 1,
    desc = 'minimum observed-velocity prediction at any tier',
  },
  hyper = { type = 'number', min = 1, desc = 'guard multiplier while winding up and striking' },
  parry = {
    type = 'number',
    min = 0,
    desc = 'for this long before it strikes a shot throws the blow away (s)',
  },
  parryReach = { type = 'number', min = 0, desc = 'from how far a shot can do it (m)' },
  chase = {
    type = 'number',
    min = 0,
    desc = 'in the blow the body follows who goes with the swing (rad/s); against it, no',
  },
  mirror = { type = 'boolean', desc = 'each use rolls the side a traced blow starts from' },
  shuffle = { type = 'boolean', desc = 'each use rolls its hold instead of taking turns' },
  steady = {
    type = 'boolean',
    desc = 'a guard broken during this blow falls when the blow ends, not before',
  },
  string = { type = 'table', schema = Flow },
  hold = {
    type = 'table',
    desc = 'stillness after the windup (s), one entry per use in a fixed order',
  },
  track = {
    type = 'number',
    min = 0,
    max = 1,
    desc = 'share of the windup the aim follows the target; frozen after it',
  },
  turn = {
    type = 'number',
    min = 0,
    desc = 'the body turns to its target through the windup (rad/s) and the blow goes that way',
  },
  lockAt = {
    type = 'number',
    default = 0.6,
    min = 0,
    max = 1,
    desc = 'share of the windup after which a turning body stops turning',
  },
  sound = { type = 'string' },
  windupSound = { type = 'string', desc = 'presentation cue at commitment, distinct from release' },
  packet = { type = 'table', schema = Packet.schema },
}
-- A projectile as part of an action (bolt, pool's spit, fan orbs).
Action.projectile = {
  speed = { type = 'number', required = true, min = 0 },
  height = { type = 'number', default = 1.4, desc = 'launch height (m)' },
  aimHeight = {
    type = 'number',
    default = AttackDefaults.aimHeight,
    desc = 'aim height over target ground (m); fixed at release, not homing',
  },
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
  volume = Area.field('pool'),
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
  volume = Area.field('pool'),
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
    turns = { type = 'number', default = 0, min = 0, desc = 'new rushes at the target' },
    bend = { type = 'number', min = 0, desc = 'how fast the rush turns after him (rad/s)' },
    turnPause = { type = 'number', default = 0.3, min = 0, desc = 'visible stop before each (s)' },
  }, { 'speed', 'minTime', 'maxTime', 'reach', 'contactY', 'contactRadius', 'packet' })
)
Action.kinds:register(
  'leap',
  kind('leap', {
    height = { type = 'number', default = 1, min = 0, desc = 'apex of the arc (m)' },
    leadShare = { type = 'number', min = 0, max = 1, desc = 'predicted share of player motion' },
    landRadius = { type = 'number', default = 0.65, min = 0 },
    landVolume = Area.field('landing'),
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
local spit = Schema:new('pool spit', Action.projectile):extend('pool spit', {
  packet = { type = 'table', required = true, schema = Packet.schema },
})
Action.kinds:register(
  'pool',
  kind('pool', {
    pool = { type = 'table', schema = Pool },
    bolt = { type = 'table', schema = spit },
  }, { 'pool', 'bolt' })
)
Action.kinds:register(
  'strike',
  kind('strike', {
    volume = Area.field('lightning'),
    radius = { type = 'number', min = 0 },
    life = { type = 'number', min = 0 },
  }, { 'radius', 'life', 'packet' })
)
-- A bounded arrangement of independently warned ground contacts. Offsets are
-- in the locked aim basis, never in the camera basis and never homing.
local Mark = Schema:new('pattern mark', {
  forward = { type = 'number', required = true },
  lateral = { type = 'number', required = true },
  delay = { type = 'number', required = true, min = 0 },
})
Action.kinds:register(
  'pattern',
  kind('pattern', {
    origin = { type = 'string', default = 'target', values = { 'target', 'caster' } },
    marks = { type = 'table', required = true, list = Mark },
    hazard = { type = 'string', required = true, check = HazardKinds.problem },
    volume = Area.field('pool'),
    radius = { type = 'number', required = true, min = 0 },
    life = { type = 'number', required = true, min = 0 },
    pulse = { type = 'number', required = true, min = 0 },
    condition = { type = 'string', desc = 'condition on a body standing in it' },
  }, { 'packet' })
)
-- What a burning cut leaves on the floor where it passed.
local Trail = Schema:new('trail', {
  origin = { type = 'string', default = 'caster', values = { 'caster' } },
  marks = { type = 'table', required = true, list = Mark },
  hazard = { type = 'string', default = 'pool', check = HazardKinds.problem },
  volume = Area.field('pool'),
  radius = { type = 'number', required = true, min = 0 },
  life = { type = 'number', required = true, min = 0 },
  pulse = { type = 'number', required = true, min = 0 },
  packet = { type = 'table', required = true, schema = Packet.schema },
})
-- One moment of a blow's path, measured from the body along the way it faces:
-- at seconds of the strike the tip stands angle radians to its side, reach m
-- away and height m above the floor.
local TraceKey = Schema:new('trace key', {
  at = { type = 'number', required = true, min = 0 },
  angle = { type = 'number', required = true },
  reach = { type = 'number', required = true, min = 0 },
  height = { type = 'number', required = true, min = 0 },
})
local swing = {
  reach = { type = 'number', min = 0, desc = 'how far the blow goes from the body (m)' },
  arc = { type = 'number', min = 0, desc = 'its width (radians)' },
  active = { type = 'table', default = { 0.06, 0.2 }, desc = 'when it can land (s)' },
  trace = {
    type = 'table',
    list = TraceKey,
    desc = 'the path of the blow; with one, reach, arc and active follow from it',
  },
  blade = {
    type = 'table',
    default = Claw.blade,
    desc = 'shares of the reach met by the blow, tip first',
  },
  contactRadius = {
    type = 'number',
    default = Claw.bladeRadius,
    min = 0,
    desc = 'thickness of a traced blow (m)',
  },
  lungeSpeed = { type = 'number', default = 0, min = 0 },
  lungeTime = { type = 'number', default = 0, min = 0 },
  closing = {
    type = 'number',
    min = 0,
    desc = 'the step comes after who backs away: it stops this share of reach short of him',
  },
  volume = Area.field('sweep'),
}
local function with(fields, more)
  local out = {}
  for key, spec in pairs(fields) do
    out[key] = spec
  end
  for key, spec in pairs(more) do
    out[key] = spec
  end
  return out
end
-- A wide blow with real reach, passed by leaving its arc or jumping a low one.
Action.kinds:register(
  'sweep',
  kind('sweep', with(swing, { trail = { type = 'table', schema = Trail } }), { 'packet' })
)
-- A grip: it pins what it catches and hurts when the grip closes.
Action.kinds:register(
  'seize',
  kind(
    'seize',
    with(swing, {
      grip = { type = 'number', min = 0, desc = 'how long it holds (s)' },
    }),
    { 'grip', 'packet' }
  )
)
-- A ring spreading from the body over the floor.
Action.kinds:register(
  'wave',
  kind('wave', {
    speed = { type = 'number', min = 0 },
    width = { type = 'number', default = 0.8, min = 0, desc = 'depth of the ring (m)' },
    reach = { type = 'number', min = 0, desc = 'where it dies out (m)' },
    start = { type = 'number', default = 0.6, min = 0, desc = 'its first radius (m)' },
    delay = { type = 'number', default = 0, min = 0 },
    volume = Area.field('wave'),
  }, { 'speed', 'reach', 'packet' })
)
-- A ray sweeping the room around the body; standing stone stops it.
Action.kinds:register(
  'beam',
  kind('beam', {
    length = { type = 'number', min = 0 },
    arc = { type = 'number', min = 0, desc = 'the angle it crosses (radians)' },
    spin = { type = 'number', min = 0, desc = 'radians per second' },
    delay = { type = 'number', default = 0.5, min = 0, desc = 'warned before it moves (s)' },
    volume = Area.field('beam'),
  }, { 'length', 'arc', 'spin', 'packet' })
)
-- Existing creatures called to the body, bounded by a limit of the living.
Action.kinds:register(
  'summon',
  kind('summon', {
    creature = { type = 'string', required = true },
    count = { type = 'number', default = 1, min = 1 },
    limit = { type = 'number', default = 2, min = 1, desc = 'of its own alive at once' },
    distance = { type = 'number', default = 2.5, min = 0, desc = 'how far from the body (m)' },
    spread = { type = 'number', default = 1.2, min = 0, desc = 'between two of them (radians)' },
  }, {})
)
-- The knight drinks: nothing leaves him, health comes back at the end.
Action.kinds:register('drink', kind('drink', { heal = { type = 'number', min = 0 } }, { 'heal' }))
-- The body springs back from its target.
Action.kinds:register(
  'hop',
  kind('hop', {
    speed = { type = 'number', min = 0 },
    lungeTime = { type = 'number', min = 0 },
  }, { 'speed', 'lungeTime' })
)
-- The body is gone and stands elsewhere.
Action.kinds:register(
  'blink',
  kind('blink', {
    distance = { type = 'number', min = 0, desc = 'from its target (m)' },
  }, { 'distance' })
)
-- Missiles let go one after another, each aimed anew.
local salvo = {}
for k, v in pairs(Action.projectile) do
  salvo[k] = v
end
salvo.count = { type = 'number', min = 1 }
salvo.interval = { type = 'number', min = 0 }
Action.kinds:register('salvo', kind('salvo', salvo, { 'speed', 'count', 'interval', 'packet' }))
-- Bolts that fall where the target stood a moment before.
Action.kinds:register(
  'storm',
  kind('storm', {
    count = { type = 'number', min = 1 },
    interval = { type = 'number', min = 0 },
    delay = { type = 'number', min = 0, desc = 'warned before each falls (s)' },
    radius = { type = 'number', min = 0 },
    life = { type = 'number', default = 0.22, min = 0 },
    volume = Area.field('lightning'),
  }, { 'count', 'interval', 'delay', 'radius', 'packet' })
)
-- The whole room strikes except a circle that wanders.
Action.kinds:register(
  'tempest',
  kind('tempest', {
    radius = { type = 'number', min = 0, desc = 'of the safe circle (m)' },
    orbit = { type = 'number', default = 0, min = 0, desc = 'its path around the mark (m)' },
    spin = { type = 'number', default = 0, min = 0, desc = 'radians per second along it' },
    delay = { type = 'number', default = 1.2, min = 0 },
    life = { type = 'number', min = 0 },
    pulse = { type = 'number', min = 0 },
  }, { 'radius', 'life', 'pulse', 'packet' })
)
-- The blast of an area action: a full damage profile (combat/damage.lua).
Action.blast = Schema:new('blast', {
  effects = { type = 'table', list = require('src.content.defs.effect').schema },
  base = { type = 'number', required = true, min = 0 },
  impact = { type = 'number', required = true, min = 0 },
  push = { type = 'number', min = 0 },
  damageType = { type = 'string', default = 'physical', check = Types.problem },
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
-- ones are added), the ones it requires, hooks (build(def) completes a
-- definition, validate(built, path) checks it) and a builder Action.<name>. Its
-- behaviour is an entry in combat/action_kinds.lua.
function Action.defineKind(name, fields, required, hooks)
  Action.kinds:register(name, kind(name, fields, required))
  Action.hooks[name] = hooks
  Action[name] = function(def)
    def.kind = name
    return def
  end
end
local function samples(values, path, size)
  assert(#values > 0 and (not size or #values == size), path .. ': invalid sample count')
  local count = 0
  for key, value in pairs(values) do
    count = count + 1
    assert(
      type(key) == 'number' and key % 1 == 0 and key >= 1 and key <= #values,
      path .. ': expected a dense array'
    )
    assert(
      type(value) == 'number' and value == value and value >= 0 and value < math.huge,
      path .. '[' .. tostring(key) .. ']: expected a finite nonnegative number'
    )
  end
  assert(count == #values, path .. ': expected a dense array')
end
local function integer(value, path)
  assert(value == nil or value % 1 == 0, path .. ': expected an integer')
end
local function projectile(spec, path)
  if spec.color then
    samples(spec.color, path .. '.color', 3)
    for _, channel in ipairs(spec.color) do
      assert(channel <= 1, path .. '.color: expected RGB channels in [0, 1]')
    end
  end
end
local function hook(name, validate)
  Action.hooks[name] = { validate = validate }
end
hook('throw', function(built, path)
  assert(built.referenceGravity > 0, path .. '.referenceGravity: must be positive')
  for _, field in ipairs({ 'blast', 'selfBlast' }) do
    local blast = built[field]
    assert(blast.falloffEnd > blast.falloffStart, path .. '.' .. field .. ': invalid damage curve')
  end
end)
hook('lunge', function(built, path)
  samples(built.contactReach, path .. '.contactReach')
  samples(built.active, path .. '.active', 2)
  assert(built.active[2] > built.active[1], path .. '.active: end must follow start')
  assert(built.lungeTime > 0, path .. '.lungeTime: must be positive')
  assert(built.active[2] <= built.lungeTime, path .. '.active: exceeds lungeTime')
  assert(built.lungeTime <= built.duration, path .. '.lungeTime: exceeds strike duration')
end)
hook('charge', function(built, path)
  assert(built.speed > 0, path .. '.speed: must be positive')
  assert(
    built.maxTime > 0 and built.maxTime >= built.minTime,
    path .. '.maxTime: invalid charge window'
  )
end)
hook('leap', function(built, path)
  assert(built.height > 0, path .. '.height: must be positive')
  Area.validate(built.landVolume, path .. '.landVolume')
end)
hook('strike', function(built, path)
  Area.validate(built.volume, path .. '.volume')
end)
hook('pattern', function(built, path)
  Area.validate(built.volume, path .. '.volume')
  assert(#built.marks > 0 and #built.marks <= 12, path .. ': needs 1..12 marks')
  assert(
    built.radius > 0 and built.life > 0 and built.pulse > 0,
    path .. ': positive footprint and cadence required'
  )
  for _, mark in ipairs(built.marks) do
    assert(mark.delay > 0, path .. ': every released mark needs a warning')
  end
  assert(
    not built.condition or Conditions.find(built.condition),
    path .. '.condition: unknown condition ' .. tostring(built.condition)
  )
end)
hook('pool', function(built, path)
  Area.validate(built.pool.volume, path .. '.pool.volume')
  assert(built.pool.pulse > 0, path .. '.pool.pulse: must be positive')
  assert(
    not built.pool.condition or Conditions.find(built.pool.condition),
    path .. '.pool.condition: unknown condition ' .. tostring(built.pool.condition)
  )
  projectile(built.bolt, path .. '.bolt')
end)
hook('fan', function(built, path)
  integer(built.count, path .. '.count')
  integer(built.rageCount, path .. '.rageCount')
  if built.line then
    Area.validate(built.line.volume, path .. '.line.volume')
    assert(built.line.pulse > 0, path .. '.line.pulse: must be positive')
    integer(built.line.count, path .. '.line.count')
    integer(built.line.every, path .. '.line.every')
  end
  projectile(built, path)
end)
hook('bolt', projectile)
-- What a blow's path says of its reach, width and window.
local function traced(built, path)
  local trace = built.trace
  assert(#trace >= 2, path .. '.trace: needs two moments at least')
  local far, low, high = 0, trace[1].angle, trace[1].angle
  for index, key in ipairs(trace) do
    assert(index == 1 or key.at > trace[index - 1].at, path .. '.trace: moments must follow')
    far, low, high = math.max(far, key.reach), math.min(low, key.angle), math.max(high, key.angle)
  end
  built.reach, built.arc = far, high - low
  built.active = { trace[1].at, trace[#trace].at }
end
local function swung(built, path)
  if built.trace then
    traced(built, path)
  end
  assert(built.reach and built.arc, path .. ': needs reach and arc, or a trace')
  samples(built.blade, path .. '.blade')
  samples(built.active, path .. '.active', 2)
  assert(built.active[2] > built.active[1], path .. '.active: end must follow start')
  assert(built.active[2] <= built.duration, path .. '.active: exceeds strike duration')
  assert(built.lungeTime <= built.duration, path .. '.lungeTime: exceeds strike duration')
  Area.validate(built.volume, path .. '.volume')
end
hook('sweep', swung)
hook('seize', swung)
hook('wave', function(built, path)
  Area.validate(built.volume, path .. '.volume')
  assert(built.speed > 0, path .. '.speed: must be positive')
end)
hook('beam', function(built, path)
  Area.validate(built.volume, path .. '.volume')
  assert(built.spin > 0, path .. '.spin: must be positive')
end)
hook('salvo', projectile)
-- What the rest of the game may ask of a kind without naming it:
--   airborne  its strike carries the body through the air
--   gathers   the body sinks and widens through the windup
--   lands     the place it lands on is marked from the windup
--   cuts      it leaves a painted cut in the air
Action.hooks.leap.traits = { airborne = true, gathers = true, lands = true }
Action.hooks.sweep.traits = { cuts = true }
Action.hooks.seize.traits = { cuts = true }
function Action.trait(action, name)
  local hooks = Action.hooks[action.kind]
  return hooks and hooks.traits and hooks.traits[name]
end
-- Complete and validate one action (where: for the message).
function Action.build(def, where)
  local schema = Action.kinds:get(def.kind)
  local path = where or ('action ' .. tostring(def.id))
  local shaped = Action.hooks[def.kind]
  if shaped and shaped.build then
    def = shaped.build(def)
  end
  local built = schema:build(def, path)
  assert(built.id ~= '', path .. '.id: must not be empty')
  assert(built.minRange <= built.range, path .. '.minRange: exceeds range')
  if built.maxRange then
    assert(
      built.maxRange >= built.minRange and built.maxRange <= built.range,
      path .. '.maxRange: must lie between minRange and range'
    )
  end
  integer(built.every, path .. '.every')
  local hooks = Action.hooks[built.kind]
  if hooks and hooks.validate then
    hooks.validate(built, path)
  end
  if built.hold then
    samples(built.hold, path .. '.hold')
  end
  if built.string then
    assert(built.string.into or built.string.branches, path .. '.string: flows nowhere')
    assert(built.string.into ~= built.id, path .. '.string: flows into itself')
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
