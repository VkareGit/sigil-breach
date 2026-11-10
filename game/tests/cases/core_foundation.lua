-- E1: the foundation (src/core) on its own, before the game uses it.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run()
  local lines = {}
  local check = Fixtures.checker(lines, 'core: ', 'core: ')
  local Class = require('src.core.class')
  local Schema = require('src.core.schema')
  local Registry = require('src.core.registry')
  local Events = require('src.core.events')
  local World = require('src.core.ecs')
  local Scheduler = require('src.core.scheduler')
  local Rng = require('src.core.rng')
  local Timers = require('src.core.timers')
  local Strict = require('src.core.strict')
  local Serialize = require('src.core.serialize')

  -- Class: constructor, methods, inheritance, is().
  local Base = Class:extend('Base')
  function Base:init(v)
    self.v = v
  end
  function Base:double()
    return self.v * 2
  end
  local Child = Base:extend('Child')
  local c = Child:new(4)
  check(
    'a subclass inherits constructor and methods',
    c:double() == 8 and c:is(Base) and c:is(Child)
  )

  -- Schema: defaults, nested records, lists, validation paths, inheritance.
  local Attack = Schema:new('attack', {
    id = { type = 'string', required = true },
    windup = { type = 'number', default = 0.5, min = 0 },
  })
  local Body = Schema:new('body', {
    hp = { type = 'number', required = true, min = 1 },
    armor = { type = 'number', default = 0, min = 0 },
    resist = { type = 'table', default = {} },
  })
  local Creature = Schema:new('creature', {
    id = { type = 'string', required = true },
    body = { type = 'table', required = true, schema = Body },
    attacks = { type = 'table', default = {}, list = Attack },
  })
  local imp = Creature:build({ id = 'imp', body = { hp = 112 }, attacks = { { id = 'claw' } } })
  check(
    'a schema fills defaults into nested records and lists',
    imp.body.armor == 0 and type(imp.body.resist) == 'table' and imp.attacks[1].windup == 0.5
  )
  local problems = Creature:problems({ id = 'bad', body = { hp = -3, armr = 1 } })
  local text = table.concat(problems, '|')
  check(
    'validation names every broken field with its path',
    text:find('creature.body.hp: below 1', 1, true)
      and text:find('creature.body.armr: unknown field', 1, true)
  )
  local thrall = { body = { hp = 112, resist = { fire = 0 } }, attacks = { { id = 'claw' } } }
  local iron = Schema.inherit(thrall, { body = { hp = 170, armor = 60 } })
  check(
    'inheritance merges records and keeps the parent untouched',
    iron.body.hp == 170
      and iron.body.armor == 60
      and iron.body.resist.fire == 0
      and thrall.body.armor == nil
  )

  -- Registry: order, clear errors, entry checks.
  local r = Registry:new('kinds', function(entry, id)
    assert(type(entry.run) == 'function', id .. ' needs run')
  end)
  r:register('b', { run = print })
  r:register('a', { run = print })
  local order = {}
  for id in r:each() do
    order[#order + 1] = id
  end
  local ok, message = pcall(r.get, r, 'zz')
  check(
    'a registry keeps registration order and names known ids on a miss',
    order[1] == 'b'
      and order[2] == 'a'
      and not ok
      and tostring(message):find('known: b, a', 1, true)
  )
  check('a registry rejects an invalid entry', not pcall(r.register, r, 'c', {}))
  check(
    'a rejected new entry leaves no ghost in registration order',
    not r:has('c') and table.concat(r:ids(), ',') == 'b,a'
  )
  local accepted = r:register('c', { run = print })
  check(
    'correcting a rejected entry registers it exactly once',
    r:get('c') == accepted and table.concat(r:ids(), ',') == 'b,a,c'
  )
  check(
    'a duplicate id is rejected without replacing its accepted definition',
    not pcall(r.register, r, 'c', { run = function() end })
      and r:get('c') == accepted
      and table.concat(r:ids(), ',') == 'b,a,c'
  )
  check(
    'a rejected replacement preserves the accepted entry and its order',
    not pcall(r.replace, r, 'c', {})
      and r:get('c') == accepted
      and table.concat(r:ids(), ',') == 'b,a,c'
  )
  local replacement = { run = function() end }
  check(
    'an explicit replacement validates and keeps the existing iteration slot',
    r:replace('c', replacement) == replacement
      and r:get('c') == replacement
      and table.concat(r:ids(), ',') == 'b,a,c'
  )
  check(
    'replacement never silently registers a misspelled or missing id',
    not pcall(r.replace, r, 'missing', replacement)
      and not r:has('missing')
      and table.concat(r:ids(), ',') == 'b,a,c'
  )

  -- Events: sim handlers immediate by priority; present queued until flush.
  local bus = Events:new()
  bus:define('killed', 'a demon died')
  local log = {}
  bus:on('sim', 'killed', function()
    log[#log + 1] = 'reward'
  end, 20)
  bus:on('sim', 'killed', function()
    log[#log + 1] = 'heal'
  end, 10)
  bus:on('present', 'killed', function()
    log[#log + 1] = 'sound'
  end)
  bus:beginStep()
  bus:emit('killed', { id = 1 })
  local beforeFlush = table.concat(log, ',')
  bus:flush()
  check(
    'sim listeners run at emission in priority order; present waits for flush',
    beforeFlush == 'heal,reward' and table.concat(log, ',') == 'heal,reward,sound'
  )
  local direct = {}
  bus:on('present', 'killed', function()
    direct[#direct + 1] = 'now'
  end)
  bus:emit('killed', {})
  check('outside a step, presentation runs at once', #direct == 1)
  check('an undeclared event kind is an error', not pcall(bus.emit, bus, 'typo', {}))

  -- ECS: pools, prefabs with component defaults, queries across pools.
  local session = { enemies = {}, bullets = {} }
  local world = World:new()
  world:component('transform', { x = { default = 0 }, z = { default = 0 } })
  world:component('health', { hp = { default = 100 } })
  world:component('projectile', { life = { default = 3 } })
  world:pool('enemies', function()
    return session.enemies
  end, { 'transform', 'health' })
  world:pool('bullets', function()
    return session.bullets
  end, { 'transform', 'projectile' })
  world:prefab('imp', { pool = 'enemies' })
  world:prefab('bolt', { pool = 'bullets' })
  local e = world:create('imp', { x = 3, hp = 112 })
  world:create('bolt', { x = 9 })
  session.enemies[#session.enemies + 1] = { x = 1, z = 1, hp = 5 } -- a hand-made member
  check(
    'a prefab fills component defaults and joins its pool',
    e.z == 0 and e.hp == 112 and session.enemies[1] == e
  )
  check(
    'queries follow the live pools, hand-made members included, in order',
    #world:query('transform') == 3
      and #world:query('health') == 2
      and #world:query('projectile') == 1
  )

  -- Strict mode: an undeclared field on a prefab entity is an error.
  local wasStrict = Strict.enabled
  Strict.enabled = true
  local strict = world:create('imp', {}, false)
  local okDeclared = pcall(function()
    strict.hp = 3
  end)
  local okTypo = pcall(function()
    strict.hpp = 3
  end)
  Strict.enabled = wasStrict
  check('strict mode accepts declared fields and rejects typos', okDeclared and not okTypo)

  -- Scheduler: fixed order, early stop.
  local trace = {}
  local s = Scheduler:new('step')
  s:add('a', function()
    trace[#trace + 1] = 'a'
  end)
  s:add('b', function()
    trace[#trace + 1] = 'b'
    return false
  end)
  s:add('c', function()
    trace[#trace + 1] = 'c'
  end)
  local done, stoppedAt = s:run()
  check(
    'systems run in declared order and may end the step',
    table.concat(trace) == 'ab' and not done and stoppedAt == 'b'
  )

  -- Rng: deterministic per seed, in [0, 1).
  local r1, r2, r3 = Rng:new(42), Rng:new(42), Rng:new(43)
  local same, differs, inRange = true, false, true
  for _ = 1, 100 do
    local a, b, x = r1:random(), r2:random(), r3:random()
    same = same and a == b
    differs = differs or a ~= x
    inRange = inRange and a >= 0 and a < 1
  end
  check('a seeded stream repeats exactly and stays in [0, 1)', same and differs and inRange)
  -- A way's own seed is mixed first (PLAN Z2b): the first rolls of seeds 1 to 1000 spread
  -- over [0, 1) (unmixed, all 1000 lie under 0.07), each mixed seed its own and never 0.
  local bins, total, seen, distinct = {}, 0, {}, true
  for seed = 1, 1000 do
    local mixed = Rng.mix(seed)
    distinct = distinct and not seen[mixed] and Rng.validSeed(mixed)
    seen[mixed] = true
    local roll = Rng:new(mixed):random()
    total = total + roll
    bins[math.floor(roll * 10) + 1] = (bins[math.floor(roll * 10) + 1] or 0) + 1
  end
  local even = math.abs(total / 1000 - 0.5) < 0.03
  for bin = 1, 10 do
    even = even and (bins[bin] or 0) >= 70 and (bins[bin] or 0) <= 130
  end
  check('the first roll of 1000 way seeds spreads over [0, 1)', even and distinct)
  check(
    'a way seed is a whole number from 1 to 2^32 - 1',
    Rng.validSeed(1)
      and Rng.validSeed(Rng.largest)
      and not Rng.validSeed(0)
      and not Rng.validSeed(Rng.largest + 1)
      and not Rng.validSeed(1.5)
      and not Rng.validSeed('1')
  )

  -- Timers and serialization.
  local t = { stun = 0.3, flash = 0.05 }
  Timers.tick(t, { 'stun', 'flash', 'missing' }, 0.1)
  check(
    'timers count down to zero',
    math.abs(t.stun - 0.2) < 1e-12 and t.flash == 0 and t.missing == 0
  )
  local value = { b = 2, a = { 1, 2.5, 'x' }, c = true }
  local encoded = Serialize.encode(value)
  local back = Serialize.decode(encoded)
  check(
    'serialization is stable and reads back',
    encoded == Serialize.encode(back) and back.a[2] == 2.5 and back.c == true
  )
  return lines
end
return Tests
