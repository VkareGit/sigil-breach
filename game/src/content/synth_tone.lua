-- The voice of the synthesizer (audio/synth.lua): the measures that shape
-- every sound it makes. Frequencies are in Hz, times in seconds, decays per
-- second; a share is of the signal's own level.
return {
  -- One period of a wavetable (samples).
  period = 2048,
  -- Soft saturation: how early loud sums bend.
  bend = 0.55,
  -- A resonator's output is scaled to this share.
  resonatorGain = 0.5,
  -- The knight's mail: three dull partials of steel and their decay.
  mail = { decay = 55, partials = { 2350, 3110, 4170 }, gains = { 1, 0.6, 0.4 } },
  -- A click of metal: its second partial (ratio and share).
  click = { ratio = 1.47, share = 0.5 },
  -- A stone wall's reflection loses its highs: what it keeps of itself.
  reflectionKeep = 0.55,
  reflectionTake = 0.45,
  -- The shared noises of a short effect: a low one and a slower one (what
  -- each keeps and takes), and the clip.
  effect = { lowKeep = 0.74, lowTake = 0.26, slowKeep = 0.975, slowTake = 0.025, clip = 0.98 },
  -- A sung vowel: the floor of its spectrum, and each formant's half-width.
  vowel = { floor = 0.015, width = 0.5 },
  -- A voice: its default attack, release, vibrato rate and seed; how many
  -- samples share one envelope step; how long the vibrato takes to settle;
  -- the breath's low-pass (keep, take).
  voice = {
    attack = 0.08,
    release = 0.2,
    vibratoRate = 5,
    seed = 3,
    control = 32,
    settle = 0.35,
    breathKeep = 0.6,
    breathTake = 0.4,
  },
  -- A struck bell at its prime: the minor-third bell's partials (hum, prime,
  -- tierce, quint, nominal and upper) as { ratio to the prime, amplitude,
  -- decay }, each beating slowly with a twin (offset, its growth per partial,
  -- its share); the clapper's knock (level, decay).
  bell = {
    partials = {
      { 0.5, 0.42, 0.32 },
      { 1.0, 0.46, 0.55 },
      { 1.2, 0.50, 0.75 },
      { 1.5, 0.22, 1.05 },
      { 2.0, 0.58, 1.25 },
      { 2.5, 0.20, 2.0 },
      { 3.0, 0.16, 2.6 },
      { 4.0, 0.10, 3.4 },
      { 5.33, 0.07, 4.2 },
    },
    twin = 0.4,
    twinStep = 0.07,
    twinShare = 0.35,
    knock = 0.35,
    knockDecay = 90,
    seed = 5,
  },
  -- A heartbeat on a frame drum: the pitch's fall (depth, speed), the drum's
  -- second partial (share, ratio, decay), the skin's noise (low-pass keep
  -- and take, lub and dub levels, decay), the beat's gain, the dub's share
  -- and both beats' decays.
  heartbeat = {
    fall = 20,
    fallSpeed = 18,
    overtone = 0.45,
    overtoneRatio = 1.52,
    overtoneDecay = 6,
    skinKeep = 0.9,
    skinTake = 0.1,
    lub = 1.6,
    dub = 1.1,
    skinDecay = 60,
    gain = 1.5,
    dubShare = 0.62,
    lubDecay = 9,
    dubDecay = 11,
    seed = 7,
  },
  -- A stone nave's reverb (Schroeder): four damped combs and two all-passes
  -- (delay s, gain), its default size, damping and predelay, the extra tail
  -- it renders, and the share of the combs summed.
  hall = {
    combs = { 0.0353, 0.0367, 0.0338, 0.0322 },
    passes = { { 0.0126, 0.5 }, { 0.0051, 0.5 } },
    size = 1.6,
    damp = 0.3,
    predelay = 0.03,
    tail = 0.5,
    combShare = 0.25,
  },
  -- A level's peaks bend above knee into the headroom left below 1.
  level = { knee = 0.6, headroom = 0.38 },
  -- Sound data never reaches full scale.
  ceiling = 0.99,
}
