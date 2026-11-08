-- Observation is input data: prove real HP/receipts, blocking, lifecycle and
-- replay rather than just comparing two copies of projection mathematics.
local Fixtures = require('tests.support.fixtures')
local O = require('src.combat.observation')
local B = require('src.combat.ballistics')
local Surface = require('src.enemies.surface')
local Weapons = require('src.content.weapons')
local Intent = require('src.player.intent')
local Journal = require('src.session.journal')
local Serialize = require('src.core.serialize')
local Input = require('src.app.input')
local T = {}
function T.run(G, renderer)
  local lines = {}
  local check = Fixtures.checker(lines, 'shot observation: ', 'shot observation: ')
  local function setup()
    local g = Fixtures.arena(G)
    g:switchWeapon(2)
    -- The imp breathes on the simulation clock (PLAN F3): at 3.25 s a round
    -- flies its whole way while the body holds one painted frame.
    g.player.cooldown, g.elapsed = 0, 3.25
    local e = g:spawn('imp', 16, 21)
    e.dummy, e.spawnAge, e.hp, e.maxHp = true, 1, 1000, 1000
    local p = Surface.prepare(g, e)
    local x, y, z = Surface.locateZone(p, 'torso')
    local ox, oy, oz = B.origin(g)
    g.player.yaw = math.atan2(x - ox, z - oz)
    g.player.pitch = math.atan2(y - oy, math.sqrt((x - ox) ^ 2 + (z - oz) ^ 2))
    assert(B.trace(g, g.player.yaw, g.player.pitch, 30) == e, 'fixture aims at real pigment')
    return g, e
  end
  local g, e = setup()
  local observation = O.capture(g)
  local frozen = Serialize.encode(observation)
  local command = O.command(observation, g)
  e.x = e.x + 2
  g.player.x = g.player.x - 1
  local currentTarget = B.trace(g, g.player.yaw, g.player.pitch, 30)
  local report
  g.bus:on('sim', 'VolleyResolved', function(event)
    report = event.report
  end)
  check(
    'direct shot resolves the shown body despite later actor/eye motion',
    currentTarget ~= e and g:shoot(command) and e.hp < 1000 and report.contacts[1].targetId == e.id
  )
  check(
    'capture and resolution never mutate submitted plain geometry',
    Serialize.encode(observation) == frozen
      and #frozen < 5000
      and not observation.bodies[1].surface.parts
      and not observation.bodies[1].surface.mask
  )
  local buffered, target = setup()
  local tap = O.command(O.capture(buffered), buffered)
  buffered.player.cooldown = 0.04
  check('unready direct press does not spend ammunition', not buffered:shoot(tap))
  Intent.queue(buffered, 'fire', tap)
  target.x = target.x + 2
  buffered.player.yaw = 0
  tap.observation.bodies[1].surface.x = -100 -- caller cannot mutate queued ownership
  for _ = 1, 8 do
    buffered:update(1 / 120, {})
  end
  check(
    'released buffer retains press-time geometry and aim through cooldown',
    buffered.player.shots == 1 and target.hp < 1000 and buffered.player.fireCommand == nil
  )
  local held, old = setup()
  local oldCommand = O.command(O.capture(held), held)
  Intent.queue(held, 'fire', oldCommand)
  old.x = old.x + 2
  local fresh = O.command(O.capture(held), held)
  held:update(1 / 120, { shoot = true, fireCommand = fresh })
  check(
    'held trigger replaces an old buffered tap with its latest observation',
    held.player.shots == 1 and old.hp == 1000 and held.player.fireCommand == nil
  )
  local covered, safe = setup()
  local beforeCover = O.command(O.capture(covered), covered)
  covered.world.map[23][16] = 1
  covered:shoot(beforeCover)
  check('current world cover still blocks a historically clear shot', safe.hp == 1000)
  for _, removed in ipairs({ false, true }) do
    local dead, front = setup()
    local back = dead:spawn('imp', 16, 18)
    back.hp, back.maxHp, back.dummy, back.spawnAge = 1000, 1000, true, 1
    local view = O.command(O.capture(dead), dead)
    front.hp = 0
    front.deathTime = 20
    if removed then
      dead.enemies = { back }
    end
    local kills = require('src.session.stats').total(dead, 'kills')
    local contacts
    dead.bus:on('sim', 'VolleyResolved', function(event)
      contacts = event.report.contacts
    end)
    dead:shoot(view)
    check(
      (removed and 'removed' or 'dead')
        .. ' observed body retains first contact without a new wound or reward',
      front.hp == 0
        and require('src.session.stats').total(dead, 'kills') == kills
        and contacts[1].targetId == front.id
        and contacts[1].kind == 'corpse'
        and contacts[1].damage == 0
    )
  end
  local stale = setup()
  local expired = O.command(O.capture(stale), stale)
  stale.elapsed = stale.elapsed + O.maxAge + 0.001
  local ammo = Weapons.state(stale).mag
  check(
    'an expired observation is rejected before ammo/cadence are changed',
    not stale:shoot(expired) and Weapons.state(stale).mag == ammo and stale.player.shots == 0
  )
  local foreign = setup()
  O.session(foreign)
  check(
    'another session cannot use an observation even with matching entity IDs',
    not foreign:shoot(command) and foreign.player.shots == 0
  )
  local paused = setup()
  local adapter = Input.new()
  adapter:present(paused, paused)
  local previous = adapter:command(paused)
  Intent.queue(paused, 'fire', previous)
  adapter:focus({
    game = paused,
    has = function()
      return false
    end,
  }, false)
  check(
    'focus loss clears buffer, invalidates view and suppresses held mouse',
    paused.state == 'paused'
      and paused.player.fireCommand == nil
      and not O.valid(paused, previous.observation)
      and adapter.suppressFire
      and adapter.observation == nil
  )
  paused.state = 'playing'
  adapter:present(paused, paused)
  local renewed = adapter:command(paused)
  adapter:gameplayKey({ game = paused }, 'escape', false)
  check(
    'pause invalidates the previous observation before a resumed shot',
    paused.state == 'paused' and not O.valid(paused, renewed.observation)
  )
  local timeout = setup()
  timeout.player.cooldown = 1
  Intent.queue(timeout, 'fire', O.command(O.capture(timeout), timeout))
  for _ = 1, 44 do
    timeout:update(1 / 120, {})
  end
  check(
    'expired fire buffer releases its observation without a delayed shot',
    timeout.player.fireBuffer == 0
      and timeout.player.fireCommand == nil
      and timeout.player.shots == 0
  )
  local reset = setup()
  local oldStage = O.command(O.capture(reset), reset)
  require('src.session.encounter').clearStage(reset)
  check(
    'headless stage replacement invalidates IDs from the old observation',
    not reset:shoot(oldStage) and reset.player.shots == 0
  )
  -- Replay records observations explicitly; no draw or presentation capture
  -- runs in the replay. Exercise all three trigger routes and journal ownership.
  local recorded = setup()
  local journal = Journal.record(recorded)
  local first = O.command(O.capture(recorded), recorded)
  recorded:shoot(first)
  first.observation.origin[1] = -999
  for _ = 1, 48 do
    recorded:update(1 / 120, {})
  end
  Intent.queue(recorded, 'fire', O.command(O.capture(recorded), recorded))
  recorded:update(1 / 120, {})
  for _ = 1, 48 do
    recorded:update(1 / 120, {})
  end
  recorded:update(1 / 120, { shoot = true, fireCommand = O.command(O.capture(recorded), recorded) })
  Journal.stop(recorded)
  local decoded = assert(Journal.decode(Journal.encode(journal)))
  local replay = setup()
  Journal.replay(replay, decoded)
  check(
    'direct, buffered and held contacts replay without a renderer',
    replay.player.shots == 3
      and #journal.receipts >= 6
      and replay.enemies[1].hp == recorded.enemies[1].hp
  )
  -- A finite projectile must ignore observed body placement and resolve at
  -- arrival; its impulse follows travel even after the shooter crosses it.
  local def = Weapons.define({
    extends = Weapons.get('exorcist'),
    id = 'observation_probe',
    delivery = { kind = 'projectile', speed = 18, radius = 0.025 },
    fire = { rounds = 1, pellets = 1, autoReload = false },
  })
  local ok, reason = pcall(function()
    local flying, moved = setup()
    local slot = Weapons.give(flying, def.id)
    flying.player.weapon, flying.player.cooldown = slot, 0
    local before = O.command(O.capture(flying), flying)
    moved.x = moved.x + 2
    flying:shoot(before)
    check(
      'finite rounds emit without an instant historical hit',
      moved.hp == 1000 and #flying.bullets == 1
    )
    for _ = 1, 45 do
      flying:update(1 / 120, {})
    end
    check(
      'finite delivery uses current arrival geometry, not the observed old body',
      moved.hp == 1000
    )
    local physical, hit = setup()
    physical.player.weapon, physical.player.cooldown = Weapons.give(physical, def.id), 0
    physical:shoot(O.command(O.capture(physical), physical))
    physical.player.z = 18
    local direction
    physical.bus:on('sim', 'BlowResolved', function(event)
      if event.target == hit then
        direction = hit.pushZ
      end
    end)
    for _ = 1, 40 do
      physical:update(1 / 120, {})
    end
    check(
      'finite impulse follows the incoming round after shooter relocation',
      hit.hp < 1000 and direction and direction < 0
    )
  end)
  Weapons.registry:unregister(def.id)
  require('src.session.snapshot').invalidateDefinitions()
  assert(ok, reason)
  local Field = require('src.run.test_field')
  local order = Field.new(G)
  order.ephemeral, order.testField.frozen = true, true
  Field.close(order)
  local p = order.player
  local fx, fz, rx, rz = math.sin(p.yaw), math.cos(p.yaw), math.cos(p.yaw), -math.sin(p.yaw)
  local front = order:spawn('armored', p.x + fx * 5, p.z + fz * 5)
  local back = order:spawn('boss', p.x + fx * 10 - rx * 0.6, p.z + fz * 10 - rz * 0.6)
  for _, enemy in ipairs({ front, back }) do
    enemy.spawnAge, enemy.awake = 1, false
    enemy.facing = math.atan2(p.x - enemy.x, p.z - enemy.z)
  end
  local truth = require('qa.hit_truth').new(renderer)
  local _, stats =
    require('qa.reviews.hit_truth').orderCheck(truth, order, { front, back }, 'regression')
  truth:release()
  check('order oracle counts authored decorative passthrough separately', stats.decorative > 0)
  check(
    'armored cloak before boss has no unexplained order/contact differences',
    stats.missed == 0
      and stats.wrongBody == 0
      and stats.ghost == 0
      and stats.agree + stats.edge == stats.rays
  )
  require('qa.observation_budget').run(G)
  return lines
end
return T
