-- The kinds of marked ground. A kind is three entries: this one (its default
-- volume), what it does (enemies/hazards.lua) and how it looks
-- (render/hazard_kinds.lua). A session refuses a kind missing from any of them.
local Registry = require('src.core.registry')
local Kinds = Registry:new('hazard kinds')
Kinds.default = 'pool'
Kinds:register('pool', { volume = 'pool' })
Kinds:register('lightning', { volume = 'lightning' })
-- A schema check: nil when the id names a kind.
function Kinds.problem(id)
  if not Kinds:has(id) then
    return 'unknown hazard kind ' .. tostring(id)
  end
end
return Kinds
