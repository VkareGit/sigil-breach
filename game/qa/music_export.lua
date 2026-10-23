-- --music-export: the score rendered outside play, as 16-bit WAV files in
-- <qa output>/music: each layer (one loop) and each mood's mix (two loops,
-- the gains of audio/score.lua), for a listen or a trailer's edit; and
-- report.txt with the render's time, the loop and each file's levels.
local Output = require('qa.output')
local Score = require('src.audio.score')
local Soundscape = require('src.audio.soundscape')
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
local function write(path, buffer, rate, loops)
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
end
local function levels(buffer)
  local peak, sum = 0, 0
  for i = 1, #buffer do
    peak = math.max(peak, math.abs(buffer[i]))
    sum = sum + buffer[i] * buffer[i]
  end
  return peak, math.sqrt(sum / #buffer)
end

function Export.run()
  local dir = Output.path('music')
  os.execute('mkdir "' .. dir:gsub('/', '\\') .. '" 2>nul')
  local started = love.timer.getTime()
  local buffers, loop, rate = Soundscape.render()
  local seconds = love.timer.getTime() - started
  local report = {
    string.format('render %.3f s; loop %.2f s at %d Hz', seconds, loop, rate),
  }
  for _, layer in ipairs(Score.layers) do
    local buffer = buffers[layer.id]
    write(dir .. '/layer-' .. layer.id .. '.wav', buffer, rate, 1)
    local peak, rms = levels(buffer)
    report[#report + 1] = string.format('layer %-8s peak %.3f rms %.3f', layer.id, peak, rms)
  end
  for _, mood in ipairs({ 'menu', 'calm', 'fight', 'guardian', 'death', 'victory' }) do
    local mix = {}
    for i = 1, #buffers[Score.layers[1].id] do
      local s = 0
      for _, layer in ipairs(Score.layers) do
        s = s + buffers[layer.id][i] * Soundscape.gain(mood, layer.id, 1)
      end
      mix[i] = s
    end
    write(dir .. '/mood-' .. mood .. '.wav', mix, rate, 2)
    local peak, rms = levels(mix)
    report[#report + 1] = string.format('mood  %-8s peak %.3f rms %.3f', mood, peak, rms)
  end
  local file = assert(io.open(dir .. '/report.txt', 'w'))
  file:write(table.concat(report, '\n'), '\n')
  file:close()
  print(table.concat(report, '\n'))
end
return Export
