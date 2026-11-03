-- Persistence adapter: parsing is pure; filesystem access is confined here.
local Settings = require('src.content.settings')
local Sets = require('src.content.sound_sets')
local P = {}
local defaults = {
  sensitivity = 1,
  muted = false,
  motion = true,
  fov = 100,
  -- Four levels (0.45, owner D17): master, effects (guns, steps, demons, warnings, menus),
  -- music and the ambience of the rooms.
  master = 1,
  effects = 1,
  music = 0.65,
  ambience = 0.65,
  hints = true,
  slot = 1,
  renderScale = Settings.renderScale.default,
  soundSet = Sets.default,
}
local bounds = {
  sensitivity = { 0.2, 3 },
  fov = { 85, 115 },
  master = { 0, 1 },
  effects = { 0, 1 },
  music = { 0, 1 },
  ambience = { 0, 1 },
}
local order = {
  'sensitivity',
  'motion',
  'fov',
  'master',
  'effects',
  'music',
  'ambience',
  'hints',
  'muted',
  'renderScale',
  'soundSet',
}
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
    elseif key == 'renderScale' then
      for _, scale in ipairs(Settings.renderScale.choices) do
        if tonumber(value) == scale then
          settings.renderScale = scale
        end
      end
    elseif key == 'soundSet' then
      for _, set in ipairs(Sets.order) do
        if value == set then
          settings.soundSet = set
        end
      end
    elseif type(defaults[key]) == 'boolean' and (value == 'true' or value == 'false') then
      settings[key] = value == 'true'
    end
  end
  -- A file from before 0.45 had one level for music and ambience together.
  if text and not text:find('ambience=', 1, true) then
    settings.ambience = settings.music
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
