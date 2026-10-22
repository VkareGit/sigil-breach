-- The walkable ground (plan v5 G2): the one answer to "how high is the floor
-- here" for shots, missiles, thrown charges and hit volumes. Bodies keep
-- their heights relative to it (a jump, a leap, a fall, a crouch); missiles,
-- charges and rays live in world height and add it. A map states its floor
-- (content/maps: floor, default 0); a map with levels answers per cell here
-- and nothing else has to change.
local Ground = {}
-- Height (m) of the ground at (x, z) of a world (built by world/arena.lua).
function Ground.height(world)
  return world and world.floor or 0
end
return Ground
