-- Spike verification: performance, determinism and event ordering of an
-- ECS on flat entities with a two-phase event bus, at the game's 120 Hz.
local ECS = require('ecs')
local Bus = require('events')

local function build(enemies)
  local w = ECS.new()
  local bus = Bus.new()
  -- Components with the game's real field names (flat entities).
  w:component('transform', { x = 0, z = 0, yaw = 0, facing = 0 })
  w:component('motion', { vx = 0, vz = 0, pushX = 0, pushZ = 0, walkSpeed = 0 })
  w:component('health', { hp = 100, maxHp = 100, deathTime = 0 })
  w:component('guard', { poise = 0, staggerLock = 0, stun = 0 })
  w:component('brain', { ai = 'idle', phase = 0, windup = 0, recover = 0, attack = 1.5, side = 1 })
  w:component('conditions', { conditions = {} })
  w:component('projectile', { vx = 0, vz = 0, life = 3 })
  local log = {}
  -- Simulation listeners: order is part of the rules (priority, then registration).
  bus:on('sim', 'killed', 20, function(ev)
    log[#log + 1] = 'reward:' .. ev.id
  end)
  bus:on('sim', 'killed', 10, function(ev)
    log[#log + 1] = 'breakKill:' .. ev.id
  end)
  local sounds, particles = 0, 0
  bus:on('present', 'killed', 0, function()
    sounds = sounds + 1
  end)
  bus:on('present', 'hit', 0, function()
    particles = particles + 1
  end)
  local enemy = { 'transform', 'motion', 'health', 'guard', 'brain', 'conditions' }
  for i = 1, enemies do
    w:spawn(enemy, { x = (i * 7.31) % 30, z = (i * 3.71) % 30, hp = 100 + i % 50, maxHp = 150 })
  end
  w:flush()
  local player = { x = 16, z = 16 }
  -- Systems in the fixed order of the session pipeline.
  w:system('timers', function(world, _, dt)
    for _, e in ipairs(world:query('guard')) do
      e.stun = math.max(0, e.stun - dt)
      e.staggerLock = math.max(0, e.staggerLock - dt)
    end
  end)
  w:system('brain', function(world, _, dt)
    for _, e in ipairs(world:query('brain', 'transform')) do
      e.phase = e.phase + dt
      e.attack = e.attack - dt
      if e.ai == 'idle' then
        e.ai = 'move'
      elseif e.ai == 'move' and e.attack <= 0 then
        e.ai, e.phase, e.attack = 'windup', 0, 1.5
      elseif e.ai == 'windup' and e.phase > 0.5 then
        e.ai, e.phase = 'move', 0
        -- an attack spawns a projectile (structural change, deferred)
        world:spawn({ 'transform', 'projectile' }, { x = e.x, z = e.z, vx = math.sin(e.id), vz = math.cos(e.id) })
      end
    end
  end)
  w:system('locomotion', function(world, _, dt)
    for _, e in ipairs(world:query('motion', 'transform', 'brain')) do
      local dx, dz = player.x - e.x, player.z - e.z
      local d = math.sqrt(dx * dx + dz * dz) + 1e-6
      e.vx, e.vz = dx / d * 3, dz / d * 3
      e.x = e.x + (e.vx + e.pushX) * dt
      e.z = e.z + (e.vz + e.pushZ) * dt
      e.pushX, e.pushZ = e.pushX * math.exp(-14 * dt), e.pushZ * math.exp(-14 * dt)
      e.facing = math.atan2(dx, dz)
    end
  end)
  w:system('projectiles', function(world, _, dt)
    for _, b in ipairs(world:query('projectile', 'transform')) do
      b.x, b.z, b.life = b.x + b.vx * 7 * dt, b.z + b.vz * 7 * dt, b.life - dt
      if b.life <= 0 then
        world:destroy(b)
      end
    end
  end)
  w:system('damage', function(world, ctx)
    -- every 10th step: hit the first 20 bodies through events
    if ctx.step % 10 ~= 0 then
      return
    end
    local list = world:query('health', 'guard')
    for i = 1, math.min(20, #list) do
      local e = list[i]
      e.hp = e.hp - 7
      e.poise = e.poise + 12
      bus:emit('hit', { id = e.id, amount = 7 })
      if e.hp <= 0 and not e.deadMarked then
        e.deadMarked = true
        bus:emit('killed', { id = e.id })
        world:destroy(e)
      end
    end
  end)
  return w, bus, log, function()
    return sounds, particles
  end
end

local function hash(w)
  local h = 0
  for _, e in ipairs(w.entities) do
    h = (h * 31 + math.floor((e.x or 0) * 1000) + math.floor((e.z or 0) * 1000) + (e.hp or 0)) % 2147483647
  end
  return h
end

local function run(enemies, seconds)
  local w, bus, log, fx = build(enemies)
  local ctx = { step = 0 }
  local t0 = love.timer.getTime()
  local steps = seconds * 120
  for s = 1, steps do
    ctx.step = s
    w:step(ctx, 1 / 120)
    bus:flushPresent()
  end
  local ms = (love.timer.getTime() - t0) * 1000 / steps
  return hash(w), ms, log, fx(), #w.entities
end

function love.load()
  local lines = {}
  for _, n in ipairs({ 10, 60, 300 }) do
    local h1, ms, log, sounds, live = run(n, 10)
    local h2 = run(n, 10)
    lines[#lines + 1] = string.format(
      'enemies %3d: %.4f ms/step (budget at 120 Hz: 8.33 ms), deterministic %s, live entities %d, kill events %d',
      n,
      ms,
      tostring(h1 == h2),
      live,
      sounds
    )
    if n == 60 then
      -- ordering: for every kill, breakKill (priority 10) precedes reward (20)
      local ok = true
      for i = 1, #log, 2 do
        if not (log[i]:match('^breakKill') and log[i + 1] and log[i + 1]:match('^reward')) then
          ok = false
        end
      end
      lines[#lines + 1] = 'sim listeners in priority order for every kill: ' .. tostring(ok) .. ' (' .. (#log / 2) .. ' kills)'
    end
  end
  local out = table.concat(lines, '\n')
  love.filesystem.write('spike-result.txt', out)
  io.write(out .. '\n')
  love.event.quit(0)
end
