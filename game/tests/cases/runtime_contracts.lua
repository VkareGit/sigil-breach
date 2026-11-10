-- Contract edges found by reading the code (handbook runtime findings 1, 2, 7
-- and 10): a failing recorded command, ammunition named by weapon id, one
-- death reported twice and the last attack as the fallback of a list.
local Fixtures = require('tests.support.fixtures')
local Journal = require('src.session.journal')
local Spawn = require('src.session.spawn')
local Interactions = require('src.session.interactions')
local Telemetry = require('src.combat.telemetry')
local Attacks = require('src.enemies.actions')
local Tests = {}
local function failing()
  error('fixture command failure')
end
function Tests.run(Game)
  local lines = {}
  local check = Fixtures.checker(lines, 'runtime contracts: ', 'runtime contracts: ')

  -- A recorded command that fails stops the recording; the depth of nested
  -- commands never stays raised behind it.
  local g = Fixtures.arena(Game)
  g.interact = failing
  local log = Journal.record(g)
  local ok, message = pcall(g.interact, g)
  check(
    'a failing recorded command reaches the caller with its own error',
    not ok and tostring(message):find('fixture command failure', 1, true) ~= nil
  )
  check(
    'a failing recorded command stops the recording with its reason',
    log.stopped == 'error' and log.final ~= nil and log.entries[#log.entries][1] == 'interact'
  )
  check(
    'after the failure the session is plain and can be recorded again',
    rawget(g, 'interact') == nil and pcall(Journal.record, g)
  )
  Journal.stop(g)

  local nested = Fixtures.arena(Game)
  nested.interact = failing
  nested.update = function(self)
    return self:interact()
  end
  local nestedLog = Journal.record(nested)
  local failed = not pcall(nested.update, nested)
  local inner = false
  for _, entry in ipairs(nestedLog.entries) do
    inner = inner or entry[1] == 'interact'
  end
  check(
    'a failure inside a nested command stops the recording once',
    failed
      and nestedLog.stopped == 'error'
      and nestedLog.entries[#nestedLog.entries][1] == 'update'
      and not inner
      and rawget(nested, 'update') == nil
  )

  local returning = Fixtures.arena(Game)
  returning.look = function()
    return 'turned', nil, nil
  end
  local returningLog = Journal.record(returning)
  check(
    'a recorded command keeps its result count, trailing nils included',
    select('#', returning:look()) == 3 and returningLog.stopped == nil
  )
  Journal.stop(returning)

  -- Ammunition named by weapon id passes strict entities and fills that gun.
  local field = Fixtures.arena(Game)
  local player = field.player
  local judge, exorcist = player.arsenal.judge, player.arsenal.exorcist
  judge.reserve = 0
  local exorcistReserve = exorcist.reserve
  local named = Spawn.make(field, 'pickup', {
    x = player.x,
    z = player.z,
    kind = 'ammo',
    amount = 3,
    weapon = 'judge',
  })
  local absent = Spawn.make(field, 'pickup', {
    x = player.x,
    z = player.z,
    kind = 'ammo',
    amount = 3,
    weapon = 'fixture-not-carried',
  })
  local empty = Spawn.make(field, 'pickup', {
    x = player.x,
    z = player.z,
    kind = 'ammo',
    amount = 3,
    slot = 9,
  })
  local ammo = Interactions.supplies.ammo
  check(
    'a weapon the knight does not carry and an empty slot want nothing',
    ammo.wanted(player, absent) == false and ammo.wanted(player, empty) == false
  )
  Interactions.collectSupplies(field)
  local left = {}
  for _, pickup in ipairs(field.pickups) do
    left[pickup] = true
  end
  check(
    'a pickup with a weapon id fills that weapon only',
    judge.reserve == 3 and exorcist.reserve == exorcistReserve and not left[named]
  )
  check('unusable ammunition stays on the floor', left[absent] and left[empty])

  -- One death, two reports: the counters move once.
  local arena = Fixtures.arena(Game)
  Telemetry.reset(arena)
  local e = arena:spawn('imp', 16, 20)
  e.spawnAge = 1
  arena:damageEnemy(e, e.hp + 1, 'weapon')
  local counted = Telemetry.get(arena)
  local kills, samples = counted.kills, counted.ttkCount
  Telemetry.kill(arena, e)
  check(
    'a second report of one death changes no counter',
    kills == 1 and counted.kills == 1 and counted.ttkCount == samples
  )

  -- The attack list: preferences first, the last attack as the fallback.
  -- A session that stepped its knight and was left lets go of everything
  -- once collected: the knight's step keeps no session between steps
  -- (qa/resource_plateau.lua found the last one held through the scratch
  -- table of player/feel.lua). Made in a function the compiler cannot keep.
  local left = setmetatable({}, { __mode = 'k' })
  local function leave()
    local session = Fixtures.arena(Game)
    for _ = 1, 3 do
      session:update(1 / 120, {})
    end
    left[session] = true
  end
  jit.off(leave, true)
  leave()
  collectgarbage('collect')
  collectgarbage('collect')
  jit.flush()
  collectgarbage('collect')
  collectgarbage('collect')
  check('a session that stepped and was left is collected', next(left) == nil)

  local function attack(id, extra)
    local atk = { id = id, range = 10, minRange = 0 }
    for key, value in pairs(extra or {}) do
      atk[key] = value
    end
    return atk
  end
  local close = attack('close', { maxRange = 3 })
  local cadence = attack('cadence', { every = 2 })
  local last = attack('last', { every = 3 })
  local body = { archetype = { attacks = { close, cadence, last } }, attackCount = 1 }
  local choose = Attacks.choose
  check('maxRange is preferred below its distance', choose(body, 2, 0) == close)
  body.attackCount = 2
  check('every fits a multiple of the counter', choose(body, 5, 0) == cadence)
  body.attackCount = 0
  check('a counter of 0 fits every cadence', choose(body, 5, 0) == cadence)
  body.attackCount = 1
  check(
    'with no preference fitting, the last attack is chosen despite its every',
    choose(body, 5, 0) == last
  )
  check('the fallback still obeys range', choose(body, 11, 0) == nil)
  body.restUntil = { last = 5 }
  check(
    'the fallback still obeys its rest',
    choose(body, 5, 1) == nil and choose(body, 5, 6) == last
  )
  return lines
end
return Tests
