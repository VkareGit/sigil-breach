-- Core cost measurements (0.29): the same workloads before and after a change,
-- each measured separately — never one number multiplied up. CPU wall time
-- from love.timer, Lua heap from collectgarbage('count'). Not an FPS estimate.
--   masks         parsing and building the baked mask data (a fresh chunk)
--   surface       preparing poses/surfaces and full 20-ray volleys
--   missiles      knight missiles swept against the selected population
--   melee         a thrall's lunges and claws against the knight
--   snapshot      Snapshot.capture / restore of the selected field
--   step          whole simulation steps with the population awake
--   corpses       steps with the population killed and kept in place
--   journal       recording, exporting and replaying a field fight
--   long session  300 waves of three demons spawned, killed and cleared
local Tooling = require('qa.tooling')
local M = {}
local clock = love.timer.getTime
local function heap()
  collectgarbage('collect')
  collectgarbage('collect')
  return collectgarbage('count')
end
-- Allocation of fn over n calls with the collector stopped (KiB per call).
local function allocation(n, fn)
  collectgarbage('collect')
  collectgarbage('stop')
  local before = collectgarbage('count')
  for i = 1, n do
    fn(i)
  end
  local after = collectgarbage('count')
  collectgarbage('restart')
  return (after - before) / n
end
local function timed(n, fn)
  local start = clock()
  for i = 1, n do
    fn(i)
  end
  return (clock() - start) / n * 1000
end
-- Per-call times (ms) of fn over n calls: median and 95th percentile.
local function spread(n, fn)
  local times = {}
  for i = 1, n do
    local start = clock()
    fn(i)
    times[i] = (clock() - start) * 1000
  end
  table.sort(times)
  return times[math.ceil(n / 2)], times[math.ceil(n * 0.95)]
end
local function field(G, count, kind)
  if (count > 20 or Tooling.crowdMap()) and not kind then
    return Tooling.crowd(G, count)
  end
  local Field = require('src.run.test_field')
  local g = Field.new(G)
  g.testing = true
  local kinds = { 'imp', 'armored', 'stolas', 'buer', 'boss', 'furfur' }
  for i = 1, count do
    local k = kind or kinds[(i - 1) % #kinds + 1]
    local angle = count == 1 and 0 or -1.2 + 2.4 * (i - 1) / (count - 1)
    local d = 6 + (i % 3) * 2
    local e = g:spawn(
      k,
      g.player.x + math.sin(g.player.yaw + angle) * d,
      g.player.z + math.cos(g.player.yaw + angle) * d
    )
    e.spawnAge, e.awake = 1, true
  end
  Field.close(g)
  return g
end
function M.run(G, output, smoke)
  local function n(full, short)
    return Tooling.count(smoke, full, short)
  end
  local lines = Tooling.header('CORE COST MEASUREMENTS', smoke)
  local populations = Tooling.populations(os.getenv('SIGIL_CORE_POPULATION'), { 20 })
  assert(
    #populations == 1 and populations[1] >= 20,
    'core population must be one integer from 20 to 512'
  )
  local population, journalPopulation = populations[1], smoke and 3 or populations[1]
  lines[#lines + 1] = 'Population: '
    .. population
    .. '; populations above 20 use a prepared free-tile factory grid outside the player catalogue. The 20 rays and 10 missiles remain fixed.'
  lines[#lines + 1] = 'Map: '
    .. (Tooling.crowdMap() or 'limbo (the arena)')
    .. (Tooling.crowdMap() and '; every population uses the crowd factory grid' or '')
  lines[#lines + 1] = 'LuaJIT ' .. tostring(jit and jit.version)
  lines[#lines + 1] =
    'Prepared CPU workloads; no renderer or desktop input polling. Timing is diagnostic, never a machine-specific pass threshold.'
  local function log(text)
    lines[#lines + 1] = text
    print(text)
  end
  -- Masks: a fresh chunk of the baked data (not the cached module).
  local path = 'src/content/art/hit_masks.lua'
  local size = love.filesystem.getInfo(path).size
  local before = heap()
  local start = clock()
  local chunk = assert(love.filesystem.load(path))
  local parsed = clock()
  local data = chunk()
  local built = clock()
  -- The compiled chunk (its stored text) is released, as after a require.
  chunk = nil
  local resident = heap() - before
  local frames = 0
  for _, group in pairs({ data.layouts, data.abilities }) do
    for _, list in pairs(group) do
      frames = frames + #list
    end
  end
  log(
    string.format(
      'masks: file %.0f KiB, %d frames; parse %.1f ms, build %.1f ms, resident %.0f KiB',
      size / 1024,
      frames,
      (parsed - start) * 1000,
      (built - parsed) * 1000,
      resident
    )
  )
  data = nil
  -- Surface preparation and full volleys (20 rays) against 20 demons.
  local B = require('src.combat.ballistics')
  local g = field(G, population)
  local ox, oy, oz = B.origin(g)
  local rays = {}
  for i = 1, 20 do
    local e = g.enemies[1 + math.floor((i - 1) * population / 20)]
    local dx, dy, dz = e.x - ox, 1.2 - oy, e.z - oz
    local l = math.sqrt(dx * dx + dy * dy + dz * dz)
    rays[i] = { dx / l, dy / l, dz / l }
  end
  for _ = 1, n(50, 2) do
    B.prepare(g)
  end
  log(
    string.format(
      'surface: prepare %d bodies %.4f ms (%.2f KiB), volley prepare + 20 rays %.4f ms (%.2f KiB)',
      population,
      timed(n(500, 3), function()
        B.prepare(g)
      end),
      allocation(n(100, 2), function()
        B.prepare(g)
      end),
      timed(n(500, 3), function()
        local bodies = B.prepare(g)
        for i = 1, 20 do
          B.traceVector(g, rays[i][1], rays[i][2], rays[i][3], 40, bodies)
        end
      end),
      allocation(n(100, 2), function()
        local bodies = B.prepare(g)
        for i = 1, 20 do
          B.traceVector(g, rays[i][1], rays[i][2], rays[i][3], 40, bodies)
        end
      end)
    )
  )
  -- Knight missiles: ten slow missiles crossing the field, per step.
  local Projectiles = require('src.combat.projectiles')
  local Spawn = require('src.session.spawn')
  g = field(G, population)
  g.testField.invincible = true
  local function volley()
    g.bullets = {}
    for i = 1, 10 do
      local e = g.enemies[math.floor(i * population / 10)]
      local dx, dz = e.x - g.player.x, e.z - g.player.z
      local l = math.sqrt(dx * dx + dz * dz)
      Spawn.make(g, 'projectile', {
        x = g.player.x,
        y = 1.2,
        z = g.player.z,
        vx = dx / l * 9,
        vy = 0,
        vz = dz / l * 9,
        life = 5,
        side = 'knight',
        packet = { base = 0, impact = 0 },
        radius = 0.12,
      })
    end
  end
  volley()
  log(
    string.format(
      'missiles: 10 knight missiles vs %d demons, per step %.4f ms (%.2f KiB)',
      population,
      timed(n(240, 4), function(i)
        if i % 60 == 0 then
          volley()
        end
        Projectiles.update(g, 1 / 120)
      end),
      allocation(n(60, 3), function()
        Projectiles.update(g, 1 / 120)
      end)
    )
  )
  -- Melee: a thrall attacking the knight (god mode), whole simulation steps.
  g = field(G, 1, 'imp')
  g.testField.invincible = true
  local e = g.enemies[1]
  e.x, e.z = g.player.x + math.sin(g.player.yaw) * 1.5, g.player.z + math.cos(g.player.yaw) * 1.5
  if smoke then
    Tooling.advanceUntil('melee smoke attack', function()
      return e.ai == 'strike'
    end, function(dt)
      g:update(dt, {})
    end, 1 / 120, 5)
  end
  local strikes = 0
  log(
    string.format(
      'melee: one attacking thrall, per simulation step %.4f ms (%.2f KiB, %s)',
      timed(n(1200, 120), function()
        g:update(1 / 120, {})
        strikes = strikes + (e.ai == 'strike' and 1 or 0)
      end),
      allocation(n(240, 4), function()
        g:update(1 / 120, {})
      end),
      strikes .. ' strike steps'
    )
  )
  assert(strikes > 0, 'melee workload never reached an active attack')
  -- Snapshot capture and restore of a 20-demon field.
  local Snapshot = require('src.session.snapshot')
  g = field(G, population)
  for _ = 1, n(60, 2) do
    g:update(1 / 120, {})
  end
  local memento
  log(
    string.format(
      'snapshot: %d bodies; capture %.3f ms (%.1f KiB), restore %.3f ms (%.1f KiB)',
      population,
      timed(n(20, 2), function()
        memento = Snapshot.capture(g)
      end),
      allocation(n(5, 1), function()
        Snapshot.capture(g)
      end),
      timed(n(20, 2), function()
        Snapshot.restore(g, memento)
      end),
      allocation(n(5, 1), function()
        Snapshot.restore(g, memento)
      end)
    )
  )
  -- Whole simulation steps with the population awake (plan v10 V0): the
  -- step cost against the number of bodies, and crowd separation alone
  -- (every living pair today).
  local AI = require('src.enemies.ai')
  g = field(G, population)
  g.testField.invincible = true
  for _ = 1, n(60, 2) do
    g:update(1 / 120, {})
  end
  local stepMedian, stepTail = spread(n(240, 4), function()
    g:update(1 / 120, {})
  end)
  local separationMedian = spread(n(240, 4), function()
    AI.separate(g, 1 / 120)
  end)
  log(
    string.format(
      'step: %d bodies awake; whole simulation step median %.4f ms, p95 %.4f ms; separation alone median %.4f ms',
      population,
      stepMedian,
      stepTail,
      separationMedian
    )
  )
  -- The population killed in place beside one living demon, measured once
  -- the corpses are done (drawn window over, at rest): since plan v10 V1
  -- they wait in the remains, outside every step.
  g = field(G, population)
  g.testField.invincible = true
  for i = 2, #g.enemies do
    local body = g.enemies[i]
    g:damageEnemy(body, body.hp + 1, 'weapon')
  end
  local visible = require('src.content.combat_defaults').corpse.visible
  for _ = 1, smoke and n(240, 4) or math.ceil((visible + 1) * 120) do
    g:update(1 / 120, {})
  end
  local alive = 0
  for _, body in ipairs(g.enemies) do
    alive = alive + (body.hp > 0 and 1 or 0)
  end
  local corpseMedian, corpseTail = spread(n(240, 4), function()
    g:update(1 / 120, {})
  end)
  log(
    string.format(
      'corpses: %d dead beside %d alive (%d in the living pool, %d in the remains); whole simulation step median %.4f ms, p95 %.4f ms',
      population - alive,
      alive,
      #g.enemies,
      #(g.remains or {}),
      corpseMedian,
      corpseTail
    )
  )
  -- Journal: production Input.sample includes the displayed geometry even
  -- while the held weapon cools down or reloads. Omitting it hides the cost.
  local Field = require('src.run.test_field')
  -- SIGIL_CORE_JOURNAL_SECONDS shortens the fight explicitly where ten
  -- seconds of a large crowd exceed the production recording budget (0.32:
  -- from 256 bodies); the report names the length used.
  local journalSeconds = tonumber(os.getenv('SIGIL_CORE_JOURNAL_SECONDS') or '') or n(10, 1)
  assert(journalSeconds >= 1 and journalSeconds % 1 == 0, 'journal seconds must be a whole number')
  local recording = require('qa.recording_workload').run(G, journalPopulation, journalSeconds)
  log(
    string.format(
      'journal: %d targets, %.2f s held-fire fight, 60 observations/s, 120 updates/s; start %.2f ms; fight %.1f ms; export %.2f ms; decode %.2f ms; replay %.1f ms; receipts=%d (replay verified)',
      journalPopulation,
      recording.seconds,
      recording.recordStart,
      recording.fight,
      recording.export,
      recording.decode,
      recording.replay,
      recording.receipts
    )
  )
  log(
    string.format(
      'journal storage: text=%d bytes; estimate=%d bytes; detached plain journal retained=%.1f KiB; commands=%d; observed mean bodies=%.2f; portal preparation steps=%d',
      recording.bytes,
      recording.estimatedBytes,
      recording.retainedCopyKiB,
      recording.commands,
      recording.meanBodies,
      recording.preparationSteps
    )
  )
  log(
    string.format(
      'journal limits: estimated serialized text=%d bytes; commands=%d; measured estimate growth=%.0f bytes/s, encoded growth=%.0f bytes/s, commands=%.1f/s; extrapolated estimate/command limits=%.2f/%.2f s at this workload only',
      recording.budget.maxBytes,
      recording.budget.maxCommands,
      recording.bytesPerSecond,
      recording.textBytesPerSecond,
      recording.commandsPerSecond,
      recording.budget.maxBytes / recording.bytesPerSecond,
      recording.budget.maxCommands / recording.commandsPerSecond
    )
  )
  log(
    'Journal text budget is NOT a RAM cap or a guaranteed duration. A complete command and final integrity may exceed the text estimate; retained-copy heap excludes export text, decoded replay, session and transient allocations. Geometry capture is real, rasterization is excluded.'
  )
  -- A long session: 300 waves of three demons, killed and cleared.
  g = Field.new(G)
  g.testing = true
  Field.close(g)
  local first = heap()
  start = clock()
  for wave = 1, n(300, 4) do
    local created = Field.spawn(g, wave % 2 == 0 and 'imp' or 'stolas', 3) or {}
    Field.close(g)
    for _, body in ipairs(created) do
      g:damageEnemy(body, body.hp + 1, 'weapon')
    end
    for _ = 1, 6 do
      g:update(1 / 120, {})
    end
  end
  local spent = (clock() - start) * 1000
  local records = 0
  for _ in pairs(g.telemetryBodies or {}) do
    records = records + 1
  end
  log(
    string.format(
      'long session: %d waves x 3 demons in %.0f ms; %d enemy records live, %d telemetry body records, heap +%.0f KiB',
      n(300, 4),
      spent,
      #g.enemies,
      records,
      heap() - first
    )
  )
  Tooling.write(output, 'core-measure.txt', lines, smoke)
  return lines
end
return M
