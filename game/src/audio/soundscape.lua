-- The music: the score's layers (audio/score.lua) rendered once when the game
-- starts, played together as aligned loops, and mixed by the mood of the
-- session: the menu's chant, the calm of a circle, the fight as danger nears,
-- the guardian's knell, death. Reads the session; never changes it.
local Pools = require('src.session.world')
local Synth = require('src.audio.synth')
local Score = require('src.audio.score')
local Queries = require('src.session.queries')
local Scene = require('src.audio.scene')
local scene = {}
local S = { intensity = 0, music = 0.65, layers = {}, gains = {}, sources = {} }
local floor = math.floor
local duckRates = { rise = 2.5, fall = 18 }
local sceneRates = { rise = 0.8, fall = 1.5 }
S.sceneRates = sceneRates

-- A note's frequency: 'Bb1', 'D3'...
function S.pitch(name)
  local letter, octave = name:match('^(%a+)(%-?%d+)$')
  local ratio = assert(Score.ratios[letter], 'unknown note ' .. name)
  return Score.tonic * 2 ^ (tonumber(octave) - 3) * ratio
end

-- The vowel a syllable sings: its last ('y' sings as 'i').
local function vowel(syllable)
  local last = syllable:lower():match('.*([aeiouy])')
  return last == 'y' and 'i' or last or 'a'
end

-- The chant as a timeline of notes {start, units, freq, vowel, line, place}
-- (start and units in units), its lines {start, units} and its length.
function S.timeline()
  local notes, lines, at = {}, {}, 0
  for index, line in ipairs(Score.chant) do
    local words = {}
    for word in line.words:gmatch('%S+') do
      words[#words + 1] = word
    end
    local start, sung, count = at, 0, #words
    for token in line.notes:gmatch('%S+') do
      if token == '-' then
        at = at + 1
      else
        local name, units = token:match('^([^:]+):?(%d*)$')
        units = tonumber(units) or 1
        sung = sung + 1
        notes[#notes + 1] = {
          start = at,
          units = units,
          freq = S.pitch(name),
          vowel = vowel(assert(words[sung], 'a note without a syllable in line ' .. index)),
          line = index,
          place = (sung - 1) / math.max(1, count - 1),
        }
        at = at + units
      end
    end
    lines[index] = { start = start, units = at - start }
  end
  return notes, lines, at
end

-- RENDERING ------------------------------------------------------------------------

local tables = {}
local function sung(freq, name)
  local key = name .. string.format('%.1f', freq)
  if not tables[key] then
    tables[key] = Synth.vowel(freq, Score.vowels[name], Score.ceiling, Synth.seed(key))
  end
  return tables[key]
end
local function organ()
  if not tables.organ then
    tables.organ = Synth.wavetable(Score.organ, Synth.seed('organ'))
  end
  return tables.organ
end

-- A frequency the loop holds a whole number of cycles of, so a held tone
-- meets itself at the seam.
local function periodic(freq, loop)
  return math.max(1, floor(freq * loop + 0.5)) / loop
end

-- A singer of the ison breathes `breaths` times a loop, at his own moments.
local function breathing(loop, breaths, offset)
  local period = loop / breaths
  return function(t)
    local d = (t - offset) % period
    d = math.min(d, period - d)
    local dip = d < 0.45 and 0.5 + 0.5 * math.cos(math.pi * d / 0.45) or 0
    return (1 - 0.8 * dip) * (1 + 0.12 * math.sin(2 * math.pi * t / loop + offset))
  end
end

local kinds = {}
-- A held chord of the choir across the whole loop.
function kinds.drone(buffer, layer, loop)
  local rate, voice = Score.rate, Score.voice
  for n, name in ipairs(layer.notes) do
    local base = S.pitch(name)
    local wave = sung(base, layer.vowel)
    for k = 1, layer.singers do
      local cents = (k - (layer.singers + 1) / 2) * voice.spread
      Synth.voice(buffer, rate, wave, 0, loop, periodic(base * 2 ^ (cents / 1200), loop), 1, {
        attack = 0,
        release = 0,
        steady = true,
        vibrato = voice.vibrato * 0.6,
        vibratoRate = periodic(voice.vibratoRate + k * voice.vibratoStep, loop),
        breath = voice.breath,
        swell = breathing(loop, layer.breaths, (k * 2.3 + n * 1.1) % (loop / layer.breaths)),
        seed = Synth.seed(layer.id .. name .. k),
      })
    end
  end
end
-- The chant (or a choir a fixed interval from it), each note a syllable, and
-- an organ doubling it.
function kinds.chant(buffer, layer, _, notes)
  local rate, unit, voice = Score.rate, Score.unit, Score.voice
  local interval = layer.interval or 1
  for index, note in ipairs(notes) do
    local freq = note.freq * interval
    local wave = sung(freq, note.vowel)
    local start, length = note.start * unit, note.units * unit + voice.legato
    -- A line rises to its middle and settles on its final.
    local gain = 0.82 + 0.18 * math.sin(math.pi * note.place)
    for k = 1, layer.singers do
      local cents = (k - (layer.singers + 1) / 2) * voice.spread
      Synth.voice(
        buffer,
        rate,
        wave,
        start + (k - 1) * voice.stagger,
        length,
        freq * 2 ^ (cents / 1200),
        gain,
        {
          attack = voice.attack,
          release = voice.release,
          vibrato = voice.vibrato,
          vibratoRate = voice.vibratoRate + k * voice.vibratoStep,
          breath = voice.breath,
          seed = Synth.seed(layer.id .. index .. ':' .. k),
        }
      )
    end
    if layer.organ then
      Synth.voice(
        buffer,
        rate,
        organ(),
        start,
        length,
        note.freq * layer.organ.ratio,
        gain * layer.organ.gain,
        {
          attack = 0.05,
          release = 0.18,
          seed = Synth.seed(layer.id .. index .. 'organ'),
        }
      )
    end
  end
end
-- The heartbeat each unit, a deeper stroke at each line.
function kinds.pulse(buffer, layer, _, _, lines, units)
  local rate, unit = Score.rate, Score.unit
  local beat = Synth.heartbeat(layer.beat, rate, Synth.seed(layer.id .. 'beat'))
  local deep = Synth.heartbeat(layer.line, rate, Synth.seed(layer.id .. 'line'))
  for u = 0, units - 1 do
    Synth.mix(buffer, rate, beat, u * unit, 0.75)
  end
  for _, line in ipairs(lines) do
    Synth.mix(buffer, rate, deep, line.start * unit, layer.line.gain)
  end
end
-- Bells struck on their units over the organ's chord of each line.
function kinds.knell(buffer, layer, _, _, lines, units)
  local rate, unit = Score.rate, Score.unit
  for index, bell in ipairs(layer.bells) do
    local strike = Synth.bell(S.pitch(bell.prime), bell.ring, rate, Synth.seed(layer.id .. index))
    for u = bell.at, units - 1, bell.every do
      Synth.mix(buffer, rate, strike, u * unit, bell.gain)
    end
  end
  for index, chord in ipairs(layer.chords) do
    local line = lines[index]
    for name in chord:gmatch('%S+') do
      for rank, detune in ipairs({ 0, 3 }) do
        Synth.voice(
          buffer,
          rate,
          organ(),
          line.start * unit,
          line.units * unit,
          S.pitch(name) * 2 ^ (detune / 1200),
          layer.organ / rank,
          { attack = 0.12, release = 0.4, seed = Synth.seed(layer.id .. chord .. name .. rank) }
        )
      end
    end
  end
end
S.kinds = kinds

-- Every layer of the score as a buffer of samples: { [id] = buffer }, the
-- loop's length (s) and the rate. Deterministic: the same score, the same sound.
function S.render(checkpoint)
  local notes, lines, units = S.timeline()
  local loop, rate = units * Score.unit, Score.rate
  local buffers = {}
  for _, layer in ipairs(Score.layers) do
    local buffer = Synth.buffer(loop, rate)
    assert(kinds[layer.kind], 'unknown score layer kind ' .. tostring(layer.kind))(
      buffer,
      layer,
      loop,
      notes,
      lines,
      units
    )
    Synth.hall(buffer, rate, layer.hall)
    buffers[layer.id] = Synth.level(buffer, layer.level)
    if checkpoint then
      checkpoint('score ' .. layer.id)
    end
  end
  return buffers, loop, rate
end

function S.release()
  for _, source in ipairs(S.sources) do
    source:stop()
    source:release()
  end
  S.layers, S.gains, S.sources, S.intensity = {}, {}, {}, 0
  S.duck = 1
  scene = {}
end
function S.init(checkpoint)
  S.release()
  local buffers, _, rate = S.render(checkpoint)
  local sources = {}
  for _, layer in ipairs(Score.layers) do
    local data = Synth.data(buffers[layer.id], rate)
    local source = love.audio.newSource(data, 'static')
    data:release()
    source:setLooping(true)
    source:setVolume(0)
    S.layers[layer.id], S.gains[layer.id] = source, 0
    sources[#sources + 1] = source
    S.sources = sources
    if checkpoint then
      checkpoint('music source ' .. layer.id)
    end
  end
  S.sources = sources
  -- Started in one call, the loops stay aligned for good.
  love.audio.play(sources)
end

-- MIXING ---------------------------------------------------------------------------

-- The mood of a session: a state's own (score.states), or in play the
-- guardian's, a rest (map, help) or 'battle' (calm into fight by intensity).
function S.mood(g)
  if g.state == 'playing' then
    if g.map or g.help then
      return 'rest'
    end
    local world = Queries.world(g)
    if world.guardianSpawned and not world.guardianDead then
      return 'guardian'
    end
    -- Chamber trials do not set the guardian flags.
    for _, e in ipairs(Pools.of(g, 'enemies')) do
      if e.hp > 0 and e.boss and e.awake then
        return 'guardian'
      end
    end
    return 'battle'
  end
  return Score.states[g.state] or 'rest'
end

-- The gain a mood gives a layer, battle blended by intensity (0..1).
function S.gain(mood, id, intensity)
  if mood == 'battle' then
    local calm, fight = Score.moods.calm[id] or 0, Score.moods.fight[id] or 0
    return calm + (fight - calm) * intensity
  end
  return Score.moods[mood][id] or 0
end

local function follow(value, target, dt, rates)
  local rate = target > value and rates.rise or rates.fall
  return value + (target - value) * (1 - math.exp(-math.max(0, dt) * rate))
end
S.follow = follow

function S.update(audio, dt, g)
  Scene.sample(g, scene)
  local mood = scene.config and 'battle' or S.mood(g)
  local danger = Score.danger
  local target = mood == 'battle' and math.min(1, (g.threat or 0) / danger.full) or 0
  if scene.config then
    target = scene.pressure
  end
  S.intensity = follow(S.intensity, target, dt, danger)
  local duck = audio and (audio.warningHold or 0) > 0 and 0.48 or 1
  S.duck = follow(S.duck or 1, duck, dt, duckRates)
  for _, layer in ipairs(Score.layers) do
    local id = layer.id
    local source = S.layers[id]
    if source then
      local wanted = scene.config and Scene.gain(scene, id, S.intensity)
        or S.gain(mood, id, S.intensity)
      local rates = scene.config and sceneRates or Score.follow
      S.gains[id] = follow(S.gains[id], wanted, dt, rates)
      source:setVolume(S.music * S.gains[id] * S.duck)
    end
  end
end
return S
