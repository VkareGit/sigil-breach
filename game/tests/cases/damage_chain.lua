-- The damage chain (plan v11 E3d): every blow carries its owner (the body
-- whose action began it) through charges, effects, shoves and collisions.
-- The kill, its score, the break-kill healing and the mode's reward belong
-- to the owner, never merely to the controlled knight; a fallen or departed
-- owner keeps his kill and reward and heals no one. Every variant is
-- recorded and replayed (the trial mode builds the scene in its init, so a
-- journal rebuilds it by itself).
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G)
  local lines = {}
  local check = Fixtures.checker(lines, 'damage chain: ', 'damage chain: ')
  local Modes = require('src.run.modes')
  local Pools = require('src.session.world')
  local Journal = require('src.session.journal')
  local Integrity = require('src.session.integrity')
  local Stats = require('src.session.stats')
  local Rules = require('src.combat.rules')
  local Weapons = require('src.content.weapons')
  local Abilities = require('src.content.abilities')
  local Snapshot = require('src.session.snapshot')
  local burn = {
    id = 'chain_burn',
    kind = 'periodic',
    duration = 1.2,
    interval = 0.2,
    packet = { base = 6, impact = 0, damageType = 'fire' },
  }
  Weapons.define({
    extends = Weapons.get('judge'),
    id = 'chain_burner',
    fire = { pellets = 1, spread = 0 },
    attack = { base = 1, impact = 0, push = 0, effects = { burn }, pierce = nil },
  })
  Snapshot.invalidateDefinitions()
  local variant = 'charge'
  local modeId = 'chain_probe'
  -- The scene: the controlled knight (B) far behind; one demon, off balance,
  -- with a reward, in front of the place where A will stand.
  Modes:register(modeId, {
    session = { map = require('src.content.maps.index').default },
    init = function(g)
      Modes:get('floor').init(g)
      g.player.x, g.player.z, g.player.yaw = 16, 29, math.pi
      local e = g:spawn('imp', 12, 20.6)
      e.spawnAge, e.rewardSouls = 1, 7
      e.hp = variant == 'burn' and 14 or 4
      e.dummy = variant == 'burn'
      Rules.markBroken(e, 'guard')
      if variant == 'dies' then
        -- A pool under the place where A will stand: it fells him before the blast.
        require('src.enemies.hazards').add(g, 12, 22, 0, 1.2, 3, {
          packet = { base = 20, impact = 0, damageType = 'poison' },
          pulse = 0.3,
          side = 'demons',
        })
      end
    end,
    start = function(g)
      g.state = 'playing'
    end,
    progress = function() end,
    reward = function(g, event)
      local e = event.enemy
      require('src.session.spawn').make(g, 'pickup', {
        kind = 'soul',
        x = e.x,
        z = e.z,
        amount = e.rewardSouls,
        owner = event.owner,
      })
    end,
  })
  local function knight(g, fields)
    local loadout = { 'exorcist', 'judge', 'chain_burner' }
    local k = g.ecs:create('knight', {
      id = 'knight2',
      x = 12,
      z = 22,
      yaw = math.pi,
      pitch = -0.5,
      hp = 40,
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
  -- One variant, recorded; returns the death, the session and the journal.
  local function run(name, fields, actions)
    variant = name
    local g = G.new(modeId)
    g.ephemeral = true
    local journal = Journal.record(g)
    g:actorJoin(knight(g, fields))
    g:start()
    local death
    g.bus:on('sim', 'EnemyKilled', function(event)
      death = {
        owner = event.owner,
        healed = event.healedKnight,
        amount = event.healed,
        reward = event.reward,
      }
    end, 99)
    actions(g)
    for _ = 1, 120 * 4 do
      if death then
        break
      end
      g:update(1 / 120, {})
    end
    for _ = 1, 10 do
      g:update(1 / 120, {})
    end
    Journal.stop(g)
    local soul
    for _, a in ipairs(Pools.of(g, 'pickups')) do
      if a.kind == 'soul' then
        soul = a
      end
    end
    return death or {}, g, journal, soul
  end
  local function replays(g, journal)
    local decoded = Journal.decode(Journal.encode(journal))
    variant = decoded.header.mode == modeId and variant or variant
    local fresh = Journal.session(G, decoded)
    fresh.ephemeral = true
    local ok = pcall(Journal.replay, fresh, decoded)
    return ok and not Integrity.difference(Integrity.capture(g), Integrity.capture(fresh))
  end
  local function throw(g)
    g:cast(1, 'knight2')
    g:switchWeapon(2, 'knight2')
  end
  local ok, problem = pcall(function()
    -- A throws, changes weapon; the charge kills the demon off balance.
    local death, g, journal, soul = run('charge', nil, throw)
    local a = Pools.get(g, 'knight2')
    check(
      string.format(
        "a charge's kill, score, healing and reward are its thrower's, not the controlled knight's (%s %s %s %s %s %s %s %s)",
        tostring(death.owner),
        tostring(death.healed),
        tostring(death.amount),
        tostring(a.hp),
        tostring(Stats.read(g, 'knight2').kills),
        tostring(Stats.read(g, 'knight1').kills),
        tostring(g.player.hp),
        tostring(soul and soul.owner)
      ),
      death.owner == 'knight2'
        and death.healed == 'knight2'
        and death.amount > 0
        and a.hp > 0
        and Stats.read(g, 'knight2').kills == 1
        and Stats.read(g, 'knight2').score == death.reward
        and Stats.read(g, 'knight1').kills == 0
        and g.player.hp == 100
        and soul
        and soul.owner == 'knight2'
    )
    check('the charge variant replays from its journal', replays(g, journal))
    -- A falls before the blast: his kill and reward stay his, nobody is healed.
    death, g, journal, soul = run('dies', { hp = 1 }, throw)
    a = Pools.get(g, 'knight2')
    check(
      'a fallen thrower keeps the kill and the reward; no one is healed',
      a.hp <= 0
        and death.owner == 'knight2'
        and death.healed == nil
        and Stats.read(g, 'knight2').kills == 1
        and soul
        and soul.owner == 'knight2'
        and g.player.hp == 100
    )
    check('the fallen-thrower variant replays from its journal', replays(g, journal))
    -- A leaves before the blast: the same.
    death, g, journal, soul = run('charge', nil, function(s)
      throw(s)
      s:actorLeave('knight2')
    end)
    check(
      'a departed thrower keeps the kill and the reward; no one is healed',
      Pools.get(g, 'knight2') == nil
        and death.owner == 'knight2'
        and death.healed == nil
        and Stats.read(g, 'knight2').kills == 1
        and soul
        and soul.owner == 'knight2'
        and g.player.hp == 100
    )
    check('the departed-thrower variant replays from its journal', replays(g, journal))
    -- A periodic effect from A's shot kills: A's chain.
    death, g, journal = run('burn', nil, function(s)
      s:switchWeapon(3, 'knight2')
      for _ = 1, 40 do
        s:update(1 / 120, {})
      end
      s:look(0, 0.45, 'knight2')
      s:shoot(nil, 'knight2')
    end)
    check(
      "an effect from A's shot kills for A",
      death.owner == 'knight2' and death.healed == 'knight2' and Stats.read(g, 'knight2').kills == 1
    )
    check('the effect variant replays from its journal', replays(g, journal))
  end)
  Modes:unregister(modeId)
  assert(ok, problem)
  -- A shove's owner owns the slam it ends in (unit level: a body thrown at a
  -- wall carries the owner of the blow that threw it).
  local s = G.new('floor')
  s.ephemeral = true
  s:start()
  Pools.clear(s, 'enemies')
  assert(s:actorJoin(knight(s)))
  local world, wallX, wallZ = s.world
  for z = 2, #world.map - 1 do
    for x = 2, #world.map[z] - 1 do
      if
        not wallX
        and world.map[z][x] == 0
        and world.map[z][x - 1] == 0
        and world.map[z][x + 1] == 1
      then
        wallX, wallZ = x, z
      end
    end
  end
  local e = s:spawn('imp', wallX - 0.2, wallZ)
  e.spawnAge, e.hp, e.dummy = 1, 3, true
  Rules.markBroken(e, 'guard')
  e.pushX, e.pushZ, e.pushOwner = 30, 0, 'knight2'
  local slain
  s.bus:on('sim', 'EnemyKilled', function(event)
    slain = event
  end)
  for _ = 1, 30 do
    if slain then
      break
    end
    s:update(1 / 120, {})
  end
  check(
    "a slam ends a shove's chain: its owner's kill",
    slain
      and slain.source == 'slam'
      and slain.owner == 'knight2'
      and Stats.read(s, 'knight2').kills == 1
  )
  Weapons.registry:unregister('chain_burner')
  Snapshot.invalidateDefinitions()
  return lines
end
return Tests
