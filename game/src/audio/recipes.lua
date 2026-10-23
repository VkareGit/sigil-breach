-- Every sound effect as data: its length (s) and a voice sampled at 44.1 kHz,
-- voice(t, u, noise, low, slower, high) of the time t (s), the share u of the
-- length, white noise and three filtered noises (audio/synth.lua: effect).
-- A recipe with make(rate) builds a fresh voice with its own state (filters,
-- sparks) for each render. jitter: the pitch varies by up to this share each
-- time it plays. A new sound is a new entry; the player asks only by name.
-- The knight's movement speaks the fresco's world: stone of the circles,
-- the mail he wears, breath, and the small bells of the sanctuary.
local Synth = require('src.audio.synth')
local pi, sin, exp, min, max = math.pi, math.sin, math.exp, math.min, math.max
local clip, ring, mail = Synth.clip, Synth.ring, Synth.mail
local R = {}

-- WEAPONS ------------------------------------------------------------------------
R.shot = {
  duration = 0.60,
  jitter = 0.04,
  voice = function(t, _, _, low, slower, high)
    local crack = high * 0.70 * exp(-t * 150) + low * 1.7 * exp(-t * 28)
    local body = sin(2 * pi * (74 * t + 1.2 * (1 - exp(-t * 40)))) * 0.90 * exp(-t * 22)
    local tail = slower * 3.5 * exp(-t * 8)
    local echo = (t > 0.065 and low * 0.35 * exp(-(t - 0.065) * 22) or 0)
    return clip(crack + body + tail + echo) * 0.87
  end,
}
R.revolver = {
  duration = 0.34,
  jitter = 0.04,
  voice = function(t, _, _, low, slower, high)
    local crack = high * 0.95 * exp(-t * 135) + low * 1.25 * exp(-t * 32)
    local body = sin(2 * pi * (112 * t + 0.65 * (1 - exp(-t * 35)))) * 0.55 * exp(-t * 27)
    local latch = t > 0.145
        and (high * 0.28 + sin(2 * pi * 1850 * t) * 0.12) * exp(-(t - 0.145) * 90)
      or 0
    return clip(crack + body + slower * 2.2 * exp(-t * 12) + latch) * 0.82
  end,
}
R.shell = {
  duration = 0.12,
  voice = function(t, _, _, _, _, high)
    return (high * 0.28 + sin(2 * pi * 2450 * t) * 0.16 + sin(2 * pi * 3470 * t) * 0.1)
      * exp(-t * 65)
  end,
}
R.empty = {
  duration = 0.08,
  voice = function(t, u, _, low)
    return (low * 0.7 + sin(2 * pi * 90 * t) * 0.4) * exp(-u * 7)
  end,
}
-- The breech: open, load and close, each a click of its own pitch.
local function breech(f)
  return function(t, _, _, _, _, high)
    local pulse = exp(-t * 75) + (t > 0.045 and 0.65 * exp(-(t - 0.045) * 95) or 0)
    return (high * 0.60 + sin(2 * pi * f * t) * 0.20 + sin(2 * pi * f * 1.41 * t) * 0.12) * pulse
  end
end
R.open = { duration = 0.16, voice = breech(1100) }
R.load = { duration = 0.18, voice = breech(1850) }
R.close = { duration = 0.17, voice = breech(760) }

-- HITS AND KILLS -----------------------------------------------------------------
R.hit = {
  duration = 0.14,
  jitter = 0.04,
  voice = function(t, _, _, low)
    return (low * 0.85 + sin(2 * pi * 115 * t) * 0.4) * exp(-t * 40)
  end,
}
R.heavyhit = {
  duration = 0.19,
  voice = function(t, _, _, low)
    return (low * 1.25 + sin(2 * pi * (95 * t - 90 * t * t)) * 0.65) * exp(-t * 32)
  end,
}
R.graze = {
  duration = 0.09,
  voice = function(t, _, _, _, _, high)
    return (high * 0.38 + sin(2 * pi * 370 * t) * 0.12) * exp(-t * 60)
  end,
}
R.kill = {
  duration = 0.42,
  jitter = 0.04,
  voice = function(t, _, _, low, slower)
    return (slower * 2.8 + low * 0.8) * exp(-t * 12)
  end,
}
R.multikill = {
  duration = 0.33,
  voice = function(t)
    return (sin(2 * pi * 330 * t) * 0.18 + sin(2 * pi * 495 * t) * 0.12) * exp(-t * 14)
  end,
}
R.hurt = { duration = 0.25, voice = R.empty.voice }
-- Weight cues (feedback/weight.lua): a passing projectile, a precise hit, a
-- broken guard, a body against stone.
R.whoosh = {
  duration = 0.34,
  voice = function(t, u, _, low, _, high)
    local swell = sin(pi * u) ^ 2
    return (low * 0.55 + high * 0.22 * (1 - u)) * swell * (0.6 + 0.4 * sin(2 * pi * (9 * t)))
  end,
}
R.crit = {
  duration = 0.24,
  voice = function(t, _, _, _, _, high)
    return (
      sin(2 * pi * 1320 * t) * 0.22
      + sin(2 * pi * 1980 * t) * 0.10
      + high * 0.20 * exp(-t * 90)
    ) * exp(-t * 16)
  end,
}
R['break'] = {
  duration = 0.28,
  voice = function(t, _, _, low, _, high)
    return clip(
      low * 1.5 * exp(-t * 26)
        + sin(2 * pi * (68 * t - 40 * t * t)) * 0.75 * exp(-t * 15)
        + high * 0.55 * exp(-t * 110)
        + sin(2 * pi * 820 * t) * 0.10 * exp(-t * 30)
    ) * 0.85
  end,
}
R.thud = {
  duration = 0.36,
  voice = function(t, _, _, low, slower)
    return clip(
      sin(2 * pi * (52 * t - 26 * t * t)) * 0.95 * exp(-t * 12)
        + low * 1.1 * exp(-t * 24)
        + slower * 2 * exp(-t * 8)
    ) * 0.85
  end,
}
-- The stone hall answers a shot: three dark reflections and a long bloom.
R.hall = {
  duration = 1.4,
  voice = function(t, _, _, low, slower)
    local bloom = slower * 2.6 * (1 - exp(-t * 30)) * exp(-t * 2.8)
    local echo = 0
    for k, d in ipairs({ 0.085, 0.17, 0.29 }) do
      if t > d then
        echo = echo + low * (0.55 / k) * exp(-(t - d) * 14)
      end
    end
    return clip(bloom + echo) * 0.75
  end,
}
-- The hero's heart under 30 HP: a muffled double beat.
R.heart = {
  duration = 0.42,
  voice = function(t, _, _, low)
    local function beat(s)
      return s > 0 and sin(2 * pi * (46 * s)) * exp(-s * 22) + low * 0.35 * exp(-s * 40) or 0
    end
    return clip(beat(t) * 0.9 + beat(t - 0.17) * 0.65) * 0.9
  end,
}

-- DEMONS -------------------------------------------------------------------------
local function growl(f)
  return function(t, u, _, low)
    return clip(
      (sin(2 * pi * (f * t - 15 * t * t)) * 0.5 + low * 0.5) * (1 + 0.4 * sin(2 * pi * 26 * t))
    ) * sin(pi * u) * 0.7
  end
end
R.snarl = { duration = 0.55, voice = growl(87) }
R.growl = { duration = 0.7, voice = growl(58) }
R.owl = {
  duration = 0.65,
  voice = function(t, u)
    return (sin(2 * pi * (430 * t - 140 * t * t)) * 0.4 + sin(2 * pi * 650 * t) * 0.12)
      * sin(pi * u)
  end,
}
R.cast = {
  duration = 0.50,
  voice = function(t, u, _, _, slower, high)
    return clip(
      (slower * 2.2 + sin(2 * pi * (72 * t + 22 * t * t)) * 0.24 + high * 0.08)
        * sin(pi * u)
        * (0.4 + u)
    ) * 0.65
  end,
}
local function rake(f)
  return function(t, u, _, low)
    return (low * 0.8 + sin(2 * pi * f * t) * 0.15) * sin(pi * u) * exp(-u * 3)
  end
end
R.claw = { duration = 0.25, voice = rake(190) }
R.antler = { duration = 0.36, voice = rake(103) }
local function blast(tailDecay)
  return function(t, _, _, low, slower, high)
    local attack = high * 0.8 * exp(-t * 100) + low * 1.5 * exp(-t * 22)
    local body = sin(2 * pi * (48 * t + 0.9 * (1 - exp(-t * 25)))) * 0.8 * exp(-t * 9)
    local tail = slower * 4 * exp(-t * tailDecay)
    return clip(attack + body + tail) * 0.84
  end
end
R.blast = { duration = 0.95, voice = blast(5) }
R.thunder = { duration = 1.1, voice = blast(3.4) }
R.pulse = {
  duration = 0.8,
  voice = function(t, u, _, low)
    return (sin(2 * pi * (60 * t - 20 * t * t)) * 0.7 + low * 0.45) * sin(pi * u) * exp(-u * 3)
  end,
}

-- SANCTUARY ----------------------------------------------------------------------
local function chime(f)
  return function(t, u)
    return (sin(2 * pi * f * t) + 0.4 * sin(2 * pi * f * 1.5 * t)) * 0.3 * sin(pi * u) * exp(-u * 3)
  end
end
R.seal = { duration = 1.2, voice = chime(220) }
R.pickup = { duration = 0.30, voice = chime(660) }
-- A zone's bell: a church bell far off, tuned to the score's fifth (A).
R.bell = {
  duration = 2.4,
  make = function(rate)
    local strike = Synth.bell(220, 2.4, rate, Synth.seed('zone bell'))
    return function(t)
      return (strike[math.floor(t * rate) + 1] or 0) * 0.55
    end
  end,
}

-- THE KNIGHT'S MOVEMENT ----------------------------------------------------------
-- A footfall: boot on stone, the mail's faint dull ring.
R.step = {
  duration = 0.10,
  jitter = 0.04,
  voice = function(t, _, _, low, slower)
    local sample = (low * 0.6 + slower * 2 + sin(2 * pi * 95 * t) * 0.2) * exp(-t * 40)
    if t > 0.018 then
      sample = sample
        + (sin(2 * pi * 2350 * t) + 0.6 * sin(2 * pi * 3110 * t)) * 0.022 * exp(-(t - 0.018) * 48)
    end
    return sample
  end,
}
-- The dodge: a boot kicks off the stone, air tears past and falls away
-- behind, the mail shakes after.
R.dash = {
  duration = 0.34,
  make = function(rate)
    local air, tune = Synth.resonator(1500, 1.6, rate)
    return function(t, u, noise, low, slower)
      tune(1500 - 1000 * u)
      local rush = air(noise) * 0.7 * sin(pi * min(1, u * 1.4)) ^ 2
      local push = sin(2 * pi * (68 * t - 55 * t * t)) * 0.5 * exp(-t * 28)
        + low * 0.45 * exp(-t * 35)
      local rattle = mail(t, { 0.012, 0.05, 0.095, 0.15 }, { 0.07, 0.05, 0.035, 0.02 })
      return clip(rush + push + rattle + slower * 1.5 * sin(pi * u)) * 0.6
    end
  end,
}
-- The perfect dodge: the shade the knight leaves behind. The sanctuary's
-- small bells shaken once, a whispered breath, a weight that stops time.
local sanctus = { { 1568, 0 }, { 1760, 0.035 }, { 2093, 0.07 }, { 1568, 0.13 }, { 1760, 0.17 } }
R.afterimage = {
  duration = 1.3,
  make = function(rate)
    local first, second = Synth.resonator(650, 5, rate), Synth.resonator(1080, 6, rate)
    return function(t, _, noise, low)
      local bells = 0
      for k, b in ipairs(sanctus) do
        local f, at = b[1], b[2]
        bells = bells
          + (k > 3 and 0.5 or 1)
            * (ring(t, at, f, 6) + 0.5 * ring(t, at, f * 2.76, 11) + 0.25 * ring(t, at, f * 5.4, 18))
      end
      local whisper = (first(noise) * 1.2 + second(noise) * 0.8) * min(1, t / 0.12) * exp(-t * 2.6)
      local weight = sin(2 * pi * 55 * t) * exp(-t * 7) * 0.4 + low * 0.3 * exp(-t * 25)
      return clip(bells * 0.16 + whisper * 0.9 + weight) * 0.9
    end
  end,
}
-- The slide: greaves grind over the stone of the circle; sparks crack off it.
R.slide = {
  duration = 0.52,
  make = function(rate)
    local grind, scrape = Synth.resonator(1900, 2.2, rate), Synth.resonator(620, 1.4, rate)
    local spark, fade = 0, exp(-1 / (0.004 * rate))
    return function(t, u, noise, low, slower, high)
      local envelope = min(1, t / 0.025) * (1 - u) ^ 1.3
      local chatter = 0.55 + 0.45 * sin(2 * pi * 31 * t + 2.5 * sin(2 * pi * 7 * t))
      local stone = (grind(noise) * 0.5 + scrape(noise) * 0.7) * chatter
      if noise > 0.997 then
        spark = 1
      end
      spark = spark * fade
      local sparks = (high * 0.6 + sin(2 * pi * 5300 * t) * 0.25) * spark * (1 - u)
      return clip((stone + low * 0.35 + slower * 1.2) * envelope + sparks) * 0.8
    end
  end,
}
-- The jump: a boot's push, a short breath, the mail lifting.
R.jump = {
  duration = 0.2,
  make = function(rate)
    local breath = Synth.resonator(1300, 1.3, rate)
    return function(t, _, noise, low)
      local push = sin(2 * pi * (82 * t - 90 * t * t)) * 0.55 * exp(-t * 34)
        + low * 0.5 * exp(-t * 45)
      local huff = breath(noise) * 0.35 * min(1, t / 0.012) * exp(-t * 22)
      return clip(push + huff + mail(t, { 0.018, 0.055 }, { 0.05, 0.03 })) * 0.85
    end
  end,
}
-- The landing: an armoured body meets stone; grit, the mail crashes down.
R.land = {
  duration = 0.32,
  voice = function(t, _, _, low, slower, high)
    local body = sin(2 * pi * (62 * t - 40 * t * t)) * 0.8 * exp(-t * 16)
    local stone = low * 0.9 * exp(-t * 30) + slower * 2 * exp(-t * 12) + high * 0.16 * exp(-t * 45)
    local crash = mail(t, { 0.006, 0.022, 0.042, 0.07, 0.11 }, { 0.09, 0.07, 0.055, 0.04, 0.025 })
    return clip(body + stone + crash) * 0.85
  end,
}
-- The powder charge thrown: the arm's swing, the clay flask knocking off its
-- strap, the fuse catching.
R.throw = {
  duration = 0.32,
  make = function(rate)
    local fizz = Synth.resonator(3600, 1.5, rate)
    return function(t, u, noise, low, _, high)
      local swing = (low * 0.5 + high * 0.1) * sin(pi * u) ^ 2
      local flask = ring(t, 0, 820, 60) * 0.12 + ring(t, 0, 1340, 75) * 0.06
      local catch = fizz(noise)
        * 0.5
        * max(0, min(1, (t - 0.06) / 0.08))
        * (0.7 + 0.3 * sin(2 * pi * 47 * t))
      return clip(swing + flask + catch * (1 - u)) * 0.85
    end
  end,
}
-- The lit fuse in flight: a hiss with crackles, fading as the charge flies.
R.fuse = {
  duration = 1.0,
  make = function(rate)
    local hiss = Synth.resonator(4200, 1.2, rate)
    local pop, fade = 0, exp(-1 / (0.003 * rate))
    return function(t, u, noise, _, _, high)
      if noise > 0.996 then
        pop = 1
      end
      pop = pop * fade
      local s = hiss(noise) * 0.35 * (0.75 + 0.25 * sin(2 * pi * 13 * t)) + high * pop * 0.5
      return s * min(1, t / 0.03) * (1 - u) ^ 1.5
    end
  end,
}
return R
