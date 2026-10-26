-- Sides of a fight (plan v10 V2): who is hostile to whom. A creature's side
-- is its definition's faction (default 'demons'); a knight's is 'knight'.
-- An entity may carry its own faction field (an ally, a turned demon).
--   hostile = { side = true, ... }   the sides it attacks and can hurt
-- Means of harm: blow, missile, hazard, blast. A blast hurts every body in
-- its reach, its own thrower included; every other means hurts only bodies
-- of a hostile side. A new side is a new entry (Factions:register); the
-- relation must be stated by both entries that take part in it.
local Registry = require('src.core.registry')
local Factions = Registry:new('factions', function(entry, id)
  assert(type(entry) == 'table', 'faction ' .. id .. ': expected a table')
  assert(type(entry.hostile) == 'table', 'faction ' .. id .. '.hostile: expected a set of sides')
  for side, value in pairs(entry.hostile) do
    assert(
      type(side) == 'string' and value == true,
      'faction ' .. id .. '.hostile: expected side = true'
    )
  end
end)
Factions:register('knight', { hostile = { demons = true } })
Factions:register('demons', { hostile = { knight = true } })
-- Means that hurt every body they reach, whatever its side.
Factions.indiscriminate = { blast = true }
function Factions.hostile(a, b)
  local entry = Factions:get(a)
  return entry.hostile[b] == true
end
-- Whether harm by this means from side a reaches a body of side b.
function Factions.harms(a, b, means)
  return Factions.indiscriminate[means] == true or Factions.hostile(a, b)
end
return Factions
