-- The kinds of harm. A new one is one entry; a typo fails when its definition
-- is built, not silently in a fight.
--   armored  armour ratings reduce it
--   color    its colour on projectiles, pools and hit markers
--   impact   the sound of a missile of it landing
--   flight   the sound of a missile of it passing
local Registry = require('src.core.registry')
local Types = Registry:new('damage types')
local function define(id, def)
  def.impact = def.impact or 'hit'
  def.flight = def.flight or 'whoosh'
  Types:register(id, def)
end
Types.define, Types.fallback = define, 'physical'
define('physical', { armored = true, color = { 0.88, 0.30, 0.20 } })
define('fire', { color = { 1, 0.56, 0.18 }, impact = 'ember_impact', flight = 'ember_flight' })
define('astral', { color = { 0.48, 0.66, 1 } })
define('poison', { color = { 0.58, 0.84, 0.30 } })
define('lightning', { color = { 0.98, 0.94, 0.72 } })
-- The cue of a missile of this type; none, or an unknown one: the plain cue.
function Types.cue(id, moment)
  local def = Types.entries[id or Types.fallback]
  return (def or Types.entries[Types.fallback])[moment]
end
-- A schema check: nil when the id names a type.
function Types.problem(id)
  if not Types:has(id) then
    return 'unknown damage type ' .. tostring(id)
  end
end
-- A schema check for a table keyed by damage types.
function Types.keysProblem(values)
  for id in pairs(values) do
    if not Types:has(id) then
      return 'unknown damage type ' .. tostring(id)
    end
  end
end
return Types
