-- Measures complete warm shot queries, never a single-ray cost multiplied up.
-- This is a CPU microbenchmark, not a rendered frame-time or FPS prediction.
local B = require('src.combat.ballistics')
local Surface = require('src.enemies.surface')
local Field = require('src.run.test_field')
local Tuning = require('src.content.tuning')
local Review = {}
local KINDS = { 'imp', 'armored', 'stolas', 'buer', 'boss', 'furfur' }
local PELLETS = 20
local function direction(g, x, y, z)
  local ox, oy, oz = B.origin(g)
  local dx, dy, dz = x - ox, y - oy, z - oz
  local length = math.sqrt(dx * dx + dy * dy + dz * dz)
  return dx / length, dy / length, dz / length, length
end
local function sourcePoint(p, u, v)
  local y = (1 - v) * p.height
  if p.mirror > 0.5 then
    u = 1 - u
  end
  local side = (u - 0.5) * p.width + y * p.lean
  return p.x + side * p.rx, p.baseY + y, p.z + side * p.rz
end
local function fixture(Game, count)
  local g = Field.new(Game)
  -- Isolated empty range: no pillar can silently remove a benchmark subject.
  -- Real DDA world tracing is retained, including the floor and perimeter.
  g.world.size, g.world.floor, g.world.map = 64, 0, {}
  for z = 1, 64 do
    g.world.map[z] = {}
    for x = 1, 64 do
      g.world.map[z][x] = (x == 1 or z == 1 or x == 64 or z == 64) and 1 or 0
    end
  end
  g.player.x, g.player.z, g.player.yaw, g.player.pitch = 32, 48, math.pi, 0
  g.enemies = {}
  local distance = count == 1 and 8 or count == 10 and 14 or 21
  -- All bodies are in the forward hemisphere. No render/FOV culling applies
  -- to ballistics; the widest population spans 149 degrees, explicitly.
  local span = count == 1 and 0 or count == 10 and 1.8 or 2.6
  local composition = {}
  for i = 1, count do
    local kind = KINDS[(i - 1) % #KINDS + 1]
    local angle = count == 1 and 0 or -span / 2 + span * (i - 1) / (count - 1)
    local e = g:spawn(kind, 32 + math.sin(angle) * distance, 48 - math.cos(angle) * distance)
    e.ai, e.spawnAge, e.previewFrame = 'chase', 1, 1 + (i - 1) % 4
    composition[kind] = (composition[kind] or 0) + 1
  end
  local bodies = B.prepare(g)
  local volleys = {}
  for _, entry in ipairs(bodies) do
    local found
    -- Choose a visible painted torso point outside the timed section. Every
    -- subject must really be hit by a centre ray, not merely exist in a list.
    for row = 3, 15 do
      for column = 3, 17 do
        if not found then
          local u, v = column / 20, row / 20
          local part = Surface.part(entry.surface.parts, u, v)
          if
            part
            and part.hittable ~= false
            and part.zone == 'torso'
            and Surface.painted(entry.surface.mask, u, v, true)
          then
            local x, y, z = sourcePoint(entry.surface, u, v)
            local dx, dy, dz, length = direction(g, x, y, z)
            local hit = B.traceVector(g, dx, dy, dz, Tuning.shotgunRange, bodies)
            if hit == entry.enemy then
              found = { dx, dy, dz, length }
            end
          end
        end
      end
    end
    assert(found, 'performance fixture occludes ' .. entry.enemy.kind .. '/' .. entry.enemy.id)
    local yaw = math.atan2(found[1], found[3])
    local pitch = math.atan2(found[2], math.sqrt(found[1] ^ 2 + found[3] ^ 2))
    local rays = {}
    for pellet = 1, PELLETS do
      local horizontal, vertical = B.pellet(pellet, #volleys, PELLETS)
      rays[pellet] = { B.spreadDirection(yaw, pitch, horizontal, vertical) }
    end
    volleys[#volleys + 1] = rays
  end
  local names = {}
  for _, kind in ipairs(KINDS) do
    if composition[kind] then
      names[#names + 1] = kind .. ':' .. composition[kind]
    end
  end
  return g, volleys, table.concat(names, '+'), distance, span
end
local function shoot(g, rays, bodies)
  local hits, sum = 0, 0
  for i = 1, PELLETS do
    local ray = rays[i]
    local enemy, distance = B.traceVector(g, ray[1], ray[2], ray[3], Tuning.shotgunRange, bodies)
    if enemy then
      hits = hits + 1
    end
    sum = sum + distance
  end
  return hits, sum
end
local function percentile(values, fraction)
  table.sort(values)
  return values[math.max(1, math.ceil(#values * fraction))]
end
local function benchmark(Game, count, warmup, iterations, allocationIterations)
  local g, volleys, composition, distance, span = fixture(Game, count)
  for i = 1, warmup do
    shoot(g, volleys[(i - 1) % count + 1], B.prepare(g))
  end
  collectgarbage('collect')
  local pose, query, hits, checksum = 0, 0, 0, 0
  local samples = {}
  local clock = love.timer.getTime
  local started = clock()
  for i = 1, iterations do
    local rays = volleys[(i - 1) % count + 1]
    local a = clock()
    local bodies = B.prepare(g)
    local b = clock()
    local n, sum = shoot(g, rays, bodies)
    local c = clock()
    pose, query = pose + b - a, query + c - b
    samples[i] = c - a
    hits, checksum = hits + n, checksum + sum
  end
  local elapsed = clock() - started
  -- A separate bounded pass measures Lua heap allocation. It deliberately
  -- does not report retained memory or mix stopped-GC times with normal times.
  collectgarbage('collect')
  collectgarbage('stop')
  local allocationBefore = collectgarbage('count')
  local ok, allocation = pcall(function()
    for i = 1, allocationIterations do
      shoot(g, volleys[(i - 1) % count + 1], B.prepare(g))
    end
    return (collectgarbage('count') - allocationBefore) / allocationIterations
  end)
  collectgarbage('restart')
  assert(ok, allocation)
  assert(hits > 0 and checksum > 0, 'benchmark must execute live contacts')
  return {
    enemies = count,
    composition = composition,
    distance = distance,
    spanDegrees = span * 180 / math.pi,
    warmup = warmup,
    iterations = iterations,
    allocationIterations = allocationIterations,
    pellets = PELLETS,
    visible = #volleys,
    poseMs = pose * 1000 / iterations,
    queryMs = query * 1000 / iterations,
    totalMs = elapsed * 1000 / iterations,
    medianMs = percentile(samples, 0.5) * 1000,
    p95Ms = percentile(samples, 0.95) * 1000,
    allocationKiB = allocation,
    hits = hits,
    checksum = checksum,
  }
end
function Review.run(Game, output, options)
  options = options or {}
  local warmup, iterations = options.warmup or 240, options.iterations or 1200
  local allocationIterations = options.allocationIterations or 120
  local result = {}
  local lines = {
    'FULL SHOT-QUERY CPU MICROBENCHMARK',
    'Actual B.prepare once + 20 B.traceVector calls per volley; cached bodies reused normally.',
    'Includes pose/semantic preparation, DDA world tracing, all enemy broad phases, masks and hit receipts.',
    'Excludes ray generation, damage/effects, simulation, rendering/GPU and input latency. Not an FPS estimate.',
    'Mixed existing archetypes/painted walk frames. Every subject verified directly hittable before timing.',
    'Empty 64x64 range with perimeter walls; subjects in the front hemisphere. No FOV culling.',
    'Aim cycles over subjects; actual shotgun cone/range. Warm masks/JIT; normal GC during timing.',
    'Pose/query use per-volley clock boundaries; wall total also includes timing/report bookkeeping.',
    'Allocation is gross Lua heap increase/volley from a separate bounded pass with GC paused, not retained memory.',
    string.format(
      'Runtime: %s; OS: %s; timings from love.timer.getTime.',
      jit and jit.version or _VERSION,
      love.system.getOS()
    ),
    '',
  }
  local csv = {
    'enemies,visible,composition,distance_m,span_degrees,warmup,volleys,pellets,pose_ms,query_ms,total_ms,median_ms,p95_ms,allocation_kib,allocation_volleys,hits,total_rays,checksum',
  }
  for _, count in ipairs({ 1, 10, 20 }) do
    local row = benchmark(Game, count, warmup, iterations, allocationIterations)
    result[#result + 1] = row
    lines[#lines + 1] = string.format(
      '%d enemies (%s), %d directly hittable; roots %.1f m away, span %.1f degrees.',
      row.enemies,
      row.composition,
      row.visible,
      row.distance,
      row.spanDegrees
    )
    lines[#lines + 1] = string.format(
      '  %d warmups; %d volleys x 20 rays; %d contacts/%d rays.',
      warmup,
      iterations,
      row.hits,
      iterations * PELLETS
    )
    lines[#lines + 1] = string.format(
      '  Mean: prepare %.4f ms + queries %.4f ms; wall total %.4f ms. Per-volley median %.4f ms, p95 %.4f ms.',
      row.poseMs,
      row.queryMs,
      row.totalMs,
      row.medianMs,
      row.p95Ms
    )
    lines[#lines + 1] = string.format(
      '  Allocation %.3f KiB/volley across %d stopped-GC volleys.',
      row.allocationKiB,
      allocationIterations
    )
    csv[#csv + 1] = string.format(
      '%d,%d,%s,%.2f,%.3f,%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%d,%d,%.6f',
      count,
      row.visible,
      row.composition,
      row.distance,
      row.spanDegrees,
      warmup,
      iterations,
      PELLETS,
      row.poseMs,
      row.queryMs,
      row.totalMs,
      row.medianMs,
      row.p95Ms,
      row.allocationKiB,
      allocationIterations,
      row.hits,
      iterations * PELLETS,
      row.checksum
    )
  end
  local function write(name, content)
    local file = assert(io.open(output .. '/' .. name, 'w'))
    file:write(table.concat(content, '\n') .. '\n')
    file:close()
  end
  write('hit-performance.txt', lines)
  write('hit-performance.csv', csv)
  return result
end
return Review
