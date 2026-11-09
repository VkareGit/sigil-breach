-- The Exorcist's sound in two directions for the owner's listening (the
-- Exorcist plan, point 6). Nothing here plays in the game: the full audio
-- export (qa/audio_export.lua) writes each cue of the gun in both directions
-- beside today's sound, every pair brought to the same level, into
-- <qa output>/sound-ab/exorcist with a report. The owner chooses; only then
-- does a direction become the gun's bank.
--   A: dry iron, a violent report, heavy powder; a short answer of the walls.
--   B: the same readable attack, a deeper growl of powder and a darker,
--      longer answer of the stone.
-- Cues: both barrels, one barrel (the gun fired with one round), the breech
-- thrown open, one and two rounds pushed home, the breech shut, the trigger on
-- an empty breech, the gun drawn.
local Synth = require('src.audio.synth')
local AB = {}
local pi, sin, exp, min = math.pi, math.sin, math.exp, math.min
local clip = Synth.clip

-- A crack of one barrel at onset, its shock and its powder.
local function barrel(t, at, noise, sharp)
  local d = t - at
  if d < 0 then
    return 0
  end
  return noise * exp(-d * sharp)
end

-- Every cue: its length, today's sound to stand beside it (and the share of
-- its level to match), and its voice in each direction.
-- voice(rate) -> function(t, noise, low, slower, high) -> sample
AB.cues = {
  {
    id = 'shot2',
    duration = 1.4,
    classic = 'shot',
    share = 1,
    A = function(rate)
      local boom = Synth.resonator(600, 0.9, rate)
      local walls = Synth.reflections(rate, { { 0.031, 0.22 }, { 0.067, 0.12 } })
      return function(t, noise, low, slower)
        local crack = barrel(t, 0, noise, 1100) + barrel(t, 0.005, noise, 1100) * 0.8
        local blast = low * 1.3 * exp(-t * 30) + boom(noise) * 2 * exp(-t * 20)
        local body = sin(2 * pi * (52 * t + 1.2 * (1 - exp(-t * 34)))) * 0.85 * exp(-t * 16)
        return clip(walls(crack * 0.85 + blast + body + slower * 2 * exp(-t * 7)))
      end
    end,
    B = function(rate)
      local boom = Synth.resonator(380, 0.8, rate)
      local walls = Synth.reflections(
        rate,
        { { 0.058, 0.36 }, { 0.117, 0.24 }, { 0.176, 0.14 }, { 0.25, 0.08 } }
      )
      return function(t, noise, low, slower)
        local crack = barrel(t, 0, noise, 900) + barrel(t, 0.006, noise, 900) * 0.75
        local blast = low * 1.8 * exp(-t * 20) + boom(noise) * 2.4 * exp(-t * 13)
        local body = sin(2 * pi * (40 * t + 1.6 * (1 - exp(-t * 26)))) * 1.0 * exp(-t * 9)
        return clip(walls(crack * 0.7 + blast + body + slower * 3.6 * exp(-t * 3.2)))
      end
    end,
  },
  {
    id = 'shot1',
    duration = 1.2,
    classic = 'shot',
    -- One round: weaker than both, as the hands show it (PLAN E6d).
    share = 0.7,
    A = function(rate)
      local boom = Synth.resonator(640, 0.9, rate)
      local walls = Synth.reflections(rate, { { 0.031, 0.2 }, { 0.067, 0.1 } })
      return function(t, noise, low, slower)
        local crack = barrel(t, 0, noise, 1200)
        local blast = low * 1.1 * exp(-t * 34) + boom(noise) * 1.6 * exp(-t * 22)
        local body = sin(2 * pi * (58 * t + 1 * (1 - exp(-t * 36)))) * 0.6 * exp(-t * 18)
        return clip(walls(crack * 0.85 + blast + body + slower * 1.5 * exp(-t * 8)))
      end
    end,
    B = function(rate)
      local boom = Synth.resonator(420, 0.8, rate)
      local walls = Synth.reflections(rate, { { 0.058, 0.32 }, { 0.117, 0.2 }, { 0.176, 0.11 } })
      return function(t, noise, low, slower)
        local crack = barrel(t, 0, noise, 950)
        local blast = low * 1.5 * exp(-t * 22) + boom(noise) * 1.9 * exp(-t * 14)
        local body = sin(2 * pi * (44 * t + 1.3 * (1 - exp(-t * 28)))) * 0.75 * exp(-t * 10)
        return clip(walls(crack * 0.7 + blast + body + slower * 2.8 * exp(-t * 3.6)))
      end
    end,
  },
  {
    id = 'open',
    duration = 0.4,
    classic = 'breakOpen',
    share = 1,
    A = function()
      return function(t, noise, low)
        local lever = Synth.clicks(t, { 0 }, 3400, 480, 0.34) + noise * 0.3 * exp(-t * 800)
        local hinge = Synth.clicks(t, { 0.028 }, 1100, 80, 0.3)
          + Synth.clicks(t, { 0.028 }, 1700, 120, 0.12)
        local drop = t > 0.055
            and (sin(2 * pi * 160 * (t - 0.055)) * 0.4 + low * 0.4) * exp(-(t - 0.055) * 44)
          or 0
        local shells = Synth.clicks(t, { 0.11, 0.124 }, 2600, 180, 0.11)
        return clip(lever + hinge + drop + shells)
      end
    end,
    B = function(rate)
      local walls = Synth.reflections(rate, { { 0.04, 0.2 }, { 0.083, 0.1 } })
      return function(t, noise, low)
        local lever = Synth.clicks(t, { 0 }, 2700, 380, 0.3) + noise * 0.25 * exp(-t * 650)
        local hinge = Synth.clicks(t, { 0.032 }, 760, 60, 0.34)
          + Synth.clicks(t, { 0.032 }, 1180, 95, 0.14)
        local drop = t > 0.065
            and (sin(2 * pi * 115 * (t - 0.065)) * 0.6 + low * 0.6) * exp(-(t - 0.065) * 30)
          or 0
        local shells = Synth.clicks(t, { 0.13, 0.146 }, 1900, 140, 0.1)
        return clip(walls(lever + hinge + drop + shells))
      end
    end,
  },
  {
    id = 'in1',
    duration = 0.2,
    classic = 'shellIn',
    -- One round where today's sound pushes two: half of its level.
    share = 0.75,
    A = function(rate)
      local brass = Synth.resonator(3000, 2, rate)
      return function(t, noise, low)
        local s = brass(noise) * 0.9 * min(1, t / 0.003) * exp(-t * 110)
        if t > 0.026 then
          s = s + (sin(2 * pi * 340 * (t - 0.026)) * 0.4 + low * 0.35) * exp(-(t - 0.026) * 80)
        end
        return clip(s)
      end
    end,
    B = function(rate)
      local brass = Synth.resonator(2200, 1.8, rate)
      return function(t, noise, low)
        local s = brass(noise) * 0.8 * min(1, t / 0.004) * exp(-t * 80)
        if t > 0.032 then
          s = s + (sin(2 * pi * 250 * (t - 0.032)) * 0.55 + low * 0.5) * exp(-(t - 0.032) * 60)
        end
        return clip(s)
      end
    end,
  },
  {
    id = 'in2',
    duration = 0.3,
    classic = 'shellIn',
    share = 1,
    A = function(rate)
      local brass = Synth.resonator(3000, 2, rate)
      return function(t, noise, low)
        local s = 0
        for _, at in ipairs({ 0, 0.1 }) do
          local d = t - at
          if d > 0 then
            s = s + brass(noise) * 0.9 * min(1, d / 0.003) * exp(-d * 110)
            if d > 0.026 then
              s = s + (sin(2 * pi * 340 * (d - 0.026)) * 0.4 + low * 0.35) * exp(-(d - 0.026) * 80)
            end
          end
        end
        return clip(s)
      end
    end,
    B = function(rate)
      local brass = Synth.resonator(2200, 1.8, rate)
      return function(t, noise, low)
        local s = 0
        for _, at in ipairs({ 0, 0.12 }) do
          local d = t - at
          if d > 0 then
            s = s + brass(noise) * 0.8 * min(1, d / 0.004) * exp(-d * 80)
            if d > 0.032 then
              s = s + (sin(2 * pi * 250 * (d - 0.032)) * 0.55 + low * 0.5) * exp(-(d - 0.032) * 60)
            end
          end
        end
        return clip(s)
      end
    end,
  },
  {
    id = 'close',
    duration = 0.35,
    classic = 'breakClose',
    share = 1,
    A = function()
      return function(t, noise, low, slower)
        local snap = noise * 0.8 * exp(-t * 800)
        local clunk = (sin(2 * pi * 130 * t) * 0.7 + low * 0.8) * exp(-t * 38)
          + slower * 1.2 * exp(-t * 26)
        local lock = Synth.clicks(t, { 0.01 }, 3100, 200, 0.24)
        return clip(snap + clunk + lock)
      end
    end,
    B = function(rate)
      local walls = Synth.reflections(rate, { { 0.045, 0.22 }, { 0.09, 0.1 } })
      return function(t, noise, low, slower)
        local snap = noise * 0.6 * exp(-t * 520)
        local clunk = (sin(2 * pi * 92 * t) * 0.85 + low * 1.0) * exp(-t * 26)
          + slower * 2 * exp(-t * 16)
        local lock = Synth.clicks(t, { 0.014 }, 2300, 150, 0.2)
          + Synth.clicks(t, { 0.055 }, 1400, 100, 0.06)
        return clip(walls(snap + clunk + lock))
      end
    end,
  },
  {
    id = 'dry',
    duration = 0.25,
    -- No such sound today: the level of the shut breech, a little lower.
    classic = 'breakClose',
    share = 0.6,
    A = function()
      return function(t, noise)
        return clip(
          Synth.clicks(t, { 0 }, 2900, 300, 0.4)
            + Synth.clicks(t, { 0.018 }, 4100, 500, 0.12)
            + noise * 0.2 * exp(-t * 900)
        )
      end
    end,
    B = function(rate)
      local walls = Synth.reflections(rate, { { 0.04, 0.2 } })
      return function(t, noise, low)
        return clip(
          walls(
            Synth.clicks(t, { 0 }, 2200, 240, 0.38)
              + Synth.clicks(t, { 0.022 }, 3300, 400, 0.1)
              + low * 0.4 * exp(-t * 120)
              + noise * 0.15 * exp(-t * 700)
          )
        )
      end
    end,
  },
  {
    id = 'draw',
    duration = 0.45,
    -- No such sound today: the level of the opened breech, lower.
    classic = 'breakOpen',
    share = 0.6,
    A = function()
      return function(t, _, low, _, high)
        local swish = high * 0.5 * min(1, t / 0.05) * exp(-math.max(0, t - 0.05) * 18)
        return clip(
          swish * (t < 0.2 and 1 or 0)
            + Synth.clicks(t, { 0.2 }, 1800, 140, 0.3)
            + low * 0.3 * exp(-math.max(0, t - 0.2) * 40) * (t > 0.2 and 1 or 0)
        )
      end
    end,
    B = function()
      return function(t, _, low, slower)
        local swish = low * 0.9 * min(1, t / 0.06) * exp(-math.max(0, t - 0.06) * 14)
        return clip(
          swish * (t < 0.22 and 1 or 0)
            + Synth.clicks(t, { 0.22 }, 1300, 110, 0.32)
            + slower * 1.4 * exp(-math.max(0, t - 0.22) * 22) * (t > 0.22 and 1 or 0)
        )
      end
    end,
  },
}

-- A voice as samples at rate, with the shared filtered noises of the effects
-- (low: a one-pole low-pass, slower: a slower one, high: noise minus low).
function AB.render(duration, rate, seed, voice)
  local random, low, slower, out = Synth.noise(seed), 0, 0, {}
  for i = 1, math.floor(duration * rate) do
    local t = (i - 1) / rate
    local noise = random()
    low = low * 0.74 + noise * 0.26
    slower = slower * 0.975 + noise * 0.025
    out[i] = voice(t, noise, low, slower, noise - low)
  end
  return out
end
-- A buffer brought to a root-mean-square level, its peaks under 1.
function AB.match(buffer, rms)
  return Synth.level(buffer, rms)
end
return AB
