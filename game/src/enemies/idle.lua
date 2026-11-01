-- Authored quiet poses are appended to the original action atlas. Unequal
-- exposures hold a breath and let it settle; entity phase prevents a chorus
-- of identical breathing. This module needs no graphics context.
local Enemies = require('src.content.enemies')
local Metadata = require('src.content.enemy_idle')
local I = { count = Metadata.count, entries = Metadata.entries }
function I.kind(e)
  return Enemies.look(e).atlas or e.kind
end
function I.sample(kind, time, id)
  local entry = assert(I.entries[kind], 'unknown idle identity: ' .. tostring(kind))
  local phase = ((time or 0) / entry.period + (id or 0) * 0.3819660112501051) % 1
  local boundary = 0
  for n, w in ipairs(entry.weights) do
    boundary = boundary + w
    if phase < boundary then
      return entry.first + n - 1
    end
  end
  return entry.first + I.count - 1
end
function I.total(kind)
  return assert(I.entries[kind]).first + I.count - 1
end
return I
