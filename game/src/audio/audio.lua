local A = { sources = {}, live = {}, muted = false, pool = {}, pooled = 0, voiceNames = {} }
local pi = math.pi
local function clip(x)
  return x / (1 + math.abs(x) * 0.55)
end
function A.init()
  local rate = 44100
  local specs = {
    heavyhit = 0.19,
    graze = 0.09,
    multikill = 0.33,
    shell = 0.12,
    shot = 0.60,
    revolver = 0.34,
    throw = 0.18,
    fuse = 0.34,
    blast = 0.95,
    thunder = 1.1,
    antler = 0.36,
    hit = 0.14,
    kill = 0.42,
    dash = 0.25,
    seal = 1.2,
    pulse = 0.8,
    pickup = 0.30,
    hurt = 0.25,
    empty = 0.08,
    open = 0.16,
    load = 0.18,
    close = 0.17,
    step = 0.10,
    land = 0.18,
    jump = 0.12,
    slide = 0.42,
    snarl = 0.55,
    owl = 0.65,
    growl = 0.7,
    cast = 0.50,
    claw = 0.25,
    bell = 2.4,
    whoosh = 0.34,
    crit = 0.24,
    ['break'] = 0.28,
    thud = 0.36,
    hall = 1.4,
    heart = 0.42,
  }
  -- One noise stream shared by every sound, so they are generated in name
  -- order: pairs() order (LuaJIT's per-process string hash) would give each
  -- sound different noise on every run.
  local rng = love.math.newRandomGenerator(413)
  local names = {}
  for name in pairs(specs) do
    names[#names + 1] = name
  end
  table.sort(names)
  for _, name in ipairs(names) do
    local dur = specs[name]
    local n = math.floor(dur * rate)
    local data = love.sound.newSoundData(n, rate, 16, 1)
    local low = 0
    local slower = 0
    for i = 0, n - 1 do
      local t = i / rate
      local u = t / dur
      local noise = rng:random() * 2 - 1
      low = low * 0.74 + noise * 0.26
      slower = slower * 0.975 + noise * 0.025
      local high = noise - low
      local sample = 0
      if name == 'shot' then
        local crack = high * 0.70 * math.exp(-t * 150) + low * 1.7 * math.exp(-t * 28)
        local body = math.sin(2 * pi * (74 * t + 1.2 * (1 - math.exp(-t * 40))))
          * 0.90
          * math.exp(-t * 22)
        local tail = slower * 3.5 * math.exp(-t * 8)
        local echo = (t > 0.065 and low * 0.35 * math.exp(-(t - 0.065) * 22) or 0)
        sample = clip(crack + body + tail + echo) * 0.87
      elseif name == 'bell' then
        sample = (
          math.sin(2 * pi * 147 * t) * 0.4
          + math.sin(2 * pi * 207.9 * t) * 0.18
          + math.sin(2 * pi * 355 * t) * 0.08
        ) * math.exp(-t * 2.3)
      elseif name == 'snarl' or name == 'growl' then
        local f = name == 'growl' and 58 or 87
        sample = clip(
          (math.sin(2 * pi * (f * t - 15 * t * t)) * 0.5 + low * 0.5)
            * (1 + 0.4 * math.sin(2 * pi * 26 * t))
        ) * math.sin(pi * u) * 0.7
      elseif name == 'owl' then
        sample = (
          math.sin(2 * pi * (430 * t - 140 * t * t)) * 0.4 + math.sin(2 * pi * 650 * t) * 0.12
        ) * math.sin(pi * u)
      elseif name == 'cast' then
        sample = clip(
          (slower * 2.2 + math.sin(2 * pi * (72 * t + 22 * t * t)) * 0.24 + high * 0.08)
            * math.sin(pi * u)
            * (0.4 + u)
        ) * 0.65
      elseif name == 'claw' or name == 'antler' then
        sample = (low * 0.8 + math.sin(2 * pi * (name == 'antler' and 103 or 190) * t) * 0.15)
          * math.sin(pi * u)
          * math.exp(-u * 3)
      elseif name == 'throw' then
        sample = (low * 0.40 + high * 0.11) * math.sin(pi * u) * math.exp(-u * 2)
      elseif name == 'fuse' then
        sample = high * 0.16 * (0.5 + 0.5 * math.sin(t * 2 * pi * 73)) * math.sin(pi * u)
      elseif name == 'blast' or name == 'thunder' then
        local attack = high * 0.8 * math.exp(-t * 100) + low * 1.5 * math.exp(-t * 22)
        local body = math.sin(2 * pi * (48 * t + 0.9 * (1 - math.exp(-t * 25))))
          * 0.8
          * math.exp(-t * 9)
        local tail = slower * 4 * math.exp(-t * (name == 'thunder' and 3.4 or 5))
        sample = clip(attack + body + tail) * 0.84
      elseif name == 'revolver' then
        local crack = high * 0.95 * math.exp(-t * 135) + low * 1.25 * math.exp(-t * 32)
        local body = math.sin(2 * pi * (112 * t + 0.65 * (1 - math.exp(-t * 35))))
          * 0.55
          * math.exp(-t * 27)
        local latch = t > 0.145
            and (high * 0.28 + math.sin(2 * pi * 1850 * t) * 0.12) * math.exp(-(t - 0.145) * 90)
          or 0
        sample = clip(crack + body + slower * 2.2 * math.exp(-t * 12) + latch) * 0.82
      elseif name == 'heavyhit' then
        sample = (low * 1.25 + math.sin(2 * pi * (95 * t - 90 * t * t)) * 0.65) * math.exp(-t * 32)
      elseif name == 'graze' then
        sample = (high * 0.38 + math.sin(2 * pi * 370 * t) * 0.12) * math.exp(-t * 60)
      elseif name == 'multikill' then
        sample = (math.sin(2 * pi * 330 * t) * 0.18 + math.sin(2 * pi * 495 * t) * 0.12)
          * math.exp(-t * 14)
      elseif name == 'shell' then
        sample = (
          high * 0.28
          + math.sin(2 * pi * 2450 * t) * 0.16
          + math.sin(2 * pi * 3470 * t) * 0.1
        ) * math.exp(-t * 65)
      elseif name == 'hit' then
        sample = (low * 0.85 + math.sin(2 * pi * 115 * t) * 0.4) * math.exp(-t * 40)
      elseif name == 'kill' then
        sample = (slower * 2.8 + low * 0.8) * math.exp(-t * 12)
      elseif name == 'open' or name == 'close' or name == 'load' then
        local f = name == 'open' and 1100 or (name == 'load' and 1850 or 760)
        local pulse = math.exp(-t * 75) + (t > 0.045 and 0.65 * math.exp(-(t - 0.045) * 95) or 0)
        sample = (
          high * 0.60
          + math.sin(2 * pi * f * t) * 0.20
          + math.sin(2 * pi * f * 1.41 * t) * 0.12
        ) * pulse
      elseif name == 'step' or name == 'land' then
        sample = (low * 0.6 + slower * 2 + math.sin(2 * pi * 95 * t) * 0.2) * math.exp(-t * 40)
        -- The knight's mail answers each footfall with a faint dull ring.
        if name == 'step' and t > 0.018 then
          sample = sample
            + (math.sin(2 * pi * 2350 * t) + 0.6 * math.sin(2 * pi * 3110 * t))
              * 0.022
              * math.exp(-(t - 0.018) * 48)
        end
      elseif name == 'slide' then
        sample = (low * 0.45 + high * 0.10) * math.sin(pi * u) * math.exp(-u * 2)
      elseif name == 'jump' or name == 'dash' then
        sample = low * 0.7 * math.sin(pi * u) * math.exp(-u * 2)
      elseif name == 'seal' or name == 'pickup' then
        local f = name == 'seal' and 220 or 660
        sample = (math.sin(2 * pi * f * t) + 0.4 * math.sin(2 * pi * f * 1.5 * t))
          * 0.3
          * math.sin(pi * u)
          * math.exp(-u * 3)
      -- Weight cues (src/feedback/weight.lua): a passing projectile, a precise hit,
      -- a broken guard, a body against stone.
      elseif name == 'whoosh' then
        local swell = math.sin(pi * u) ^ 2
        sample = (low * 0.55 + high * 0.22 * (1 - u))
          * swell
          * (0.6 + 0.4 * math.sin(2 * pi * (9 * t)))
      elseif name == 'crit' then
        sample = (
          math.sin(2 * pi * 1320 * t) * 0.22
          + math.sin(2 * pi * 1980 * t) * 0.10
          + high * 0.20 * math.exp(-t * 90)
        ) * math.exp(-t * 16)
      elseif name == 'break' then
        sample = clip(
          low * 1.5 * math.exp(-t * 26)
            + math.sin(2 * pi * (68 * t - 40 * t * t)) * 0.75 * math.exp(-t * 15)
            + high * 0.55 * math.exp(-t * 110)
            + math.sin(2 * pi * 820 * t) * 0.10 * math.exp(-t * 30)
        ) * 0.85
      elseif name == 'thud' then
        sample = clip(
          math.sin(2 * pi * (52 * t - 26 * t * t)) * 0.95 * math.exp(-t * 12)
            + low * 1.1 * math.exp(-t * 24)
            + slower * 2 * math.exp(-t * 8)
        ) * 0.85
      -- The stone hall answers a shot: three dark reflections and a long bloom.
      elseif name == 'hall' then
        local bloom = slower * 2.6 * (1 - math.exp(-t * 30)) * math.exp(-t * 2.8)
        local echo = 0
        for k, d in ipairs({ 0.085, 0.17, 0.29 }) do
          if t > d then
            echo = echo + low * (0.55 / k) * math.exp(-(t - d) * 14)
          end
        end
        sample = clip(bloom + echo) * 0.75
      -- The hero's heart under 30 HP: a muffled double beat.
      elseif name == 'heart' then
        local beat = function(s)
          return s > 0
              and math.sin(2 * pi * (46 * s)) * math.exp(-s * 22) + low * 0.35 * math.exp(-s * 40)
            or 0
        end
        sample = clip(beat(t) * 0.9 + beat(t - 0.17) * 0.65) * 0.9
      elseif name == 'pulse' then
        sample = (math.sin(2 * pi * (60 * t - 20 * t * t)) * 0.7 + low * 0.45)
          * math.sin(pi * u)
          * math.exp(-u * 3)
      else
        sample = (low * 0.7 + math.sin(2 * pi * 90 * t) * 0.4) * math.exp(-u * 7)
      end
      data:setSample(i, math.max(-0.98, math.min(0.98, sample)))
    end
    A.sources[name] = love.audio.newSource(data, 'static')
    data:release()
  end
  local dur = 8
  local data = love.sound.newSoundData(rate * dur, rate, 16, 1)
  for i = 0, rate * dur - 1 do
    local t = i / rate
    data:setSample(
      i,
      (
        math.sin(t * 2 * pi * 41.25) * 0.026
        + math.sin(t * 2 * pi * 61.875) * 0.012
        + math.sin(t * 2 * pi * 82.5) * 0.006
      ) * (1 + 0.15 * math.sin(t * 2 * pi / 8))
    )
  end
  A.ambient = love.audio.newSource(data, 'static')
  data:release()
  A.ambient:setLooping(true)
  A.ambient:setVolume(0.55)
  A.ambient:play()
  require('src.audio.soundscape').init(A)
end
-- Reuse finished voices instead of allocating a new Source on every pellet,
-- step and impact. Both active voices and the idle cache have strict caps.
local function recycle(s)
  s:stop()
  local name = A.voiceNames[s]
  A.voiceNames[s] = nil
  if name and A.pooled < 28 then
    A.pool[name] = A.pool[name] or {}
    local list = A.pool[name]
    list[#list + 1] = s
    A.pooled = A.pooled + 1
  else
    s:release()
  end
end
function A.play(name, volume)
  if A.muted or not A.sources[name] then
    return
  end
  while #A.live >= 28 do
    recycle(table.remove(A.live, 1))
  end
  local list = A.pool[name]
  local s
  if list and #list > 0 then
    s = table.remove(list)
    A.pooled = A.pooled - 1
  else
    s = A.sources[name]:clone()
  end
  A.voiceNames[s] = name
  s:setVolume(volume or 0.65)
  s:setPitch(1)
  s:setRelative(true)
  s:setPosition(0, 0, 0)
  s:setRolloff(0)
  if name == 'shot' or name == 'revolver' or name == 'hit' or name == 'step' or name == 'kill' then
    s:setPitch(0.96 + love.math.random() * 0.08)
  end
  s:play()
  A.live[#A.live + 1] = s
  return s
end
function A.playAt(name, x, z, p, volume)
  local dx, dz = x - p.x, z - p.z
  local d = math.sqrt(dx * dx + dz * dz)
  local s = A.play(name, (volume or 0.6) / (1 + d * 0.13))
  if s then
    local side =
      math.max(-1, math.min(1, (dx * math.cos(p.yaw) - dz * math.sin(p.yaw)) / math.max(1, d)))
    s:setRelative(true)
    s:setPosition(side * 0.8, 0, -0.6)
    s:setRolloff(0)
  end
  return s
end
function A.update(dt, g)
  if g then
    require('src.audio.soundscape').update(A, dt, g)
  end
  for i = #A.live, 1, -1 do
    if not A.live[i]:isPlaying() then
      recycle(table.remove(A.live, i))
    end
  end
end
function A.toggle()
  A.muted = not A.muted
  love.audio.setVolume(A.muted and 0 or 0.7)
end
return A
