-- --audio-export: the game's sound outside play, as 16-bit WAV files for a
-- listen or a trailer's edit. <qa output>/music: each layer of the score (one
-- loop) and each mood's mix (two loops, the gains of content/score.lua);
-- <qa output>/sounds: every sound effect (audio/recipes.lua) as it plays.
-- report.txt in each: render time and every file's levels.
local Output = require('qa.output')
local Score = require('src.content.score')
local Soundscape = require('src.audio.soundscape')
local VoiceData = require('src.audio.voice_data')
local Recipes = require('src.audio.recipes')
local Audio = require('src.audio.audio')
local Tooling = require('qa.tooling')
local Synth = require('src.audio.synth')
local Export = {}
local floor = math.floor

local function u32(v)
  return string.char(
    v % 256,
    floor(v / 256) % 256,
    floor(v / 65536) % 256,
    floor(v / 16777216) % 256
  )
end
local function u16(v)
  return string.char(v % 256, floor(v / 256) % 256)
end
local function write(path, buffer, rate, loops, verify)
  local file = assert(io.open(path, 'wb'))
  local bytes = #buffer * loops * 2
  file:write('RIFF', u32(36 + bytes), 'WAVE', 'fmt ', u32(16), u16(1), u16(1))
  file:write(u32(rate), u32(rate * 2), u16(2), u16(16), 'data', u32(bytes))
  local chunk = {}
  for _ = 1, loops do
    for i = 1, #buffer do
      local v = floor(math.max(-1, math.min(1, buffer[i])) * 32767 + 0.5)
      chunk[#chunk + 1] = u16(v < 0 and v + 65536 or v)
      if #chunk == 4096 then
        file:write(table.concat(chunk))
        chunk = {}
      end
    end
  end
  file:write(table.concat(chunk))
  file:close()
  if verify then
    local saved = assert(io.open(path, 'rb'))
    local encoded = saved:read('*a')
    saved:close()
    local fileData = love.filesystem.newFileData(encoded, 'qa-smoke.wav')
    local decoded = love.sound.newSoundData(fileData)
    assert(
      decoded:getSampleCount() == #buffer * loops and decoded:getSampleRate() == rate,
      'exported WAV does not decode to its declared PCM samples'
    )
    decoded:release()
    fileData:release()
  end
end
local function levels(buffer)
  local peak, sum = 0, 0
  for i = 1, #buffer do
    peak = math.max(peak, math.abs(buffer[i]))
    sum = sum + buffer[i] * buffer[i]
  end
  return peak, math.sqrt(sum / #buffer)
end

local function directory(name)
  local dir = Output.path(name)
  require('qa.directory').ensure(dir)
  return dir
end
local function report(dir, lines, smoke)
  Tooling.write(dir, 'report.txt', lines, smoke)
  print(table.concat(lines, '\n'))
end

-- A staged listening excerpt, explicitly not a recording of a play session.
-- Uses the real chapel mix data, runtime gain follower and rendered voices.
local function chapelExcerpt(buffers, rate, dir, lines)
  local Scene = require('src.audio.scene')
  local config = require('src.content.maps.proving_soundscape')
  local route = {
    { seconds = 6, stage = 'traversal', x = 24, z = 36 },
    { seconds = 8, stage = 'traversal', x = 24, z = 20 },
    { seconds = 5, stage = 'traversal', x = 18.5, z = 27.5 },
    { seconds = 4, stage = 'summoning' },
    { seconds = 7, stage = 'duel', pressure = 0.2 },
    { seconds = 10, stage = 'duel', pressure = 0.9 },
    { seconds = 8, stage = 'aftermath' },
  }
  local mix, gains, index, clock = {}, {}, 1, 0
  local loop = #buffers[Score.layers[1].id]
  for _, scene in ipairs(route) do
    scene.config, scene.returning = config, 0
    scene.x, scene.z = scene.x or 10, scene.z or 18
    lines[#lines + 1] = string.format(
      'chapel excerpt %.1fs: %s (pressure %.1f)',
      clock,
      scene.stage,
      scene.pressure or 0
    )
    for n = 1, math.floor(scene.seconds * rate) do
      if n % math.floor(rate / 60) == 1 then
        for _, layer in ipairs(Score.layers) do
          local id = layer.id
          gains[id] = Soundscape.follow(
            gains[id] or 0,
            Scene.gain(scene, id, scene.pressure or 0),
            1 / 60,
            Soundscape.sceneRates
          )
        end
      end
      local sample = 0
      for _, layer in ipairs(Score.layers) do
        sample = sample + buffers[layer.id][(index - 1) % loop + 1] * (gains[layer.id] or 0)
      end
      mix[index], index = sample * Soundscape.music, index + 1
    end
    clock = clock + scene.seconds
  end
  for _, cue in ipairs({
    { 19, 'binding_release', 0.32 },
    { 23, 'ash_arrival', 0.38 },
    { 26, 'ash_fan_warning', 0.4 },
    { 26.65, 'ash_fan_release', 0.4 },
    { 30, 'ash_lance_warning', 0.4 },
    { 30.65, 'ground_sunder', 0.35 },
    { 31.30, 'ash_eruption', 0.3 },
    { 31.60, 'ash_eruption', 0.3 },
    { 31.90, 'ash_eruption', 0.3 },
    { 35, 'furnace_warning', 0.4 },
    { 35.55, 'ground_sunder', 0.35 },
    { 36.03, 'ash_eruption', 0.3 },
    { 40, 'boss_collapse', 0.4 },
  }) do
    local recipe = Recipes[cue[2]]
    local sound = VoiceData.render(cue[2], recipe, rate)
    local start = math.floor(cue[1] * rate) + 1
    for i = 0, sound:getSampleCount() - 1 do
      if mix[start + i] then
        mix[start + i] = mix[start + i] + sound:getSample(i) * cue[3]
      end
    end
    sound:release()
  end
  -- End the exported excerpt gracefully; runtime stems continue indefinitely.
  for i = math.max(1, #mix - rate), #mix do
    mix[i] = mix[i] * (#mix - i) / rate
  end
  local peak, rms = levels(mix)
  assert(peak < 1, 'chapel listening excerpt clips')
  write(dir .. '/chapel-listening-excerpt.wav', mix, rate, 1, true)
  lines[#lines + 1] = string.format(
    'chapel excerpt peak %.3f rms %.3f; staged mono listening example, not gameplay recording or subjective approval',
    peak,
    rms
  )
end

-- Every recipe rendered as the game renders it (Audio.rate, its own seed).
function Export.sounds(smoke)
  local dir = directory('sounds')
  local names = {}
  for name in pairs(Recipes) do
    names[#names + 1] = name
  end
  table.sort(names)
  local lines = Tooling.header('SOUND EFFECT EXPORT', smoke)
  for index, name in ipairs(names) do
    if smoke and index > 1 then
      break
    end
    local recipe = Recipes[name]
    local data = VoiceData.render(name, recipe, Audio.rate)
    local buffer = {}
    for i = 0, data:getSampleCount() - 1 do
      buffer[i + 1] = data:getSample(i)
    end
    data:release()
    write(dir .. '/' .. name .. '.wav', buffer, Audio.rate, 1, smoke)
    local peak, rms = levels(buffer)
    lines[#lines + 1] =
      string.format('%-14s %.2f s peak %.3f rms %.3f', name, recipe.duration, peak, rms)
  end
  report(dir, lines, smoke)
  return smoke and 1 or #names
end

-- The Exorcist's two directions for the owner's listening (qa/sound_ab.lua):
-- each cue in A and B, beside today's sound, every one at the level of today's
-- (or its stated share of it). Full profile only; nothing of it plays in game.
function Export.exorcistAB()
  local AB = require('qa.sound_ab')
  local dir = directory('sound-ab/exorcist')
  local rate = Audio.rate
  local lines = Tooling.header('EXORCIST A/B EXPORT', false)
  lines[#lines + 1] = 'A: dry iron, violent report, heavy powder, short walls.'
  lines[#lines + 1] = 'B: the same attack, deeper powder, darker and longer stone.'
  lines[#lines + 1] = "Levels are matched by RMS to today's sound (classic), not by loudness"
    .. ' as heard: listen before choosing; nothing here plays in the game.'
  for _, cue in ipairs(AB.cues) do
    local recipe = Recipes[cue.classic]
    local data = VoiceData.render(cue.classic, recipe, rate)
    local classic = {}
    for i = 0, data:getSampleCount() - 1 do
      classic[i + 1] = data:getSample(i)
    end
    data:release()
    local _, reference = levels(classic)
    local target = reference * cue.share
    if cue.share == 1 then
      write(dir .. '/' .. cue.id .. '-classic.wav', classic, rate, 1, false)
    end
    for _, side in ipairs({ 'A', 'B' }) do
      local buffer =
        AB.render(cue.duration, rate, Synth.seed('exorcist-ab-' .. cue.id .. side), cue[side](rate))
      AB.match(buffer, target)
      write(dir .. '/' .. cue.id .. '-' .. side .. '.wav', buffer, rate, 1, false)
      local peak, rms = levels(buffer)
      lines[#lines + 1] = string.format(
        '%-6s %s %.2f s peak %.3f rms %.3f (today %s rms %.3f x %.2f)',
        cue.id,
        side,
        cue.duration,
        peak,
        rms,
        cue.classic,
        reference,
        cue.share
      )
    end
  end
  report(dir, lines, false)
  return #AB.cues
end

function Export.run(smoke)
  local effects = Export.sounds(smoke)
  local pairs = smoke and 0 or Export.exorcistAB()
  local dir = directory('music')
  local started = love.timer.getTime()
  local buffers, loop, rate = Soundscape.render()
  local seconds = love.timer.getTime() - started
  local lines = Tooling.header('MUSIC EXPORT', smoke)
  lines[#lines + 1] = string.format('render %.3f s; loop %.2f s at %d Hz', seconds, loop, rate)
  local function excerpt(buffer)
    if not smoke then
      return buffer
    end
    local short = {}
    for i = 1, math.min(#buffer, rate) do
      short[i] = buffer[i]
    end
    return short
  end
  local layers = smoke and { Score.layers[1] } or Score.layers
  for _, layer in ipairs(layers) do
    local buffer = excerpt(buffers[layer.id])
    write(dir .. '/layer-' .. layer.id .. '.wav', buffer, rate, 1, smoke)
    local peak, rms = levels(buffer)
    lines[#lines + 1] = string.format('layer %-8s peak %.3f rms %.3f', layer.id, peak, rms)
  end
  local moods = smoke and { 'fight' } or { 'menu', 'calm', 'fight', 'guardian', 'death', 'victory' }
  for _, mood in ipairs(moods) do
    local mix = {}
    for i = 1, (smoke and math.min(rate, #buffers[Score.layers[1].id]) or #buffers[Score.layers[1].id]) do
      local s = 0
      for _, layer in ipairs(Score.layers) do
        s = s + buffers[layer.id][i] * Soundscape.gain(mood, layer.id, 1)
      end
      mix[i] = s
    end
    write(dir .. '/mood-' .. mood .. '.wav', mix, rate, smoke and 1 or 2, smoke)
    local peak, rms = levels(mix)
    lines[#lines + 1] = string.format('mood  %-8s peak %.3f rms %.3f', mood, peak, rms)
  end
  if smoke then
    lines[#lines + 1] =
      'Smoke exports one full sound effect, one layer excerpt and one mixed-mood excerpt (1 s each); every WAV was decoded back and its sample count/rate verified. Full score synthesis is exercised; this is not a complete audio export or listening assessment.'
  else
    chapelExcerpt(buffers, rate, dir, lines)
  end
  report(dir, lines, smoke)
  local summary = Tooling.header('AUDIO EXPORT', smoke)
  summary[#summary + 1] = string.format(
    'Exported effects=%d layers=%d moods=%d exorcistAB=%d; detailed reports: sounds/report.txt and music/report.txt',
    effects,
    #layers,
    #moods,
    pairs
  )
  Tooling.write(Output.directory(), 'audio-export.txt', summary, smoke)
end
return Export
