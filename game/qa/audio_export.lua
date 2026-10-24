-- --audio-export: the game's sound outside play, as 16-bit WAV files for a
-- listen or a trailer's edit. <qa output>/music: each layer of the score (one
-- loop) and each mood's mix (two loops, the gains of audio/score.lua);
-- <qa output>/sounds: every sound effect (audio/recipes.lua) as it plays.
-- report.txt in each: render time and every file's levels.
local Output = require('qa.output')
local Score = require('src.audio.score')
local Soundscape = require('src.audio.soundscape')
local Synth = require('src.audio.synth')
local Recipes = require('src.audio.recipes')
local Audio = require('src.audio.audio')
local Tooling = require('qa.tooling')
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
  os.execute('mkdir "' .. dir:gsub('/', '\\') .. '" 2>nul')
  return dir
end
local function report(dir, lines, smoke)
  Tooling.write(dir, 'report.txt', lines, smoke)
  print(table.concat(lines, '\n'))
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
    local data = Synth.effect(
      recipe.duration,
      Audio.rate,
      Synth.seed(name),
      recipe.voice or recipe.make(Audio.rate)
    )
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

function Export.run(smoke)
  local effects = Export.sounds(smoke)
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
  end
  report(dir, lines, smoke)
  local summary = Tooling.header('AUDIO EXPORT', smoke)
  summary[#summary + 1] = string.format(
    'Exported effects=%d layers=%d moods=%d; detailed reports: sounds/report.txt and music/report.txt',
    effects,
    #layers,
    #moods
  )
  Tooling.write(Output.directory(), 'audio-export.txt', summary, smoke)
end
return Export
