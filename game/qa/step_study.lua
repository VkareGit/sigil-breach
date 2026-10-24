-- Two separate experiments (0.29), never mixed:
--   A. Frame rate. The same scenario (inputs as a function of simulation time)
--      driven by the application's accumulator at 30 / 60 / 144 / 240 FPS
--      and a jittered schedule. The simulation step stays 1/120 s, so every
--      schedule must reproduce the same state bit for bit; below 5 FPS the
--      accumulator's 0.2 s clamp drops time (shown, by design).
--   B. Physics step. Each contact or motion law run with steps of 1/60, 1/120
--      (the game's) and 1/240 s, one Game:simulate step each (Game:update would
--      split any step into 1/120 s): how much its result moves with the step.
--      Swept and closed-form laws should agree to well under a step's travel.
local Golden = require('qa.golden')
local Rules = require('src.combat.rules')
local Attacks = require('src.enemies.actions')
local Tooling = require('qa.tooling')
local S = {}
local STEP = 1 / 120
local function arena(G)
  local g = G.new('classic')
  g.testing = true
  g:start()
  g.enemies, g.bullets, g.hazards, g.pickups = {}, {}, {}, {}
  g.player.x, g.player.z, g.player.yaw = 16, 25, math.pi
  return g
end
-- A. The application's accumulator (app/application.lua: update), alone.
local function drive(G, frames, limit)
  local g = arena(G)
  local e = g:spawn('imp', 16, 17)
  e.spawnAge, e.awake = 1, true
  local accumulator, steps = 0, 0
  for _, dt in ipairs(frames) do
    accumulator = math.min(0.20, accumulator + dt)
    while accumulator >= STEP and steps < (limit or math.huge) do
      steps = steps + 1
      local input = { forward = steps % 240 < 60 and 1 or 0, shoot = steps % 70 == 0 }
      g.player.yaw = math.pi + math.sin(steps / 90) * 0.2
      g:update(STEP, input)
      accumulator = accumulator - STEP
    end
  end
  return Golden.digest(g), steps
end
local function schedule(fps, seconds, jitter)
  local out, t, i = {}, 0, 0
  while t < seconds do
    i = i + 1
    local dt = 1 / fps
    if jitter then
      dt = dt * (0.4 + 1.2 * ((i * 7919) % 101) / 100)
    end
    out[i], t = dt, t + dt
  end
  return out
end
-- B. Laws at a given step; each returns a number (seconds or metres).
local laws = {}
function laws.boltContact(G, dt)
  local g = arena(G)
  local e = g:spawn('stolas', 16, 15)
  e.spawnAge, e.awake = 1, true
  local hitAt
  g.bus:on('sim', 'PlayerHit', function()
    hitAt = hitAt or g.elapsed
  end)
  Attacks.begin(g, e, 10, Rules.archetype(e).attacks[1])
  for _ = 1, math.ceil(4 / dt) do
    g:simulate(dt, {})
    if hitAt then
      break
    end
  end
  return hitAt, 'time of a bolt meeting the knight (s)'
end
function laws.clawContact(G, dt)
  local g = arena(G)
  local e = g:spawn('imp', 16, 23)
  e.spawnAge, e.awake = 1, true
  local hitAt
  g.bus:on('sim', 'PlayerHit', function()
    hitAt = hitAt or g.elapsed
  end)
  Attacks.begin(g, e, 2, Rules.archetype(e).attacks[1])
  for _ = 1, math.ceil(3 / dt) do
    g:simulate(dt, {})
    if hitAt then
      break
    end
  end
  return hitAt, 'time of a claw landing (s)'
end
function laws.chargeContact(G, dt)
  local g = arena(G)
  local e = g:spawn('armored', 16, 19)
  e.spawnAge, e.awake = 1, true
  local hitAt
  g.bus:on('sim', 'PlayerHit', function()
    hitAt = hitAt or g.elapsed
  end)
  for _, atk in ipairs(Rules.archetype(e).attacks) do
    if atk.kind == 'charge' then
      Attacks.begin(g, e, 6, atk)
    end
  end
  for _ = 1, math.ceil(4 / dt) do
    g:simulate(dt, {})
    if hitAt then
      break
    end
  end
  return hitAt, 'time of a charge reaching the knight (s)'
end
function laws.leapLanding(G, dt)
  local g = arena(G)
  local e = g:spawn('imp', 16, 19)
  e.spawnAge, e.awake = 1, true
  local landed
  g.bus:on('sim', 'Landed', function()
    landed = landed or g.elapsed
  end)
  for _, atk in ipairs(Rules.archetype(e).attacks) do
    if atk.kind == 'leap' then
      Attacks.begin(g, e, 6, atk)
    end
  end
  for _ = 1, math.ceil(4 / dt) do
    g:simulate(dt, {})
    if landed then
      break
    end
  end
  return landed, 'time of a leap landing (s)'
end
function laws.shove(G, dt)
  local g = arena(G)
  local e = g:spawn('imp', 16, 20)
  -- Stunned for the whole second: the shove alone moves it, no walking.
  e.spawnAge, e.stun = 1, 5
  Rules.addPush(e, 0, -1, 5, 1)
  local z = e.z
  for _ = 1, math.floor(1 / dt + 0.5) do
    g:simulate(dt, {})
  end
  return z - e.z, 'travel of a 5 m/s shove in 1 s (m)'
end
function laws.walk(G, dt)
  local g = arena(G)
  local e = g:spawn('imp', 16, 5)
  e.spawnAge, e.awake = 1, true
  local z = e.z
  for _ = 1, math.floor(1 / dt + 0.5) do
    g:simulate(dt, {})
  end
  return e.z - z, 'a thrall walking from rest for 1 s (m)'
end
function laws.corpseLanding(G, dt)
  local g = arena(G)
  local e = g:spawn('imp', 16, 20)
  e.spawnAge = 1
  g:damageEnemy(e, e.hp + 1, 'weapon')
  e.fallY, e.fallVY = 0, 2
  for _ = 1, math.ceil(1 / dt) do
    g:simulate(dt, {})
    if e.fallLanded then
      break
    end
  end
  return e.fallLanded, 'a corpse thrown up at 2 m/s lands (s)'
end
function laws.knightRun(G, dt)
  local g = arena(G)
  local z = g.player.z
  for _ = 1, math.floor(1 / dt + 0.5) do
    g:simulate(dt, { forward = 1 })
  end
  return z - g.player.z, 'the knight running forward for 1 s (m)'
end
function S.run(G, output, smoke)
  local lines = Tooling.header('STEP STUDY', smoke)
  lines[#lines + 1] = 'A. Frame rate at a fixed 1/120 s simulation step:'
  local limit, duration = Tooling.count(smoke, 700, 120), Tooling.count(smoke, 6, 1.1)
  local reference
  for _, entry in ipairs({
    -- Each schedule runs exactly 700 steps (5.83 s): the same simulated time.
    { 'fps 30', schedule(30, duration) },
    { 'fps 60', schedule(60, duration) },
    { 'fps 144', schedule(144, duration) },
    { 'fps 240', schedule(240, duration) },
    { 'jittered 24-150 fps', schedule(60, duration, true) },
  }) do
    local digest, steps = drive(G, entry[2], limit)
    reference = reference or digest
    lines[#lines + 1] = string.format(
      '  %-22s %5d steps  digest %s  %s',
      entry[1],
      steps,
      digest,
      digest == reference and 'same' or 'DIFFERENT'
    )
    assert(
      steps == limit and digest == reference,
      'fixed-step frame schedule diverged: ' .. entry[1]
    )
  end
  local slow, steps = drive(G, schedule(4, duration))
  lines[#lines + 1] = string.format(
    '  %-22s %5d steps (time dropped by the 0.2 s clamp, by design)  digest %s',
    'fps 4',
    steps,
    slow
  )
  lines[#lines + 1] = ''
  lines[#lines + 1] =
    'B. Physics step (each law at dt 1/60, 1/120, 1/240 s; difference from 1/120):'
  local names = {}
  for name in pairs(laws) do
    names[#names + 1] = name
  end
  table.sort(names)
  local results = {}
  for _, name in ipairs(names) do
    local values, label = {}, ''
    for i, dt in ipairs({ 1 / 60, 1 / 120, 1 / 240 }) do
      values[i], label = laws[name](G, dt)
    end
    results[name] = values
    local base = values[2]
    lines[#lines + 1] = string.format(
      '  %-14s %-44s 1/60 %s  1/120 %s  1/240 %s  max diff %s',
      name,
      label,
      values[1] and string.format('%.4f', values[1]) or 'none',
      base and string.format('%.4f', base) or 'none',
      values[3] and string.format('%.4f', values[3]) or 'none',
      (base and values[1] and values[3])
          and string.format(
            '%.4f',
            math.max(math.abs(values[1] - base), math.abs(values[3] - base))
          )
        or '-'
    )
  end
  Tooling.write(output, 'step-study.txt', lines, smoke)
  for _, line in ipairs(lines) do
    print(line)
  end
  return results
end
return S
