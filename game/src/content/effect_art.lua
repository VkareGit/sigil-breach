-- Painted effect sequences over the existing atlas. Timing and frame choices
-- are data; these visual records never determine damage or attack windows.
local Registry = require('src.core.registry')
local Effects = Registry:new('effect artwork', function(entry, id)
  local where = 'effect artwork ' .. id .. ': '
  assert(
    type(entry.duration) == 'number' and entry.duration > 0 and entry.duration < math.huge,
    where .. 'invalid duration'
  )
  assert(type(entry.frames) == 'table' and #entry.frames > 0, where .. 'missing frames')
  for _, frame in ipairs(entry.frames) do
    assert(
      type(frame) == 'number' and frame % 1 == 0 and frame >= 1 and frame <= 16,
      where .. 'unknown atlas frame'
    )
  end
  for _, key in ipairs({ 'alpha', 'brightness' }) do
    assert(
      type(entry[key]) == 'number' and entry[key] >= 0 and entry[key] < math.huge,
      where .. 'invalid ' .. key
    )
  end
  assert(entry.alpha <= 1, where .. 'alpha exceeds one')
  assert(
    entry.rise == nil or (type(entry.rise) == 'number' and math.abs(entry.rise) < math.huge),
    where .. 'invalid rise'
  )
  assert(
    entry.limit == nil
      or (type(entry.limit) == 'number' and entry.limit >= 1 and entry.limit % 1 == 0),
    where .. 'invalid limit'
  )
end)
Effects:register(
  'stone',
  { duration = 0.28, frames = { 1, 2, 3, 4 }, alpha = 0.60, brightness = 1 }
)
Effects:register(
  'blood',
  { duration = 0.32, frames = { 5, 6, 7, 8 }, alpha = 0.60, brightness = 1 }
)
-- The first two display frames show the actual point of contact before the
-- longer spray disperses. These use the same pigment as the existing effects.
Effects:register(
  'contact_blood',
  { duration = 0.067, frames = { 6 }, alpha = 0.95, brightness = 1 }
)
Effects:register(
  'contact_stone',
  { duration = 0.067, frames = { 2 }, alpha = 0.95, brightness = 1.12 }
)
Effects:register('smoke', {
  duration = 0.52,
  frames = { 9, 10, 11, 12 },
  alpha = 0.17,
  brightness = 1,
  rise = 0.24,
  limit = 8,
})
-- The slow cloud of something heavy coming down.
Effects:register('dust', {
  duration = 3.4,
  frames = { 9, 10, 11, 12 },
  alpha = 0.34,
  brightness = 0.75,
  rise = 0.3,
  limit = 22,
})
Effects:register(
  'arc',
  { duration = 0.24, frames = { 13, 14, 15, 16 }, alpha = 0.78, brightness = 1.12 }
)
return Effects
