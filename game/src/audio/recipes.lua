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

-- One dry swallow: a low throat pulse, liquid knocking inside clay, then
-- a short breath. No bell, shimmer or long electronic tail.
R.flaskSip = {
  duration = 0.19,
  jitter = 0.015,
  make = function(rate)
    local throat = Synth.resonator(310, 1.2, rate)
    return function(t, u, noise, low)
      local first = exp(-((t - 0.035) / 0.018) ^ 2)
      local second = exp(-((t - 0.095) / 0.026) ^ 2)
      local gulp = throat(low) * (first * 0.48 + second * 0.30)
      local clay = ring(t, 0.018, 690, 85) * 0.055
      local breath = noise * 0.025 * sin(pi * u) ^ 2
      return clip(gulp + clay + breath) * (1 - u)
    end
  end,
}

-- WEAPONS ------------------------------------------------------------------------
-- Black powder in a stone nave: a heavy report, its smoke still crackling,
-- the walls answering a moment later (the long ring is R.hall).

-- The Exorcist: both barrels at once, a hair apart (ka-BOOM): the crack of
-- each, the powder's blast and its burning crackle, a falling sub thump.
R.shot = {
  duration = 0.9,
  jitter = 0.04,
  make = function(rate)
    local boom, walls =
      Synth.resonator(520, 0.9, rate), Synth.reflections(rate, {
        { 0.047, 0.34 },
        { 0.093, 0.22 },
        { 0.141, 0.12 },
      })
    local crackle, fade = 0, exp(-1 / (0.0015 * rate))
    return function(t, _, noise, low, slower, high)
      local crack = noise * exp(-t * 900)
        + (t > 0.006 and noise * 0.75 * exp(-(t - 0.006) * 900) or 0)
      local blast = low * 1.5 * exp(-t * 26) + boom(noise) * 2.2 * exp(-t * 17)
      local body = sin(2 * pi * (48 * t + 1.4 * (1 - exp(-t * 30)))) * 0.9 * exp(-t * 13)
      if noise > 0.993 and t < 0.25 then
        crackle = 1
      end
      crackle = crackle * fade
      local powder = high * crackle * 0.6 * exp(-t * 9)
      local dry = crack * 0.7 + blast + body + powder + slower * 3.2 * exp(-t * 4.5)
      return clip(walls(dry)) * 0.55
    end
  end,
}
-- The Judge: one heavy round, a sharp crack, the iron frame ringing, the
-- cylinder turning to the next chamber.
R.revolver = {
  duration = 0.55,
  jitter = 0.04,
  make = function(rate)
    local snap, walls =
      Synth.resonator(1800, 1.4, rate), Synth.reflections(rate, {
        { 0.041, 0.26 },
        { 0.087, 0.15 },
      })
    return function(t, _, noise, low, slower, high)
      local crack = noise * exp(-t * 1100)
        + high * 0.85 * exp(-t * 120)
        + snap(noise) * 1.6 * exp(-t * 60)
      local body = sin(2 * pi * (85 * t + 0.9 * (1 - exp(-t * 35)))) * 0.6 * exp(-t * 24)
        + low * 1.1 * exp(-t * 30)
      local frame = (
        sin(2 * pi * 2650 * t)
        + 0.5 * sin(2 * pi * 3920 * t)
        + 0.3 * sin(2 * pi * 5300 * t)
      )
        * 0.09
        * exp(-t * 35)
      local turn = Synth.clicks(t, { 0.15, 0.172 }, 1850, 260, { 0.16, 0.08 })
      local dry = crack * 0.8 + body + frame + turn + slower * 2.4 * exp(-t * 9)
      return clip(walls(dry)) * 0.7
    end
  end,
}
-- RELOADS (content/tuning.lua reload.<mechanism>.voices names them).
-- The Exorcist's breech: the lever thrown, the barrels dropping on the
-- hinge, the spent shells drawn out.
R.breakOpen = {
  duration = 0.32,
  voice = function(t, _, noise, low)
    local lever = Synth.clicks(t, { 0 }, 3100, 420, 0.32) + noise * 0.35 * exp(-t * 700)
    local hinge = Synth.clicks(t, { 0.03 }, 920, 70, 0.3)
      + Synth.clicks(t, { 0.03 }, 1430, 110, 0.14)
    local drop = t > 0.06
        and (sin(2 * pi * 140 * (t - 0.06)) * 0.5 + low * 0.5) * exp(-(t - 0.06) * 38)
      or 0
    local shells = Synth.clicks(t, { 0.12, 0.135 }, 2300, 160, 0.1)
    return clip(lever + hinge + drop + shells) * 0.85
  end,
}
-- Two shells pushed home: a short scrape of paper and brass, a dull seat.
R.shellIn = {
  duration = 0.26,
  make = function(rate)
    local brass = Synth.resonator(2600, 2, rate)
    return function(t, _, noise, low)
      local s = 0
      for _, at in ipairs({ 0, 0.11 }) do
        local d = t - at
        if d > 0 then
          s = s + brass(noise) * 0.9 * min(1, d / 0.004) * exp(-d * 90)
          if d > 0.03 then
            s = s + (sin(2 * pi * 310 * (d - 0.03)) * 0.45 + low * 0.4) * exp(-(d - 0.03) * 70)
          end
        end
      end
      return clip(s) * 1.0
    end
  end,
}
-- The breech snapped shut: a hard clunk, the lock biting.
R.breakClose = {
  duration = 0.3,
  voice = function(t, _, noise, low, slower)
    local snap = noise * 0.7 * exp(-t * 600)
    local clunk = (sin(2 * pi * (110 * t)) * 0.75 + low * 0.9) * exp(-t * 32)
      + slower * 1.6 * exp(-t * 20)
    local lock = Synth.clicks(t, { 0.012 }, 2800, 180, 0.22)
      + Synth.clicks(t, { 0.05, 0.075 }, 1700, 120, 0.06)
    return clip(snap + clunk + lock) * 0.53
  end,
}
-- The Judge's cylinder swung out on its crane: the latch, the free spin, the
-- clank at the stop, the empty cases falling out.
R.gateOpen = {
  duration = 0.42,
  voice = function(t, _, noise, low)
    local latch = Synth.clicks(t, { 0 }, 3400, 380, 0.26) + noise * 0.25 * exp(-t * 800)
    local spin = Synth.clicks(
      t,
      { 0.03, 0.048, 0.07, 0.096, 0.127 },
      4200,
      520,
      { 0.08, 0.07, 0.06, 0.05, 0.04 }
    )
    local stop = t > 0.15
        and (sin(2 * pi * 230 * (t - 0.15)) * 0.4 + low * 0.35) * exp(-(t - 0.15) * 45)
      or 0
    local cases = Synth.clicks(t, { 0.24, 0.262, 0.279, 0.3, 0.318, 0.34 }, 3600, 140, 0.07)
    return clip(latch + spin + stop + Synth.clicks(t, { 0.15 }, 1300, 90, 0.15) + cases) * 1.0
  end,
}
-- Rounds dropped into the chambers: soft brass clicks, the last one seated.
R.roundsIn = {
  duration = 0.3,
  voice = function(t, _, _, low)
    local drops = Synth.clicks(t, { 0, 0.045, 0.085, 0.12 }, 3300, 220, { 0.1, 0.09, 0.1, 0.08 })
    local seat = t > 0.16
        and (sin(2 * pi * 420 * (t - 0.16)) * 0.3 + low * 0.3) * exp(-(t - 0.16) * 60)
      or 0
    return clip(drops * 1.6 + seat * 1.4) * 0.95
  end,
}
-- The cylinder slapped home: a clank, the ratchet spinning down, the latch.
R.cylinderClose = {
  duration = 0.36,
  voice = function(t, _, noise, low)
    local slap = noise * 0.5 * exp(-t * 650)
      + (sin(2 * pi * 180 * t) * 0.6 + low * 0.7) * exp(-t * 36)
    local ring = (sin(2 * pi * 2200 * t) + 0.6 * sin(2 * pi * 3300 * t)) * 0.06 * exp(-t * 28)
    local ratchet = Synth.clicks(t, { 0.03, 0.05, 0.074, 0.103, 0.138, 0.18 }, 4400, 600, 0.07)
    local latch = Synth.clicks(t, { 0.23 }, 2900, 300, 0.14)
    return clip(slap + ring + ratchet + latch) * 0.66
  end,
}
R.shell = {
  duration = 0.12,
  voice = function(t, _, _, _, _, high)
    return (high * 0.28 + sin(2 * pi * 2450 * t) * 0.16 + sin(2 * pi * 3470 * t) * 0.1)
      * exp(-t * 65)
  end,
}
-- A pull on an empty chamber: the hammer falls on nothing.
R.empty = {
  duration = 0.12,
  voice = function(t, _, noise, low)
    local hammer = Synth.clicks(t, { 0 }, 2900, 260, 0.3) + noise * 0.3 * exp(-t * 900)
    return clip(hammer * 1.5 + (sin(2 * pi * 260 * t) * 0.35 + low * 0.45) * exp(-t * 70)) * 0.9
  end,
}

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
R.hurt = {
  duration = 0.25,
  voice = function(t, u, _, low)
    return (low * 0.7 + sin(2 * pi * 90 * t) * 0.4) * exp(-u * 7)
  end,
}
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
-- The nave answers a shot: a dark burst of powder rung through the stone
-- hall's reverb (Synth.hall), only its wet tail, a long low bloom.
R.hall = {
  duration = 2.2,
  make = function(rate)
    local tail, random, low = Synth.buffer(2.2, rate), Synth.noise(Synth.seed('hall burst')), 0
    for i = 1, math.floor(0.08 * rate) do
      low = low * 0.8 + random() * 0.2
      tail[i] = low * exp(-(i - 1) / rate * 40)
    end
    Synth.hall(
      tail,
      rate,
      { time = 2.4, mix = 1, dry = 0, damp = 0.5, size = 1.8, predelay = 0.035 }
    )
    local peak = 0
    for i = 1, #tail do
      peak = max(peak, math.abs(tail[i]))
    end
    return function(t)
      return (tail[math.floor(t * rate) + 1] or 0) / peak * 0.5
    end
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
-- Distinct material/weight cues. Kept as recipes so adding a creature changes
-- its sound data, not an audio switch on its name.
local function foot(pitch, metal, wet)
  return {
    duration = 0.38,
    jitter = 0.045,
    priority = 0,
    voice = function(t, _, noise, low, slower)
      local body = sin(2 * pi * pitch * t) * exp(-t * 18) * 0.38
      local grit = low * exp(-t * 40) * 0.25 + slower * exp(-t * 15) * 0.8
      return clip(
        body
          + grit
          + metal * mail(t, { 0.01, 0.04, 0.085 }, { 0.08, 0.04, 0.02 })
          + wet * noise * sin(2 * pi * 37 * t) ^ 2 * exp(-t * 25) * 0.16
      )
    end,
  }
end
R.cloven_step, R.iron_step = foot(115, 0, 0), foot(75, 1, 0)
R.flesh_step, R.heavy_step = foot(90, 0, 1), foot(42, 0.25, 0)
R.wing_fold = {
  duration = 0.5,
  priority = 0,
  voice = function(t, u, _, low, _, high)
    return (low * 0.3 + high * 0.04) * sin(pi * u) ^ 2 * exp(-t * 3)
  end,
}
R.ember_warning = {
  duration = 0.65,
  priority = 3,
  make = function(rate)
    local throat = Synth.resonator(310, 3.5, rate)
    return function(t, u, noise, low)
      return clip(
        (throat(noise) * 0.9 + low * 0.45 + sin(2 * pi * 67 * t) * 0.15)
          * min(1, t / 0.025)
          * (0.3 + 0.7 * u)
          * min(1, (1 - u) * 15)
      )
    end
  end,
}
R.storm_warning = {
  duration = 0.65,
  priority = 3,
  make = function(rate)
    local air = Synth.resonator(1600, 2, rate)
    return function(t, u, noise)
      return clip(
        (air(noise) * 0.5 + sin(2 * pi * (360 * t + 180 * t * t)) * 0.16)
          * min(1, t / 0.04)
          * (0.35 + 0.65 * u)
          * min(1, (1 - u) * 20)
      )
    end
  end,
}
R.ember_flight = {
  duration = 0.38,
  priority = 0,
  voice = function(_, u, _, low, _, high)
    return (low * 0.4 + high * 0.1) * sin(pi * u) ^ 2
  end,
}
R.ember_impact = {
  duration = 0.45,
  priority = 1,
  voice = function(t, _, noise, low, slower)
    return clip(noise * 0.12 * exp(-t * 90) + low * 0.65 * exp(-t * 18) + slower * exp(-t * 8))
      * 0.6
  end,
}
R.crypt_drip = {
  duration = 1.2,
  priority = 0,
  make = function(rate)
    local hall = Synth.reflections(rate, { { 0.11, 0.38 }, { 0.24, 0.22 }, { 0.43, 0.09 } })
    return function(t)
      return hall(sin(2 * pi * (1400 * t - 420 * t * t)) * exp(-t * 65) * 0.22)
    end
  end,
}
for _, name in ipairs({ 'shot', 'revolver', 'blast', 'thunder', 'afterimage' }) do
  R[name].priority = 2
end
for _, voices in ipairs({
  'src.audio.ritual_voices',
  'src.audio.owl_voices',
  'src.audio.iron_voices',
  'src.audio.ember_voices',
  'src.audio.furfur_voices',
  'src.audio.garden_voices',
  'src.audio.medal_voices',
  'src.audio.hit_voices',
}) do
  for name, recipe in pairs(require(voices)) do
    assert(not R[name], 'duplicate sound recipe ' .. name)
    R[name] = recipe
  end
end
return R
