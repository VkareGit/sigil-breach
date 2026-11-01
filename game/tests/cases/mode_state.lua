-- Mode state and the view contract (plan v11 E2). The guardian belongs to
-- the encounter, the seals and the secret to the world, a mode's private
-- state to its record; views belong to their session and last one step.
-- The trial: an "altars" mode (destroy three altars) through its whole
-- life — start, progress, its own save section and a load from the file,
-- the end, a clean restart, a replayed journal — with its state only in
-- g.modeData, its goal in the HUD's objective and its marks on the map
-- through views: no new session field, no branch in a screen.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, renderer)
  local lines = {}
  local check = Fixtures.checker(lines, 'mode state: ', 'mode state: ')
  local Modes = require('src.run.modes')
  local Queries = require('src.run.queries')
  local Encounter = require('src.session.encounter')
  local World = require('src.world.arena')
  local Fields = require('src.session.fields')
  local Save = require('src.storage.save')
  local Journal = require('src.session.journal')
  local Integrity = require('src.session.integrity')
  local Snapshot = require('src.session.snapshot')

  -- Owners: the guardian through the encounter, the seals counted on the world.
  local g = G.new('floor')
  g.testing = true
  check(
    'the session keeps no guardian, seal, secret or rank field of its own',
    rawget(g, 'bossSpawned') == nil
      and rawget(g, 'seals') == nil
      and Fields.retired.bossDead
      and Fields.retired.secretFound
      and Fields.retired.rank
      and not pcall(function()
        return g.bestScore
      end)
      and not Fields.owner('seals')
      and not Fields.owner('bossDead')
      and Fields.owner('encounter') == 'session/encounter.lua'
  )
  World.breakSeals(g.world, 2)
  Encounter.guardianArrived(g)
  check(
    'seals are the broken seals of the world; the guardian is the encounter record',
    World.activeSeals(g.world) == 2
      and Queries.world(g).guardianSpawned
      and not Queries.world(g).guardianDead
      and Modes.record(g) == g.run
  )

  -- Views: each session its own; the same object within a step; stale after.
  local a, b = G.new('floor'), G.new('floor')
  a.testing, b.testing = true, true
  a:start()
  b:start()
  local runA, worldB = Queries.run(a), Queries.world(b)
  a.run.wallet = 77
  Encounter.guardianFell(b)
  local runA2, worldB2 = Queries.run(a), Queries.world(b)
  check(
    'views of two sessions read in turn keep their own values',
    runA2 == runA
      and worldB2 == worldB
      and runA.wallet == 77
      and worldB.guardianDead
      and Queries.world(a) ~= worldB
      and not Queries.world(a).guardianDead
  )
  local c, d = G.new('floor'), G.new('floor')
  c.testing, d.testing = true, true
  c.run.wallet, d.run.wallet = 11, 22
  local viewC, viewD = Queries.run(c), Queries.run(d)
  check(
    'two expeditions never share a view table',
    viewC ~= viewD and viewC.wallet == 11 and viewD.wallet == 22
  )
  local kept = Queries.copy(viewC)
  check('a view is valid in its step', Queries.valid(c, viewC))
  c.state = 'playing'
  c:update(1 / 120, {})
  check(
    'a view held past the next step is detected as stale (negative)',
    not Queries.valid(c, viewC) and kept.wallet == 11 and Queries.valid(c, Queries.run(c))
  )
  local viewD2 = Queries.run(d)
  d:act('closeShop')
  check('a command makes the earlier view stale', not Queries.valid(d, viewD2))

  -- The altars mode.
  Fixtures.words({
    altars_objective = 'Destroy the altars  {destroyed} / {total}',
    altars_done = 'The altars are ash',
  })
  local id = 'trial_altars'
  -- Where the altars stand: found by a probe walk before the trial (far away
  -- until then), so the knight reaches them by its recorded inputs alone.
  local spots = { { -50, -50 }, { -50, -50 }, { -50, -50 } }
  local function fresh()
    local altars = {}
    for i, s in ipairs(spots) do
      altars[i] = { x = s[1], z = s[2], destroyed = false }
    end
    return { altars = altars, destroyed = 0 }
  end
  local function plain(data)
    local altars = {}
    for i, a in ipairs(data.altars) do
      altars[i] = { x = a.x, z = a.z, destroyed = a.destroyed }
    end
    return { altars = altars, destroyed = data.destroyed }
  end
  local ok, problem = pcall(function()
    Save.declare({
      name = 'altars',
      file = 'altars',
      version = 1,
      pack = function(session)
        return plain(session.modeData)
      end,
      unpack = function(data)
        assert(type(data.destroyed) == 'number' and #data.altars == #spots, 'altars')
        return plain(data)
      end,
      restore = function(session, data)
        session.modeData = plain(data)
      end,
    })
    Modes:register(id, {
      session = { world = id, map = require('src.content.maps.index').default },
      init = function(session)
        session.modeData = fresh()
      end,
      reset = function(session)
        session.modeData = fresh()
      end,
      start = function(session)
        session.state = 'playing'
      end,
      progress = function(session)
        local data = session.modeData
        local p = session.player
        for _, altar in ipairs(data.altars) do
          if not altar.destroyed and (altar.x - p.x) ^ 2 + (altar.z - p.z) ^ 2 < 1.5 ^ 2 then
            altar.destroyed, data.destroyed = true, data.destroyed + 1
          end
        end
        if data.destroyed == #data.altars and session.state == 'playing' then
          session.state = 'won'
        end
      end,
      objective = function(session)
        local data = session.modeData
        return data.destroyed == #data.altars and require('src.content.text').get('altars_done')
          or require('src.content.text').get(
            'altars_objective',
            { destroyed = data.destroyed, total = #data.altars }
          )
      end,
      worldView = function(session, out)
        out.gates, out.paintedPickups, out.classicSecret = {}, false, false
        out.markers = {}
        for i, altar in ipairs(session.modeData.altars) do
          out.markers[i] = { x = altar.x, z = altar.z, done = altar.destroyed }
        end
        return out
      end,
      snapshot = function(session)
        return plain(session.modeData)
      end,
      load = function(session, data)
        session.modeData = plain(data)
        return true
      end,
      save = function(session)
        return Save.encode('altars', Save.capture('altars', session), 1)
      end,
    })
    local WorldObjects = require('src.render.world_objects')
    local drawn = 0
    WorldObjects.register('trial_altar', {
      {
        pass = 'sprites',
        order = 46,
        draw = function(_, _, view)
          for _, m in ipairs(view.markers or {}) do
            drawn = drawn + (m.done and 0 or 1)
          end
        end,
      },
    })
    local ahead, aside = { forward = 1 }, { strafe = 1 }
    local function walk(session, input, steps)
      for _ = 1, steps do
        session:update(1 / 120, input)
      end
      return { session.player.x, session.player.z }
    end
    local probe = G.new(id)
    probe.testing = true
    probe:start()
    spots[1] = walk(probe, {}, 1)
    spots[2] = walk(probe, ahead, 50)
    spots[3] = walk(probe, aside, 50)
    local s = G.new(id)
    s.testing = true
    local journal = Journal.record(s)
    s:start()
    walk(s, {}, 1)
    check(
      'the altars mode starts and advances: one altar down, its goal in the objective',
      s.modeData.destroyed == 1 and Queries.objective(s):find('1 / 3', 1, true) ~= nil
    )
    local marks = Queries.world(s).markers
    check(
      'its marks reach the map through the world view',
      #marks == 3 and marks[1].done and not marks[2].done
    )
    renderer:draw(s, 1280, 720)
    check('its altars are drawn by a registered world object', drawn == 2)
    -- Its own section in its own file, read back into a new session.
    local file = Modes.act(s, 'save')
    local values = assert(Save.decode('altars', file))
    local loaded = G.new(id)
    loaded.testing = true
    Save.restore('altars', loaded, values)
    check(
      'its own save section is written and restored from the file',
      loaded.modeData.destroyed == 1
        and loaded.modeData.altars[1].destroyed
        and not loaded.modeData.altars[2].destroyed
    )
    walk(s, ahead, 50)
    walk(s, aside, 50)
    Journal.stop(s)
    check(
      'it ends when the third altar falls',
      s.state == 'won'
        and s.modeData.destroyed == 3
        and Queries.objective(s) == 'The altars are ash'
    )
    local decoded = Journal.decode(Journal.encode(journal))
    local replay = Journal.session(G, decoded)
    replay.testing = true
    Journal.replay(replay, decoded)
    check(
      'its journal replays to the same end',
      not Integrity.difference(Integrity.capture(s), Integrity.capture(replay))
        and replay.modeData.destroyed == 3
    )
    local snapshot = Snapshot.capture(s)
    Modes.act(s, 'reset')
    check('reset brings it back to a clean start', s.modeData.destroyed == 0)
    Snapshot.restore(s, snapshot)
    local again = G.new(id)
    check(
      'a restart begins from a clean state, the finished one untouched',
      again.modeData.destroyed == 0 and s.modeData.destroyed == 3 and again.modeData ~= s.modeData
    )
    local undeclared = {}
    for key in pairs(s) do
      if not Fields.owner(key) then
        undeclared[#undeclared + 1] = tostring(key)
      end
    end
    check('it adds no session field (' .. table.concat(undeclared, ' ') .. ')', #undeclared == 0)
    WorldObjects.unregister('trial_altar')
  end)
  require('src.render.world_objects').unregister('trial_altar')
  if Modes:has(id) then
    Modes:unregister(id)
  end
  Save.forget('altars')
  assert(ok, problem)
  return lines
end
return Tests
