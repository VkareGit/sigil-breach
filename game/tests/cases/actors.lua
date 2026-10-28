-- Independent actors (plan v11 E3). Every knight of the pool moves, fires,
-- reloads and holds its trigger on its own input, through commands that
-- name it; journal v5 records the ids and builds the same pool on replay
-- (actorJoin, actorLeave, actorControl); a shot's pattern and seeds follow
-- its shooter's own sequence. The targets are posts of explicit volumes (one
-- centred cylinder): what they show does not depend on the viewer (plan v11
-- E4 makes painted bodies so).
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G)
  local lines = {}
  local check = Fixtures.checker(lines, 'actors: ', 'actors: ')
  local Pools = require('src.session.world')
  local Journal = require('src.session.journal')
  local Integrity = require('src.session.integrity')
  local Projection = require('qa.state_projection')
  local Weapons = require('src.content.weapons')
  local Abilities = require('src.content.abilities')
  local Creature = require('src.content.defs.creature')
  local A = require('src.content.enemies')
  local profiles = require('src.enemies.hit_volumes').profiles
  profiles['trial-post'] = {
    shapes = { { id = 'body', zone = 'torso', x = 0.5, bottom = 0, top = 0.9, radius = 0.35 } },
  }
  Fixtures.words({ trial_post = 'Trial Post' })
  A.trial_post = Creature.define({
    extends = A.imp,
    id = 'trial_post',
    kind = 'imp',
    variant = 'trial_post',
    name = 'trial_post',
    appearance = { hit = 'volumes', anatomy = 'trial-post' },
  })
  -- A knight as a member record (the pools section's format).
  local function knight(g, id, x, z, fields)
    local loadout = { 'exorcist', 'judge' }
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
    }, false)
    for key, value in pairs(fields or {}) do
      k[key] = value
    end
    return Pools.memberRecord(k)
  end
  -- The session of the trials: the classic arena without its garrison, two
  -- posts, an awake thrall by the second knight's place.
  local function arena(thrall)
    local g = G.new('classic')
    g.testing = true
    g:start()
    Pools.clear(g, 'enemies')
    Pools.clear(g, 'pickups')
    g.player.x, g.player.z, g.player.yaw = 14, 25, math.pi
    for _, spot in ipairs({ { 14, 21 }, { 18, 21 } }) do
      local post = g:spawn('trial_post', spot[1], spot[2])
      post.dummy, post.spawnAge, post.hp, post.maxHp = true, 1, 5000, 5000
    end
    if thrall then
      local e = g:spawn('imp', 19, 27)
      -- This sequence tests commands before B's planned death. Keep its
      -- historical attacker; live balance has separate creature-pressure fights.
      local Rules = require('src.combat.rules')
      Rules.equip(e, require('tests.support.content.imp_pre_pressure'))
      Rules.applyTier(e, e.tier)
      e.awake, e.memory, e.spawnAge = true, 60, 1
    end
    return g
  end
  local function capture(g)
    return Integrity.capture(g)
  end

  -- Negative commands: an unknown id, a dead knight, another knight's slot.
  local s = arena()
  assert(s:actorJoin(knight(s, 'knight2', 18, 25)))
  local before = capture(s)
  check(
    'a command for an id that names no knight is refused without effect',
    s:shoot(nil, 'ghost') == false
      and s:switchWeapon(2, 'ghost') == false
      and s:reloadGun('ghost') == false
      and s:look(1, 0, 'ghost') == false
      and s:cast(1, 'ghost') == false
      and not Integrity.difference(before, capture(s))
  )
  assert(s:actorJoin(knight(s, 'knight3', 16, 26, { hp = 0 })))
  before = capture(s)
  check(
    'a dead knight takes commands without effect',
    s:shoot(nil, 'knight3') == false
      and s:switchWeapon(2, 'knight3') == false
      and s:dash(1, 0, 'knight3') == false
      and not Integrity.difference(before, capture(s))
  )
  s:switchWeapon(2)
  check(
    "one knight's weapon change leaves another's slot",
    s.player.weapon == 2 and Pools.get(s, 'knight2').weapon == 1
  )
  check(
    'a joining id already used, or a record that is not a knight, is refused',
    not s:actorJoin(knight(s, 'knight2', 1, 1)) and not s:actorJoin({ id = 'knight9', bogus = 1 })
  )

  -- Two actors through a whole sequence, recorded and replayed; the
  -- projection of both is compared after every step.
  local function trial(g, frames)
    local function tick(input)
      g:update(1 / 120, input or {})
      frames[#frames + 1] = table.concat(Projection.lines(g), '\n')
    end
    local walkB = { actors = { knight2 = { forward = 0.4 } } }
    -- A empties the shotgun (the reload starts); B fires its revolver; both walk.
    tick({ shoot = true, forward = 0.3, actors = { knight2 = { shoot = true, forward = 0.4 } } })
    for i = 1, 90 do
      local b = { forward = 0.4, shoot = i % 30 == 0 }
      tick({ forward = 0.2, actors = { knight2 = b } })
    end
    local reloaded = g.player.reload > 0 or g.player.arsenal.exorcist.mag == 2
    -- A: the revolver, a shot, a reload stopped by the trigger.
    for _ = 1, 150 do
      tick(walkB)
    end
    g:switchWeapon(2)
    for _ = 1, 40 do
      tick(walkB)
    end
    tick({ shoot = true, actors = walkB.actors })
    for _ = 1, 120 do
      tick(walkB)
    end
    g:reloadGun()
    tick(walkB)
    local reloading = g.player.reload > 0
    tick({ shoot = true, actors = walkB.actors })
    local interrupted = reloading and g.player.reload == 0
    -- B changes weapon, then stands until the thrall fells him.
    g:switchWeapon(1, 'knight2')
    local changed = Pools.get(g, 'knight2').weapon == 1
    for _ = 1, 120 * 12 do
      if Pools.get(g, 'knight2').hp <= 0 then
        break
      end
      tick()
    end
    local fallen = Pools.get(g, 'knight2').hp <= 0
    local idle = g:shoot(nil, 'knight2') == false
    for _ = 1, 30 do
      tick()
    end
    return reloaded, interrupted, changed, fallen, idle
  end
  local recorded = arena(true)
  local fell = 0
  recorded.bus:on('sim', 'KnightFell', function()
    fell = fell + 1
  end)
  local journal = Journal.record(recorded)
  recorded:actorJoin(knight(recorded, 'knight2', 18, 25, { weapon = 2, hp = 1 }))
  local frames = {}
  local reloaded, interrupted, changed, fallen, idle = trial(recorded, frames)
  Journal.stop(recorded)
  check(
    string.format(
      'two actors: A reloads, B fires and walks, A stops a reload with the trigger, B changes weapon and falls (%s %s %s %s %s %d)',
      tostring(reloaded),
      tostring(interrupted),
      tostring(changed),
      tostring(fallen),
      tostring(idle),
      fell
    ),
    reloaded and interrupted and changed and fallen and idle and fell == 1
  )
  local shotsA, shotsB = recorded.player.shots, Pools.get(recorded, 'knight2').shots
  check('both actors fired their own shots', shotsA >= 2 and shotsB >= 2)
  local decoded = Journal.decode(Journal.encode(journal))
  local replay = arena(true)
  local replayed = {}
  local update = replay.update
  replay.update = function(self, ...)
    update(self, ...)
    replayed[#replayed + 1] = table.concat(Projection.lines(self), '\n')
  end
  local ok, problem = pcall(Journal.replay, replay, decoded)
  local same = ok and #replayed == #frames
  for i = 1, #frames do
    same = same and replayed[i] == frames[i]
  end
  check(
    'journal v5 replays both actors bit for bit, step by step ('
      .. (ok and 'ok' or tostring(problem))
      .. ')',
    same and decoded.header.version == 5 and decoded.header.actors[1] == 'knight1'
  )

  -- The actor journal: a second knight with its own place and equipment
  -- joins before the first update; a fresh session from the journal alone.
  local g = G.new('classic')
  g.testing = true
  local actorJournal = Journal.record(g)
  g:actorJoin(knight(g, 'knight2', 18, 26, {
    armor = 10,
    weapon = 2,
    loadout = { 'judge' },
    arsenal = Weapons.arsenal({ 'judge' }),
  }))
  g:start()
  for i = 1, 60 do
    g:update(1 / 120, { forward = 0.3, actors = { knight2 = { strafe = 0.5, shoot = i == 30 } } })
  end
  -- Joining, control and leaving during the recording.
  g:actorJoin(knight(g, 'knight3', 15, 27))
  for _ = 1, 20 do
    g:update(1 / 120, { actors = { knight2 = { forward = 0.2 }, knight3 = { strafe = -0.4 } } })
  end
  local controlled = g:actorControl('knight3')
  for _ = 1, 20 do
    g:update(1 / 120, { forward = 0.5, actors = { knight1 = { strafe = 0.3 } } })
  end
  local left = g:actorLeave('knight2')
  for _ = 1, 20 do
    g:update(1 / 120, { forward = 0.5 })
  end
  Journal.stop(g)
  local text = Journal.encode(actorJournal)
  local read = Journal.decode(text)
  local fresh = Journal.session(G, read)
  fresh.testing = true
  local replayOk, replayProblem = pcall(Journal.replay, fresh, read)
  check(
    'an actor journal replays in a fresh session from the journal alone ('
      .. tostring(replayProblem)
      .. ')',
    replayOk
      and controlled
      and left
      and fresh.player.id == 'knight3'
      and Pools.get(fresh, 'knight2') == nil
      and Pools.get(fresh, 'knight1') ~= nil
      and not Integrity.difference(Integrity.capture(g), Integrity.capture(fresh))
  )
  -- Preflight refusals: nothing of the session changes.
  local function refused(label, edit)
    local bad = Journal.decode(text)
    edit(bad.entries)
    local target = Journal.session(G, bad)
    target.testing = true
    local untouched = Integrity.capture(target)
    local accepted = pcall(Journal.replay, target, bad)
    check(
      label .. ' is refused before the session changes',
      not accepted and not Integrity.difference(untouched, Integrity.capture(target))
    )
  end
  local function find(entries, name, id)
    for i, entry in ipairs(entries) do
      if entry[1] == name and (id == nil or entry[2][1] == id) then
        return i, entry
      end
    end
  end
  refused('a command for a knight before his actorJoin', function(entries)
    local _, join = find(entries, 'actorJoin')
    table.insert(entries, 1, { 'reloadGun', { 'knight2' } })
    assert(join)
  end)
  refused('a command for a knight after his actorLeave', function(entries)
    entries[#entries + 1] = { 'switchWeapon', { 1, 'knight2' } }
  end)
  refused('an actorJoin with an id in use', function(entries)
    local _, join = find(entries, 'actorJoin')
    entries[#entries + 1] = { 'actorJoin', join[2] }
  end)
  refused('an actorJoin with a record that is not a knight', function(entries)
    entries[#entries + 1] = { 'actorJoin', { { id = 'knight7', bogus = true } } }
  end)
  refused('a command for an id never known', function(entries)
    entries[#entries + 1] = { 'shoot', { nil, 'knight8' } }
  end)
  local r = G.new('classic')
  local rj = Journal.record(r)
  local result = r:shoot(nil, 'nobody')
  Journal.stop(r)
  local shootEntries = 0
  for _, entry in ipairs(rj.entries) do
    shootEntries = shootEntries + (entry[1] == 'shoot' and 1 or 0)
  end
  check(
    'the recorder refuses a command for an absent knight instead of recording it',
    result == false and shootEntries == 0
  )
  -- The shot sequence: B's shots between A's change neither the pattern
  -- nor the seeds of A's next shots.
  local function shots(withB)
    local q = arena()
    q:actorJoin(knight(q, 'knight2', 18, 25))
    local rays = {}
    q.bus:on('sim', 'VolleyResolved', function(event)
      if event.report.actor == 'knight1' then
        for _, ray in ipairs(event.report.rays) do
          rays[#rays + 1] = string.format('%d %.12g %.12g', ray.seed, ray.ox, ray.oy)
        end
      end
    end)
    for n = 1, 3 do
      q.player.cooldown, q.player.arsenal.exorcist.readyAt = 0, 0
      q.player.arsenal.exorcist.mag = 2
      q:shoot()
      if withB then
        for _ = 1, 2 do
          local b = Pools.get(q, 'knight2')
          b.cooldown, b.arsenal.exorcist.readyAt, b.arsenal.exorcist.mag = 0, 0, 2
          q:shoot(nil, 'knight2')
        end
      end
      q:update(1 / 120, {})
      assert(n)
    end
    return table.concat(rays, '|'), q
  end
  local alone = shots(false)
  local shared, q = shots(true)
  check(
    "another actor's shots do not change one actor's pellet pattern or seeds",
    alone == shared and #alone > 0 and q.player.shotSequence == 3
  )
  local SessionSave = require('src.storage.session_save')
  local restored = G.new('classic')
  restored.testing = true
  SessionSave.restore(restored, assert(SessionSave.decode(SessionSave.encode(q, 3))))
  local againB = Pools.get(restored, 'knight2')
  require('src.player.feel').init(restored)
  check(
    'shot sequences survive a save and a load; a reset starts the actor again',
    againB and againB.shotSequence == 6 and restored.player.shotSequence == 0
  )
  A.trial_post = nil
  profiles['trial-post'] = nil
  return lines
end
return Tests
