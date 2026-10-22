-- Factory of session entities. Systems never build entity tables by hand:
-- they ask for a prefab (session/components.lua) with the values that depend
-- on the moment. A bare session (a hand-made test fixture without an ECS
-- world) still gets the entity appended to the right array.
local Spawn = {}
-- prefab -> the session array its pool reads.
Spawn.arrays = {
  creature = 'enemies',
  projectile = 'bullets',
  hazard = 'hazards',
  pickup = 'pickups',
  charge = 'charges',
}
function Spawn.make(g, prefab, values)
  if g.ecs then
    return g.ecs:create(prefab, values)
  end
  local list = g[assert(Spawn.arrays[prefab], 'unknown prefab ' .. tostring(prefab))]
  list[#list + 1] = values
  return values
end
return Spawn
