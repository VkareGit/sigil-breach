-- The walkable ground (plan v5 G2): the one answer to "how high is the floor
-- here" for shots, missiles, thrown charges and hit volumes. Bodies keep
-- their heights relative to it (a jump, a leap, a fall, a crouch); missiles,
-- charges and rays live in world height. A heightfield has one supporting
-- surface per cell (no overhangs); elevation is relative to the map datum.
local Ground = {}
-- Height (m) of the ground at (x, z) of a world (built by world/arena.lua).
function Ground.cell(world, x, z)
  local row = world and world.elevations and world.elevations[z]
  return row and row[x] or 0
end
function Ground.height(world, x, z)
  local datum = world and world.floor or 0
  if x == nil or z == nil then
    return datum
  end
  return datum + Ground.cell(world, math.floor(x + 0.5), math.floor(z + 0.5))
end
return Ground
