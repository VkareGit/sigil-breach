-- The shape of ruin. Pure geometry shared by what falls in the simulation and
-- what is drawn falling, so the hole in the roof is the same hole for both.
--   hole = { x, z, radius, seed }           the part of a vault that comes down
--   tear = { z, half, low, high, seed }     the upper edge of a torn wall
local Ruin = {}
local atan2, sin, sqrt, abs, huge = math.atan2, math.sin, math.sqrt, math.abs, math.huge
local Kinds = require('src.content.breakables')
function Ruin.holeEdge(hole, angle)
  local s = hole.seed
  return hole.radius
    * (1 + 0.2 * sin(angle * 3 + s) + 0.11 * sin(angle * 7 - s * 2) + 0.05 * sin(angle * 13 + s))
end
-- The widest the edge can stand from the hole's centre, in whole cells.
function Ruin.holeReach(hole)
  return math.ceil(hole.radius * 1.36)
end
function Ruin.inHole(hole, x, z)
  local dx, dz = x - hole.x, z - hole.z
  return sqrt(dx * dx + dz * dz) < Ruin.holeEdge(hole, atan2(dz, dx))
end
-- Height of a torn wall at z; infinite outside the tear.
function Ruin.tearHeight(tear, z)
  local d = abs(z - tear.z) / tear.half
  if d >= 1 then
    return huge
  end
  local jag = 0.5 * sin(z * 3.1 + tear.seed) + 0.28 * sin(z * 7.3 - tear.seed)
  return tear.low + (tear.high - tear.low) * d ^ 1.7 + jag * (1 - d * d)
end
function Ruin.check(list, label)
  local seen = {}
  for _, item in ipairs(list or {}) do
    assert(
      type(item.id) == 'string' and not seen[item.id],
      label .. ': breakable id ' .. tostring(item.id)
    )
    seen[item.id] = true
    assert(Kinds[item.kind], label .. ': unknown breakable kind ' .. tostring(item.kind))
    assert(type(item.radius) == 'number' and item.radius > 0, label .. ': breakable radius')
    for _, point in ipairs({ item.from, item.to }) do
      assert(type(point) == 'table' and #point == 3, label .. ': breakable segment')
    end
    if Kinds[item.kind].collapses then
      assert(item.cell and item.hole and item.rubble, label .. ': a support needs its ruin')
    end
  end
  for _, item in ipairs(list or {}) do
    assert(item.supports == nil or seen[item.supports], label .. ': unknown support')
  end
end
return Ruin
