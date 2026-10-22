-- Persistence adapter: parsing is pure; filesystem access is confined here.
local P = {}
local defaults =
  { sensitivity = 1, muted = false, motion = true, fov = 100, music = 0.65, hints = true }
local bounds = { sensitivity = { 0.2, 3 }, fov = { 85, 115 }, music = { 0, 1 } }
local order = { 'sensitivity', 'motion', 'fov', 'music', 'hints', 'muted' }
function P.decode(text)
  local settings = {}
  for key, value in pairs(defaults) do
    settings[key] = value
  end
  for line in ((text or '') .. '\n'):gmatch('([^\r\n]+)') do
    local key, value = line:match('^([%w_]+)=([^\r\n]+)$')
    local range = bounds[key]
    if range then
      local number = tonumber(value)
      if number and number == number and math.abs(number) < math.huge then
        settings[key] = math.max(range[1], math.min(range[2], number))
      end
    elseif type(defaults[key]) == 'boolean' and (value == 'true' or value == 'false') then
      settings[key] = value == 'true'
    end
  end
  return settings
end
function P.encode(settings)
  local lines = {}
  for _, key in ipairs(order) do
    lines[#lines + 1] = key .. '=' .. tostring(settings[key])
  end
  return table.concat(lines, '\n')
end
function P.read()
  return P.decode(love.filesystem.read('settings-v03.txt') or love.filesystem.read('settings.txt'))
end
function P.save(settings)
  return love.filesystem.write('settings-v03.txt', P.encode(settings))
end
return P
