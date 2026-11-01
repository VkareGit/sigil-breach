local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, renderer)
  local W = require('src.world.arena')
  local Run = require('src.run.descent')
  local Save = require('src.storage.run_save')
  local AI = require('src.enemies.ai')
  local Waves = require('src.content.waves')
  local lines = {}
  local check = Fixtures.checker(lines, '', '')
  local function fresh()
    return Fixtures.expedition(G)
  end
  local function index(w, x, z)
    return math.floor(z + 0.5) * w.size + math.floor(x + 0.5)
  end
  local function active(g)
    g.run.phase = 'wave'
    g.run.pending = {}
    g.run.queueIndex = #Waves[g.run.wave].queue + 1
    g.run.spawnTimer = 1000
    g.run.phaseTime = 0
  end
  local g = fresh()
  local w = g.world
  local classic = W.new('classic')
  local same = true
  local floors = 0
  for z = 1, 31 do
    for x = 1, 31 do
      same = same and w.map[z][x] == classic.map[z][x]
      if w.map[z][x] == 0 then
        floors = floors + 1
      end
    end
  end
  -- 0.14 opened the arena: 470 floor cells became 588 (one transept, wider nave and altar, arch pillars).
  check(
    'descent uses exactly the single open test field',
    w.size == 31 and classic.size == 31 and same and floors == 588 and not w.expanded
  )
  local boundary = true
  for n = 1, w.size do
    boundary = boundary
      and w.map[1][n] > 0
      and w.map[w.size][n] > 0
      and w.map[n][1] > 0
      and w.map[n][w.size] > 0
  end
  check('single test field retains its complete solid boundary', boundary)
  local flow = W.flow(w, g.player.x, g.player.z)
  local connected, clearance = true, true
  for z = 1, w.size do
    for x = 1, w.size do
      if w.map[z][x] == 0 then
        connected = connected and flow[index(w, x, z)] ~= nil
        clearance = clearance and not W.solid(w, x, z, 0.25)
      end
    end
  end
  check('every test-field floor is reachable with actor clearance', connected and clearance)
  local excluded = true
  for _, p in ipairs({ { 7, 28 }, { 31, 26 }, { 21, 34 }, { 6, 5.2 }, { 6, 8 } }) do
    excluded = excluded and W.solid(w, p[1], p[2], 0.22)
  end
  check(
    'deferred wings gallery and secret are absent from active collision',
    excluded and not w.secretDoor and not w.secretOpening
  )
  g.player.x = 3.7
  g.player.z = 20.4
  local money = g.run.wallet
  local interacted = g:interact()
  check(
    'the test field cannot activate the deferred secret reward',
    not interacted and g.run.wallet == money and g:context() == nil
  )
  local legal = true
  for _, p in ipairs(w.gates) do
    legal = legal and not W.solid(w, p.x, p.z, 0.25) and flow[index(w, p.x, p.z)] ~= nil
  end
  check('all six active wave portals occupy reachable original floor', #w.gates == 6 and legal)
  local spawnable = true
  for z = 1, w.size do
    for x = 1, w.size do
      if w.map[z][x] == 0 then
        local from = W.flow(w, x, z)
        local found = false
        for _, p in ipairs(w.gates) do
          local d = from[index(w, p.x, p.z)]
          if d and d >= 8 and (p.x - x) ^ 2 + (p.z - z) ^ 2 >= 36 then
            found = true
            break
          end
        end
        spawnable = spawnable and found
      end
    end
  end
  check('every original floor tile has a distant reachable wave portal', spawnable)
  for wave = 1, 4 do
    g = fresh()
    g.run.wave = wave
    local started = Run.ready(g)
    local ammo, health = 0, 0
    legal = true
    for _, a in ipairs(g.pickups) do
      if a.kind == 'ammo' then
        ammo = ammo + a.amount
      elseif a.kind == 'health' then
        health = health + a.amount
      end
      legal = legal
        and not W.solid(g.world, a.x, a.z, 0.22)
        and flow[index(g.world, a.x, a.z)] ~= nil
    end
    check(
      'wave ' .. wave .. ' keeps the fixed four-shell and twenty-health budget on reachable floor',
      started and #g.pickups == 3 and ammo == 4 and health == 20 and legal
    )
    local before = #g.pickups
    check(
      'repeated readiness cannot duplicate wave ' .. wave .. ' supplies',
      not Run.ready(g) and #g.pickups == before
    )
  end
  g = fresh()
  g.run.wave = 5
  g.pickups = { { kind = 'health', amount = 100, x = 16, z = 27 } }
  check(
    'boss trial clears old crates and grants no extra wave supplies',
    Run.ready(g) and #g.pickups == 0
  )
  for i, p in ipairs({ { 16, 27.5 }, { 7, 17 }, { 25, 17 }, { 16, 5.5 } }) do
    g = fresh()
    g.player.x = p[1]
    g.player.z = p[2]
    Run.ready(g)
    Run.update(g, 3.1)
    local pending = g.run.pending[1]
    local d = pending and math.sqrt((pending.x - p[1]) ^ 2 + (pending.z - p[2]) ^ 2) or 0
    local frontal = pending
      and (
            (pending.x - p[1]) * math.sin(g.player.yaw)
            + (pending.z - p[2]) * math.cos(g.player.yaw)
          )
          / math.max(0.01, d)
        > 0.25
    local ok = pending
      and d >= 4.2
      and (d >= 6 or (frontal and W.visible(g.world, p[1], p[2], pending.x, pending.z)))
      and not W.solid(g.world, pending.x, pending.z, 0.25)
    Run.update(g, 1.21)
    local enemy = g.enemies[1]
    check(
      'wave warning and spawn remain on legal distant floor from test position ' .. i,
      ok and enemy and not W.solid(g.world, enemy.x, enemy.z, 0.25)
    )
  end
  g = fresh()
  local yaw = math.atan2(g.world.ember.x - g.player.x, g.world.ember.z - g.player.z)
  check(
    'new runs still face the visible improved shrine',
    math.abs(g.player.yaw - yaw) < 0.00001
      and W.visible(g.world, g.player.x, g.player.z, g.world.ember.x, g.world.ember.z)
  )
  W.rebuild(g.world)
  local separated = true
  for _, lamp in ipairs(g.world.lamps) do
    separated = separated and (lamp.x - g.world.ember.x) ^ 2 + (lamp.z - g.world.ember.z) ^ 2 >= 4
  end
  check('rebuilding original geometry does not restore the overlapping shrine torch', separated)
  check('merchant still opens at the original shrine', Run.openShop(g))
  Run.closeShop(g)
  g.player.x = 20.66
  g.player.z = 25.22 -- behind the round pillar (0.14)
  check('original pillar still blocks shop interaction through stone', not Run.openShop(g))
  local legacy = [[SIGIL06
1
3698670484
phase=preparing
wave=1
wallet=100
glyph=none
owned=0,0
claimed=
inventory=40,2,28,40,1
checkpoint=40,2,28,40,1
echo=none
elapsed=0
kills=0
damage=0
deaths=0
secret=0
score=0
fragment=0]]
  local decoded = Save.decode(legacy)
  check(
    'v0.6 and v0.7 saves without the expansion field still decode',
    decoded and decoded.wallet == 100 and not decoded.secretOpen
  )
  g = fresh()
  Run.load(g, decoded)
  check(
    'legacy preparation restores the original playable field',
    g.state == 'playing' and g.world.size == 31 and g.player.hp == 100 and g.run.wallet == 100
  )
  local valid = Run.snapshot(fresh())
  valid.phase = 'defeated'
  valid.wallet = 0
  valid.echo = { amount = 144, x = 15, z = 20.2, wave = 1 }
  g = fresh()
  Run.load(g, assert(Save.decode(Save.encode(valid, 2))))
  check(
    'a valid original-arena echo preserves its exact coordinates',
    g.run.echo.x == 15 and g.run.echo.z == 20.2 and g.run.echo.amount == 144 and g.run.wallet == 0
  )
  for i, p in ipairs({
    { 35, 27 },
    { 21, 34 },
    { 6, 5.2 },
    { 7, 28 },
    { 31, 26 },
    { 38, 38 },
    {
      12,
      25,
    },
  }) do
    local data = Run.snapshot(fresh())
    data.phase = 'defeated'
    data.wallet = 0
    data.echo = { amount = 117, x = p[1], z = p[2], wave = 1 }
    data.secret = true
    data.secretOpen = true
    data.score = 500
    data.claimed['1_1'] = true
    decoded = assert(Save.decode(Save.encode(data, 10 + i)))
    g = fresh()
    Run.load(g, decoded)
    local echo = g.run.echo
    local accessible = W.flow(g.world, 16, 27.5)[index(g.world, echo.x, echo.z)] ~= nil
    check(
      'unreachable legacy echo ' .. i .. ' is relocated without losing or crediting souls',
      echo.amount == 117
        and echo.wave == 1
        and echo.x == 16
        and echo.z == 26
        and accessible
        and not W.solid(g.world, echo.x, echo.z, 0.22)
        and g.run.wallet == 0
    )
    check(
      'legacy discovery ' .. i .. ' remains metadata without reopening deferred geometry',
      g.world.secretFound
        and require('src.session.stats').total(g, 'score') == 500
        and g.run.claimed['1_1']
        and Run.snapshot(g).secretOpen
        and not g.world.secretOpen
        and not g.world.expanded
        and decoded.echo.x == p[1]
        and decoded.echo.z == p[2]
    )
  end
  Run.retry(g)
  Run.update(g, 0.01)
  check(
    'relocated echo still waits until the retry starts',
    g.run.echo.amount == 117 and g.run.wallet == 0
  )
  local saved = assert(Save.decode(Save.encode(Run.snapshot(g), 30)))
  local loaded = fresh()
  Run.load(loaded, saved)
  check(
    'relocated echo is stable across another save and load',
    loaded.run.echo.x == 16
      and loaded.run.echo.z == 26
      and loaded.run.echo.amount == 117
      and loaded.run.wallet == 0
  )
  active(loaded)
  loaded:spawn('imp', 7, 17)
  loaded.player.x = 16
  loaded.player.z = 26
  Run.update(loaded, 0.01)
  Run.update(loaded, 0.01)
  check(
    'relocated souls can be recovered once during combat',
    loaded.run.wallet == 117 and not loaded.run.echo
  )
  -- Real AI movement verifies the field remains useful for enemy and boss iteration.
  for i, route in ipairs({
    { 7, 17, 25, 17 },
    { 25, 17, 7, 17 },
    { 16, 5.5, 16, 27.5 },
    { 16, 27.5, 16, 5.5 },
    { 7, 13, 25, 20 },
    { 25, 20, 7, 13 },
  }) do
    g = fresh()
    g.player.x = route[3]
    g.player.z = route[4]
    g.player.invuln = 1000
    g.nextAttack = 1e9
    active(g)
    local e = g:spawn('imp', route[1], route[2])
    e.awake = true
    e.memory = 60
    e.spawnAge = 1
    local arrived = false
    for frame = 1, 1000 do
      g.elapsed = frame * 0.05
      Run.update(g, 0.05)
      AI.update(g, 0.05)
      if (e.x - g.player.x) ^ 2 + (e.z - g.player.z) ^ 2 < 2.25 then
        arrived = true
        break
      end
    end
    check('demon reaches its target through actual original-field collision route ' .. i, arrived)
  end
  love.mouse.setRelativeMode(false)
  return lines
end
return Tests
