-- Sound synthesis shared by the effects (audio/recipes.lua) and the score
-- (audio/soundscape.lua): seeded noise, sung and piped wavetables, a bell's
-- strike, a stone hall's reverb and the conversion to LÖVE sound data.
-- Plain arrays of samples in, plain arrays out; nothing here plays a sound.
local Tone = require('src.content.synth_tone')
local Synth = {}
local pi, sin, exp, floor, abs, sqrt = math.pi, math.sin, math.exp, math.floor, math.abs, math.sqrt
local TAU = 2 * pi
-- One period of a wavetable (samples); tables interpolate linearly.
Synth.period = Tone.period

-- Soft saturation: loud sums bend instead of clipping.
function Synth.clip(x)
  return x / (1 + abs(x) * Tone.bend)
end

-- A seed of a name's own, so adding a sound never changes another's noise.
function Synth.seed(name)
  local h = 7
  for i = 1, #name do
    h = (h * 31 + name:byte(i)) % 2147483647 -- constant: a string hash under 2^31
  end
  return h
end

-- Park-Miller noise in [-1, 1]: exact in doubles, cheap enough per sample.
function Synth.noise(seed)
  local x = seed % 2147483646 + 1 -- constant: Park-Miller's state
  return function()
    x = x * 16807 % 2147483647 -- constant: Park-Miller's generator
    return x / 1073741823.5 - 1 -- constant: half its modulus
  end
end

-- A two-pole band-pass at f Hz (quality q) for a rate; returns a filter
-- function of one input sample. tune(f) moves its centre (a sweep).
function Synth.resonator(f, q, rate)
  local a1, a2, gain
  local y1, y2 = 0, 0
  local function tune(freq)
    local r = exp(-pi * freq / q / rate)
    a1, a2 = 2 * r * math.cos(TAU * freq / rate), -r * r
    gain = (1 - r * r) * Tone.resonatorGain
  end
  tune(f)
  return function(x)
    local y = gain * x + a1 * y1 + a2 * y2
    y2, y1 = y1, y
    return y
  end,
    tune
end

-- A ring at f Hz struck at onset (s), decaying by decay per second.
function Synth.ring(t, onset, f, decay)
  local s = t - onset
  if s < 0 then
    return 0
  end
  return sin(TAU * f * s) * exp(-s * decay)
end

-- The knight's mail shaken: small rings of steel at the given onsets (s) and
-- amplitudes, each a cluster of three dull partials.
function Synth.mail(t, onsets, amplitudes)
  local sum = 0
  for k = 1, #onsets do
    local s = t - onsets[k]
    if s > 0 then
      local M = Tone.mail
      local f, g = M.partials, M.gains
      local e = exp(-s * M.decay) * amplitudes[k]
      sum = sum
        + (g[1] * sin(TAU * f[1] * s) + g[2] * sin(TAU * f[2] * s) + g[3] * sin(TAU * f[3] * s))
          * e
    end
  end
  return sum
end

-- Small mechanical clicks of metal at the given onsets (s): a ring at f Hz
-- that dies by decay per second, each with amplitude amp (or amps[k]).
function Synth.clicks(t, onsets, f, decay, amp)
  local sum = 0
  for k = 1, #onsets do
    local s = t - onsets[k]
    if s > 0 then
      local a = type(amp) == 'table' and amp[k] or amp
      local C = Tone.click
      sum = sum + (sin(TAU * f * s) + C.share * sin(TAU * f * C.ratio * s)) * exp(-s * decay) * a
    end
  end
  return sum
end

-- Stone walls answering a sound: taps {{delay s, gain}, ...}; each reflection
-- loses its highs (a one-pole low-pass). Returns a function of one sample.
function Synth.reflections(rate, taps)
  local delays, soft, size = {}, {}, 1
  for k, tap in ipairs(taps) do
    delays[k], soft[k] = floor(tap[1] * rate), 0
    size = math.max(size, delays[k] + 1)
  end
  local history, index = {}, 0
  for i = 0, size - 1 do
    history[i] = 0
  end
  return function(x)
    history[index] = x
    local out = x
    for k, tap in ipairs(taps) do
      soft[k] = soft[k] * Tone.reflectionKeep
        + history[(index - delays[k]) % size] * Tone.reflectionTake
      out = out + soft[k] * tap[2]
    end
    index = (index + 1) % size
    return out
  end
end

-- A short effect: voice(t, u, noise, low, slower, high) sampled for its
-- duration at rate, with the shared filtered noises of the old recipes
-- (low: a one-pole low-pass, slower: a slower one, high: noise minus low).
function Synth.effect(duration, rate, seed, voice)
  local n = floor(duration * rate)
  local data = love.sound.newSoundData(n, rate, 16, 1) -- constant: 16-bit mono
  local random = Synth.noise(seed)
  local low, slower = 0, 0
  local E = Tone.effect
  for i = 0, n - 1 do
    local t = i / rate
    local noise = random()
    low = low * E.lowKeep + noise * E.lowTake
    slower = slower * E.slowKeep + noise * E.slowTake
    local sample = voice(t, t / duration, noise, low, slower, noise - low)
    data:setSample(i, math.max(-E.clip, math.min(E.clip, sample)))
  end
  return data
end

-- WAVETABLES -----------------------------------------------------------------

-- One period from harmonic amplitudes {a1, a2, ...}; phases from the seed
-- keep the crest low. Normalised to a peak of 1.
function Synth.wavetable(amplitudes, seed)
  local n, random = Synth.period, Synth.noise(seed or 1)
  local wave, peak = {}, 0
  local phases = {}
  for k = 1, #amplitudes do
    phases[k] = (random() + 1) * pi
  end
  for i = 0, n - 1 do
    local x, s = TAU * i / n, 0
    for k = 1, #amplitudes do
      local a = amplitudes[k]
      if a ~= 0 then
        s = s + a * sin(k * x + phases[k])
      end
    end
    wave[i] = s
    peak = math.max(peak, abs(s))
  end
  for i = 0, n - 1 do
    wave[i] = wave[i] / peak
  end
  wave[n] = wave[0]
  return wave
end

-- A sung vowel at f0 Hz: a glottal source (-6 dB per octave after the lips)
-- through the vowel's formants {frequency, gain dB, bandwidth}, harmonics up
-- to ceiling Hz.
function Synth.vowel(f0, formants, ceiling, seed)
  local amplitudes = {}
  for k = 1, math.max(1, floor(ceiling / f0)) do
    local f, shape = k * f0, Tone.vowel.floor
    for _, formant in ipairs(formants) do
      local width = formant[3] * Tone.vowel.width
      shape = shape + 10 ^ (formant[2] / 20) / (1 + ((f - formant[1]) / width) ^ 2) -- constant: decibels
    end
    amplitudes[k] = shape / k
  end
  return Synth.wavetable(amplitudes, seed)
end

-- A voice from a wavetable added into a looping buffer (1-based samples at
-- rate; what overruns the end wraps to the start): from start s for length s
-- (a release follows), at freq Hz and gain. Options: attack, release (s),
-- vibrato depth (share of the pitch) and rate (Hz), steady (vibrato from the
-- first sample, for a held drone), breath (noise riding the voice), swell(t)
-- (a gain over the note's own time), seed.
function Synth.voice(buffer, rate, wave, start, length, freq, gain, o)
  o = o or {}
  local V = Tone.voice
  local attack, release = o.attack or V.attack, o.release or V.release
  local depth, vrate = o.vibrato or 0, o.vibratoRate or V.vibratoRate
  local breath, swell = o.breath or 0, o.swell
  local random = Synth.noise(o.seed or V.seed)
  local vphase = (random() + 1) * pi
  local n, step = Synth.period, Synth.period / rate
  local size = #buffer
  local first = floor(start * rate)
  local total = floor((length + release) * rate)
  local phase = (random() + 1) * 0.5 * n
  local control = V.control
  local env, envNext, f, fNext
  local function at(time)
    local e = 0
    if time < attack then
      e = sin(0.5 * pi * time / attack)
    elseif time < length then
      e = 1
    elseif release > 0 then
      e = math.cos(0.5 * pi * math.min(1, (time - length) / release))
    end
    if swell then
      e = e * swell(time)
    end
    local ramp = o.steady and 1 or math.min(1, time / V.settle)
    return e, freq * (1 + depth * ramp * sin(TAU * vrate * time + vphase))
  end
  envNext, fNext = at(0)
  local dEnv, dF = 0, 0
  -- The breath is soft noise (a one-pole low-pass), not a hiss over the voice.
  local air = 0
  for j = 0, total - 1 do
    if j % control == 0 then
      env, f = envNext, fNext
      envNext, fNext = at((j + control) / rate)
      dEnv, dF = (envNext - env) / control, (fNext - f) / control
    end
    local i = floor(phase)
    local s = wave[i] + (wave[i + 1] - wave[i]) * (phase - i)
    if breath > 0 then
      air = air * V.breathKeep + random() * V.breathTake
      s = s * (1 + breath * air)
    end
    local index = (first + j) % size + 1
    buffer[index] = buffer[index] + s * env * gain
    phase = phase + f * step
    if phase >= n then
      phase = phase - n
    end
    env, f = env + dEnv, f + dF
  end
end

-- A struck bell at prime Hz: the minor-third bell's partials (hum, prime,
-- tierce, quint, nominal and upper), each beating slowly as real bells warble;
-- seconds long at rate. Returns an array of samples.
Synth.bellPartials = Tone.bell.partials
function Synth.bell(prime, seconds, rate, seed)
  local B = Tone.bell
  local samples, random = {}, Synth.noise(seed or B.seed)
  local n = floor(seconds * rate)
  -- The clapper's strike: a short knock of metal.
  for i = 1, n do
    samples[i] = random() * B.knock * exp(-(i - 1) / rate * B.knockDecay)
  end
  -- Each partial and its slow twin, as rotating oscillators (no sine per sample).
  for k, p in ipairs(Synth.bellPartials) do
    for twin = 0, 1 do
      local f = prime * p[1] + twin * (B.twin + k * B.twinStep)
      local w = TAU * f / rate
      local cw, sw = math.cos(w), sin(w)
      local c, s = 1, 0
      local a, fade = p[2] * (twin == 0 and 1 or B.twinShare), exp(-p[3] / rate)
      for i = 1, n do
        samples[i] = samples[i] + a * s
        c, s = c * cw - s * sw, s * cw + c * sw
        a = a * fade
      end
    end
  end
  local peak = 0
  for i = 1, n do
    peak = math.max(peak, abs(samples[i]))
  end
  for i = 1, n do
    samples[i] = samples[i] / peak
  end
  return samples
end

-- A heartbeat on a frame drum: lub and a softer dub (o.dub s later), at
-- o.pitch Hz, o.length s; low enough to be felt, saturated a little so small
-- speakers hear its overtones.
function Synth.heartbeat(o, rate, seed)
  local H = Tone.heartbeat
  local samples, random = {}, Synth.noise(seed or H.seed)
  local n, low, dub, pitch = floor(o.length * rate), 0, o.dub, o.pitch
  local function beat(s, depth)
    if s < 0 then
      return 0
    end
    local f = pitch + H.fall * exp(-s * H.fallSpeed)
    return (
      sin(TAU * f * s)
      + H.overtone * sin(TAU * H.overtoneRatio * f * s) * exp(-s * H.overtoneDecay)
    ) * exp(-s * depth)
  end
  for i = 1, n do
    local t = (i - 1) / rate
    low = low * H.skinKeep + random() * H.skinTake
    local skin = low * H.lub * exp(-t * H.skinDecay)
      + low * H.dub * exp(-math.max(0, t - dub) * H.skinDecay) * (t > dub and 1 or 0)
    samples[i] =
      Synth.clip(H.gain * (beat(t, H.lubDecay) + H.dubShare * beat(t - dub, H.dubDecay)) + skin)
  end
  return samples
end

-- Add samples into buffer at time (s) with gain; a buffer is a loop, so what
-- overruns its end wraps to its start.
function Synth.mix(buffer, rate, samples, time, gain)
  local n, first = #buffer, floor(time * rate)
  for i = 1, #samples do
    local index = (first + i - 1) % n + 1
    buffer[index] = buffer[index] + samples[i] * gain
  end
end

-- HALL -------------------------------------------------------------------------

-- A stone nave's reverb (Schroeder: four damped combs, two all-passes) over
-- a looping buffer: the tail that would ring past the end folds back into the
-- start, so the loop rings seamlessly (a one-shot longer than its ring folds
-- back nothing audible). o: time (RT60 s), mix (wet share), dry (the dry
-- share, 1 - mix / 2 unless given), damp (0..1), size (scales the delay
-- lines), predelay (s).
local HALL = Tone.hall
local combs, passes = HALL.combs, HALL.passes
function Synth.hall(buffer, rate, o)
  local n = #buffer
  local tail = floor(math.min(n, (o.time + HALL.tail) * rate))
  local size, damp = o.size or HALL.size, o.damp or HALL.damp
  local lines = {}
  for k, d in ipairs(combs) do
    local length = floor(d * size * rate)
    lines[k] = {
      data = {},
      length = length,
      index = 0,
      store = 0,
      feedback = 10 ^ (-3 * length / rate / o.time), -- constant: RT60, a fall of 60 dB
    }
    for i = 0, length - 1 do
      lines[k].data[i] = 0
    end
  end
  local filters = {}
  for k, p in ipairs(passes) do
    local length = floor(p[1] * rate)
    filters[k] = { data = {}, length = length, index = 0, gain = p[2] }
    for i = 0, length - 1 do
      filters[k].data[i] = 0
    end
  end
  local pre = math.max(1, floor((o.predelay or HALL.predelay) * rate))
  local wet = {}
  for i = 1, n + tail do
    local source = i - pre
    local x = (source >= 1 and source <= n) and buffer[source] or 0
    local out = 0
    for k = 1, #lines do
      local line = lines[k]
      local y = line.data[line.index]
      line.store = y * (1 - damp) + line.store * damp
      line.data[line.index] = x + line.store * line.feedback
      line.index = (line.index + 1) % line.length
      out = out + y
    end
    out = out * HALL.combShare
    for k = 1, #filters do
      local filter = filters[k]
      local delayed = filter.data[filter.index]
      local y = -out * filter.gain + delayed
      filter.data[filter.index] = out + delayed * filter.gain
      filter.index = (filter.index + 1) % filter.length
      out = y
    end
    wet[i] = out
  end
  for i = 1, tail do
    wet[i] = wet[i] + wet[n + i]
  end
  local mix = o.mix
  local dry = o.dry or (1 - mix * 0.5)
  for i = 1, n do
    buffer[i] = buffer[i] * dry + wet[i] * mix * 2
  end
end

-- LEVELS -----------------------------------------------------------------------

-- Scale a buffer to a root-mean-square level, then bend its peaks under 1.
function Synth.level(buffer, rms)
  local sum = 0
  for i = 1, #buffer do
    sum = sum + buffer[i] * buffer[i]
  end
  local now = sqrt(sum / math.max(1, #buffer))
  local scale = now > 0 and rms / now or 0
  for i = 1, #buffer do
    local x = buffer[i] * scale
    local m = abs(x)
    local L = Tone.level
    if m > L.knee then
      x = (x > 0 and 1 or -1) * (L.knee + L.headroom * math.tanh((m - L.knee) / L.headroom))
    end
    buffer[i] = x
  end
  return buffer
end

-- LÖVE sound data from a buffer of samples in [-1, 1].
function Synth.data(buffer, rate)
  local data = love.sound.newSoundData(#buffer, rate, 16, 1) -- constant: 16-bit mono
  for i = 1, #buffer do
    data:setSample(i - 1, math.max(-Tone.ceiling, math.min(Tone.ceiling, buffer[i])))
  end
  return data
end

-- A silent buffer of seconds at rate.
function Synth.buffer(seconds, rate)
  local buffer = {}
  for i = 1, floor(seconds * rate) do
    buffer[i] = 0
  end
  return buffer
end
return Synth
