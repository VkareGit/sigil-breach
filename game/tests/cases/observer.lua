-- The observer of geometry (plan v11 E4). The simulation never asks the
-- camera's viewer: a shot is resolved on the bodies its shooter's own
-- observation shows, turned to his eye; a missile's targets turn to its owner
-- while he stands and is present, else to the point it was fired from; an
-- observation names its shooter and his generation, and ends with his death,
-- a change of control or his leave, never with another's. Drawing (any
-- camera, any order) changes nothing of the world.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, renderer)
  local lines = {}
  local check = Fixtures.checker(lines, 'observer: ', 'observer: ')
  local O = require('src.combat.observation')
  local B = require('src.combat.ballistics')
  local Surface = require('src.enemies.surface')
  local Geometry = require('src.enemies.geometry')
  local Pose = require('src.enemies.pose')
  local Pools = require('src.session.world')
  local Journal = require('src.session.journal')
  local Integrity = require('src.session.integrity')
  local Projection = require('qa.state_projection')
  local Weapons = require('src.content.weapons')
  local Abilities = require('src.content.abilities')
  local Intent = require('src.player.intent')
  local Input = require('src.app.input')
  local Projectiles = require('src.combat.projectiles')
  local Snapshot = require('src.session.snapshot')
  local step = 1 / 120
  local bolt = Weapons.define({
    extends = Weapons.get('exorcist'),
    id = 'observer_bolt',
    delivery = { kind = 'projectile', speed = 6, radius = 0.025 },
    fire = { rounds = 1, pellets = 1, autoReload = false },
  })
  Snapshot.invalidateDefinitions()
  -- A knight as a member record (the pools section's format).
  local function knight(g, id, x, z, fields)
    local loadout = { 'exorcist', 'judge', 'observer_bolt' }
    local k = g.ecs:create('knight', {
      id = id,
      x = x,
      z = z,
      yaw = math.pi,
      hp = 100,
      loadout = loadout,
      arsenal = Weapons.arsenal(loadout),
      abilities = { 'powder' },
      abilityState = Abilities.kit({ 'powder' }),
      weapon = 2,
    }, false)
    for key, value in pairs(fields or {}) do
      k[key] = value
    end
    return Pools.memberRecord(k)
  end
  -- The aim of an eye at a zone of a painted body as that eye sees it.
  local function aimAt(g, eye, e, zone)
    local p = Surface.prepare(g, e, nil, eye)
    local x, y, z = Surface.locateZone(p, zone)
    local ox, oy, oz = B.origin(g, eye)
    return math.atan2(x - ox, z - oz), math.atan2(y - oy, math.sqrt((x - ox) ^ 2 + (z - oz) ^ 2))
  end
  local function aim(g, k, e, zone)
    k.yaw, k.pitch = aimAt(g, k, e, zone)
  end
  -- The same through the look command (a journal records it).
  local function turn(g, k, e, zone)
    local yaw, pitch = aimAt(g, k, e, zone)
    g:look(yaw - k.yaw, pitch - k.pitch, k.id)
  end
  -- The classic arena without its garrison: A (controlled) and one painted
  -- demon standing still; B joins by command (so a journal records him).
  local spots = { A = { 14, 25 }, B = { 19, 24 } }
  local function arena(extra)
    local g = G.new('floor')
    g.testing = true
    g:start()
    Pools.clear(g, 'enemies')
    Pools.clear(g, 'pickups')
    g.player.x, g.player.z, g.player.yaw = spots.A[1], spots.A[2], math.pi
    g:switchWeapon(2)
    g.player.cooldown = 0
    local e = g:spawn('imp', 16, 20.5)
    e.dummy, e.spawnAge, e.hp, e.maxHp = true, 1, 5000, 5000
    e.facing = 0
    if extra then
      extra(g)
    end
    return g, e
  end
  local function join(g, fields)
    assert(g:actorJoin(knight(g, 'knight2', spots.B[1], spots.B[2], fields)))
    return Pools.get(g, 'knight2')
  end
  local function volleys(g)
    local out = {}
    g.bus:on('sim', 'VolleyResolved', function(event)
      out[#out + 1] = event.report
    end)
    return out
  end

  -- One observation per shooter, from his own eye; a foreign one is refused.
  local g, e = arena()
  local a, b = g.player, join(g)
  check('the demon is a painted body (a billboard turned to its observer)', not Geometry.uses(e))
  aim(g, a, e, 'torso')
  aim(g, b, e, 'head')
  local seenA, seenB = O.capture(g, g, a), O.capture(g, g, b)
  local bx, by, bz = B.origin(g, b)
  check(
    'an observation names its shooter and starts at his eye, turned to him',
    seenA.shooter == 'knight1'
      and seenB.shooter == 'knight2'
      and seenB.origin[1] == bx
      and seenB.origin[2] == by
      and seenB.origin[3] == bz
      and math.abs(Pose.sample(g, e, nil, b).yaw - math.atan2(b.x - e.x, b.z - e.z)) < 1e-9
      and seenA.bodies[1].surface.nx ~= seenB.bodies[1].surface.nx
  )
  local magA, magB = Weapons.state(g, nil, a).mag, Weapons.state(g, nil, b).mag
  local before = Integrity.capture(g)
  check(
    "A's command with B's observation (another eye, another sample) is refused without spending ammunition",
    g:shoot(O.command(seenB, g, a)) == false
      and g:shoot(O.command(seenA, g, b), 'knight2') == false
      and Weapons.state(g, nil, a).mag == magA
      and Weapons.state(g, nil, b).mag == magB
      and a.shots == 0
      and b.shots == 0
      and not Integrity.difference(before, Integrity.capture(g))
  )
  -- The shooter moves and turns between the frame drawn and the command: the
  -- origin and the bodies are the sample's, the aim the command's.
  local reports = volleys(g)
  local commandB = O.command(seenB, g, b)
  b.x, b.yaw = b.x + 1, b.yaw + 0.6
  local fired = g:shoot(commandB, 'knight2')
  local hit = reports[1] and reports[1].contacts[1]
  check(
    'B hits the head of the demon he sees from his side, from the eye of his sample',
    fired
      and hit
      and hit.targetId == e.id
      and hit.zone == 'head'
      and reports[1].actor == 'knight2'
      and reports[1].origin[1] == bx
      and e.hp < 5000
  )

  -- The order the views are drawn in changes no hit.
  local function ordered(firstB)
    local s, target = arena()
    local sa, sb = s.player, join(s)
    aim(s, sa, target, 'torso')
    aim(s, sb, target, 'head')
    local oa, ob
    if firstB then
      ob = O.capture(s, s, sb)
      oa = O.capture(s, s, sa)
    else
      oa = O.capture(s, s, sa)
      ob = O.capture(s, s, sb)
    end
    s:shoot(O.command(oa, s, sa))
    s:shoot(O.command(ob, s, sb), 'knight2')
    return Integrity.capture(s), target.hp
  end
  local stateAB, hpAB = ordered(false)
  local stateBA, hpBA = ordered(true)
  check(
    'drawing B before A changes no hit',
    hpAB < 5000 and hpAB == hpBA and not Integrity.difference(stateAB, stateBA)
  )

  -- A buffered press older than maxAge is refused without ammunition; a held
  -- trigger takes the shooter's newest observation.
  local stale, staleTarget = arena()
  local sb = join(stale)
  aim(stale, sb, staleTarget, 'head')
  local old = O.command(O.capture(stale, stale, sb), stale, sb)
  for _ = 1, math.ceil(O.maxAge / step) + 2 do
    stale:update(step, {})
  end
  local staleMag = Weapons.state(stale, nil, sb).mag
  Intent.queue(stale, 'fire', old, sb)
  stale:update(step, {})
  check(
    "B's buffered press past maxAge is refused without spending ammunition",
    sb.shots == 0 and Weapons.state(stale, nil, sb).mag == staleMag and staleTarget.hp == 5000
  )
  local held, moved = arena()
  local hb = join(held)
  aim(held, hb, moved, 'torso')
  hb.cooldown = 0.04
  local first = O.command(O.capture(held, held, hb), held, hb)
  held:update(step, { actors = { knight2 = { shoot = true, fireCommand = first } } })
  moved.x = moved.x + 2
  for _ = 1, 8 do
    local newest = O.command(O.capture(held, held, hb), held, hb)
    held:update(step, { actors = { knight2 = { shoot = true, fireCommand = newest } } })
  end
  check(
    "B's held trigger fires on his newest observation (the moved demon is not hit where it was)",
    hb.shots == 1 and moved.hp == 5000
  )

  -- Missiles: the owner's eye while he stands; the point fired from once he
  -- has fallen or left. Each variant recorded and replayed from its journal.
  local function missile(variant)
    local s, target = arena(variant == 'dead' and function(scene)
      require('src.enemies.hazards').add(scene, spots.B[1], spots.B[2], 0, 1.2, 3, {
        packet = { base = 20, impact = 0, damageType = 'poison' },
        pulse = 0.3,
        side = 'demons',
      })
    end)
    local journal = Journal.record(s)
    local eye = { x = spots.B[1], z = spots.B[2], jump = 0 }
    local yaw, pitch = aimAt(s, eye, target, 'torso')
    local owner =
      join(s, { weapon = 3, yaw = yaw, pitch = pitch, hp = variant == 'dead' and 1 or 100 })
    local seen = {}
    local observer = Projectiles.observer
    Projectiles.observer = function(...)
      local who = observer(...)
      seen[#seen + 1] = who
      return who
    end
    local ok, problem = pcall(function()
      assert(s:shoot(nil, 'knight2'), 'the missile is fired')
      if variant == 'removed' then
        assert(s:actorLeave('knight2'))
      end
      for _ = 1, 120 do
        s:update(step, {})
      end
    end)
    Projectiles.observer = observer
    Journal.stop(s)
    assert(ok, problem)
    local replay = arena(variant == 'dead' and function(scene)
      require('src.enemies.hazards').add(scene, spots.B[1], spots.B[2], 0, 1.2, 3, {
        packet = { base = 20, impact = 0, damageType = 'poison' },
        pulse = 0.3,
        side = 'demons',
      })
    end)
    local replayed = pcall(Journal.replay, replay, Journal.decode(Journal.encode(journal)))
    return seen,
      owner,
      target,
      replayed and not Integrity.difference(Integrity.capture(s), Integrity.capture(replay))
  end
  local function points(seen, owner)
    local mine, fixed = 0, 0
    for _, who in ipairs(seen) do
      if who == owner then
        mine = mine + 1
      elseif who and who.x == spots.B[1] and who.z == spots.B[2] and not who.id then
        fixed = fixed + 1
      end
    end
    return mine, fixed
  end
  local ok, problem = pcall(function()
    local seen, owner, target, replays = missile('alive')
    local mine, fixed = points(seen, owner)
    check(
      "a standing owner's missile sees its targets from his eye",
      mine > 0 and fixed == 0 and target.hp < 5000 and owner.hp > 0
    )
    check('the standing-owner variant replays from its journal', replays)
    seen, owner, target, replays = missile('dead')
    mine, fixed = points(seen, owner)
    check(
      "a fallen owner's missile sees its targets from the point it was fired from",
      owner.hp <= 0 and fixed > 0 and seen[#seen] ~= owner and target.hp < 5000
    )
    check('the fallen-owner variant replays from its journal', replays)
    seen, owner, target, replays = missile('removed')
    mine, fixed = points(seen, owner)
    check(
      "a departed owner's missile sees its targets from the point it was fired from",
      mine == 0 and fixed > 0 and target.hp < 5000
    )
    check('the departed-owner variant replays from its journal', replays)
  end)
  assert(ok, problem)

  -- Invalidation scopes: an actor's own end ends only his observations.
  local scoped, demon = arena()
  local sa = scoped.player
  local k2 = join(scoped)
  assert(scoped:actorJoin(knight(scoped, 'knight3', 15, 27)))
  assert(scoped:actorJoin(knight(scoped, 'knight4', 13, 27)))
  local k3, k4 = Pools.get(scoped, 'knight3'), Pools.get(scoped, 'knight4')
  local function views()
    return {
      [sa] = O.capture(scoped, scoped, sa),
      [k2] = O.capture(scoped, scoped, k2),
      [k3] = O.capture(scoped, scoped, k3),
      [k4] = O.capture(scoped, scoped, k4),
    }
  end
  local function valid(all, k)
    return O.valid(scoped, all[k], k) and true or false
  end
  local all = views()
  scoped:damageBody(k2, 1000, k2.x + 1, k2.z, { base = 1000, impact = 0 }, demon)
  k4.x, k4.z = k4.x + 2, k4.z - 1
  check(
    "B's death ends his observations only; another's move (a teleport) ends none",
    k2.hp <= 0 and not valid(all, k2) and valid(all, sa) and valid(all, k3) and valid(all, k4)
  )
  all = views()
  assert(scoped:actorControl('knight3'))
  check(
    'a change of control ends the observations of both knights, not of the others',
    not valid(all, sa) and not valid(all, k3) and valid(all, k4)
  )
  all = views()
  assert(scoped:actorLeave('knight4'))
  check(
    "a knight's leave ends his observations only",
    not valid(all, k4) and valid(all, sa) and valid(all, k3)
  )
  all = views()
  O.invalidate(scoped)
  check(
    "the world's generation (a reset, a new map) ends every observation",
    not valid(all, sa) and not valid(all, k3)
  )
  local Field = require('src.run.test_field')
  local field = Field.new(G)
  field.testing = true
  Field.close(field)
  local fieldView = O.capture(field, field)
  Field.reset(field)
  check("the proving ground's reset ends the observations before it", not O.valid(field, fieldView))

  -- An extra camera, drawn and moved every frame, changes neither the state
  -- nor its digest; two views presented each frame step the world once.
  local function play(camera)
    local s, target = arena()
    local pa, pb = s.player, join(s)
    aim(s, pa, target, 'torso')
    aim(s, pb, target, 'head')
    local adapter = Input.new()
    local frames, updates = {}, 0
    local update = s.update
    s.update = function(self, ...)
      updates = updates + 1
      return update(self, ...)
    end
    local viewB = setmetatable({}, { __index = s })
    local unchanged = true
    for i = 1, 90 do
      local still = Integrity.capture(s)
      adapter:present(s, s)
      adapter:present(s, viewB, pb)
      if camera then
        local view = setmetatable({
          viewer = {
            id = 'camera',
            x = 10 + i * 0.1,
            z = 18 + (i % 7),
            yaw = i * 0.05,
            pitch = 0,
            jump = 0,
          },
        }, { __index = s })
        renderer:draw(view, 320, 180)
      end
      unchanged = unchanged and not Integrity.difference(still, Integrity.capture(s))
      local trigger = i % 30 == 0
      s:update(step, {
        shoot = trigger,
        fireCommand = trigger and adapter:command(s) or nil,
        actors = {
          knight2 = { shoot = trigger, fireCommand = trigger and adapter:command(s, pb) or nil },
        },
      })
      frames[#frames + 1] = table.concat(Projection.lines(s), '\n')
    end
    return s, frames, updates, unchanged, adapter
  end
  local plain, plainFrames = play(false)
  local drawn, drawnFrames, updates, unchanged, adapter = play(true)
  local same = #plainFrames == #drawnFrames
  for i = 1, #plainFrames do
    same = same and plainFrames[i] == drawnFrames[i]
  end
  check(
    'an extra camera, drawn and moved, changes neither the projection nor the state',
    same and not Integrity.difference(Integrity.capture(plain), Integrity.capture(drawn))
  )
  check(
    string.format(
      'two views presented each frame: one step of the world per frame, an observation per actor (%d %s %d %d)',
      updates,
      tostring(unchanged),
      drawn.player.shots,
      Pools.get(drawn, 'knight2').shots
    ),
    updates == 90
      and unchanged
      and math.abs(drawn.elapsed - plain.elapsed) < 1e-12
      and adapter.observations.knight1.shooter == 'knight1'
      and adapter.observations.knight2.shooter == 'knight2'
      and adapter:command(drawn, Pools.get(drawn, 'knight2')).observation.shooter == 'knight2'
      and drawn.player.shots >= 2
      and Pools.get(drawn, 'knight2').shots == drawn.player.shots
  )

  -- The two-actor trial on painted demons: both fire on their own views, B
  -- into the head of the demon as he sees it; the journal replays bit for bit.
  local recorded, painted = arena()
  local journal = Journal.record(recorded)
  local ra, rb = recorded.player, join(recorded)
  turn(recorded, ra, painted, 'torso')
  turn(recorded, rb, painted, 'head')
  local trialReports = volleys(recorded)
  local frames = {}
  for i = 1, 150 do
    local trigger = i % 25 == 0
    local input = { forward = 0, actors = { knight2 = {} } }
    if trigger then
      -- Each aims anew at the demon as he sees it (a wound changes its pose).
      turn(recorded, ra, painted, 'torso')
      turn(recorded, rb, painted, 'head')
      input.shoot = true
      input.fireCommand = O.command(O.capture(recorded, recorded, ra), recorded, ra)
      input.actors.knight2 = {
        shoot = true,
        fireCommand = O.command(O.capture(recorded, recorded, rb), recorded, rb),
      }
    end
    recorded:update(step, input)
    frames[#frames + 1] = table.concat(Projection.lines(recorded), '\n')
  end
  Journal.stop(recorded)
  local heads, bodies = 0, 0
  for _, report in ipairs(trialReports) do
    local contact = report.contacts[1]
    if contact and contact.targetId == painted.id then
      if report.actor == 'knight2' and contact.zone == 'head' then
        heads = heads + 1
      elseif report.actor == 'knight1' then
        bodies = bodies + 1
      end
    end
  end
  check(
    string.format('two actors fire on their own views of a painted demon (%d %d)', heads, bodies),
    heads == rb.shots and heads >= 3 and bodies == ra.shots and bodies >= 3
  )
  local decoded = Journal.decode(Journal.encode(journal))
  local replay = arena()
  local replayed = {}
  local update = replay.update
  replay.update = function(self, ...)
    update(self, ...)
    replayed[#replayed + 1] = table.concat(Projection.lines(self), '\n')
  end
  local replayOk, replayProblem = pcall(Journal.replay, replay, decoded)
  same = replayOk and #replayed == #frames
  for i = 1, #frames do
    same = same and replayed[i] == frames[i]
  end
  check(
    'the painted trial replays bit for bit, step by step (' .. tostring(replayProblem) .. ')',
    same and not Integrity.difference(Integrity.capture(recorded), Integrity.capture(replay))
  )
  Weapons.registry:unregister(bolt.id)
  Snapshot.invalidateDefinitions()
  return lines
end
return Tests
