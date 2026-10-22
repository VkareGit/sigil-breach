-- Core cost measurements (0.29): the same workloads before and after a change,
-- each measured separately — never one number multiplied up. CPU wall time
-- from love.timer, Lua heap from collectgarbage('count'). Not an FPS estimate.
--   masks         parsing and building the baked mask data (a fresh chunk)
--   surface       preparing poses/surfaces and full 20-ray volleys
--   missiles      knight missiles swept against 20 demons each step
--   melee         a thrall's lunges and claws against the knight
--   snapshot      Snapshot.capture / restore of a 20-demon field
--   journal       recording, exporting and replaying a field fight
--   long session  300 waves of three demons spawned, killed and cleared
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
local function field(G, count, kind)
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
function M.run(G, output)
  local lines = { 'CORE COST MEASUREMENTS', 'LuaJIT ' .. tostring(jit and jit.version), '' }
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
  local g = field(G, 20)
  local ox, oy, oz = B.origin(g)
  local rays = {}
  for i = 1, 20 do
    local e = g.enemies[i]
    local dx, dy, dz = e.x - ox, 1.2 - oy, e.z - oz
    local l = math.sqrt(dx * dx + dy * dy + dz * dz)
    rays[i] = { dx / l, dy / l, dz / l }
  end
  for _ = 1, 50 do
    B.prepare(g)
  end
  log(
    string.format(
      'surface: prepare 20 bodies %.4f ms (%.2f KiB), volley prepare + 20 rays %.4f ms (%.2f KiB)',
      timed(500, function()
        B.prepare(g)
      end),
      allocation(100, function()
        B.prepare(g)
      end),
      timed(500, function()
        local bodies = B.prepare(g)
        for i = 1, 20 do
          B.traceVector(g, rays[i][1], rays[i][2], rays[i][3], 40, bodies)
        end
      end),
      allocation(100, function()
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
  g = field(G, 20)
  g.testField.invincible = true
  local function volley()
    g.bullets = {}
    for i = 1, 10 do
      local e = g.enemies[i * 2]
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
      'missiles: 10 knight missiles vs 20 demons, per step %.4f ms (%.2f KiB)',
      timed(240, function(i)
        if i % 60 == 0 then
          volley()
        end
        Projectiles.update(g, 1 / 120)
      end),
      allocation(60, function()
        Projectiles.update(g, 1 / 120)
      end)
    )
  )
  -- Melee: a thrall attacking the knight (god mode), whole simulation steps.
  g = field(G, 1, 'imp')
  g.testField.invincible = true
  local e = g.enemies[1]
  e.x, e.z = g.player.x + math.sin(g.player.yaw) * 1.5, g.player.z + math.cos(g.player.yaw) * 1.5
  local strikes = 0
  log(
    string.format(
      'melee: one attacking thrall, per simulation step %.4f ms (%.2f KiB, %s)',
      timed(1200, function()
        g:update(1 / 120, {})
        strikes = strikes + (e.ai == 'strike' and 1 or 0)
      end),
      allocation(240, function()
        g:update(1 / 120, {})
      end),
      strikes .. ' strike steps'
    )
  )
  -- Snapshot capture and restore of a 20-demon field.
  local Snapshot = require('src.session.snapshot')
  g = field(G, 20)
  for _ = 1, 60 do
    g:update(1 / 120, {})
  end
  local memento
  log(
    string.format(
      'snapshot: capture %.3f ms (%.1f KiB), restore %.3f ms (%.1f KiB)',
      timed(20, function()
        memento = Snapshot.capture(g)
      end),
      allocation(5, function()
        Snapshot.capture(g)
      end),
      timed(20, function()
        Snapshot.restore(g, memento)
      end),
      allocation(5, function()
        Snapshot.restore(g, memento)
      end)
    )
  )
  -- Journal: record, export and replay a ten-second field fight.
  local Journal = require('src.session.journal')
  local Field = require('src.run.test_field')
  g = Field.new(G)
  g.testing = true
  start = clock()
  local journal = Journal.record(g)
  local recordStart = (clock() - start) * 1000
  g:act('catalog', 'field_spawn_imp_3')
  start = clock()
  for tick = 1, 1200 do
    g.player.yaw = g.player.yaw + 0.002
    g:update(1 / 120, { shoot = tick % 45 == 0 })
  end
  local fight = (clock() - start) * 1000
  start = clock()
  local text = Journal.encode(journal)
  local export = (clock() - start) * 1000
  Journal.stop(g)
  local fresh = Journal.session(G, Journal.decode(text))
  fresh.testing = true
  start = clock()
  Journal.replay(fresh, Journal.decode(text))
  local replay = (clock() - start) * 1000
  log(
    string.format(
      'journal: record start %.2f ms, recorded 10 s fight %.1f ms, export %.2f ms (%.0f KiB text), replay %.1f ms',
      recordStart,
      fight,
      export,
      #text / 1024,
      replay
    )
  )
  -- A long session: 300 waves of three demons, killed and cleared.
  g = Field.new(G)
  g.testing = true
  Field.close(g)
  local first = heap()
  start = clock()
  for wave = 1, 300 do
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
      'long session: 300 waves x 3 demons in %.0f ms; %d enemy records live, %d telemetry body records, heap +%.0f KiB',
      spent,
      #g.enemies,
      records,
      heap() - first
    )
  )
  local f = assert(io.open(output .. '/core-measure.txt', 'w'))
  f:write(table.concat(lines, '\n') .. '\n')
  f:close()
  return lines
end
return M
