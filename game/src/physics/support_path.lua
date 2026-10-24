-- Point-support changes along a horizontal segment. The circular movement
-- footprint and weapon contact surfaces are separate contracts. This helper
-- splits grounded drag at a ledge so the remaining time is really airborne.
local Ground = require('src.physics.ground')
local Path = {}
-- Same spatial skin as Collision.move; larger than its zero-travel cutoff.
-- It selects a segment endpoint, never adds distance to the requested path.
local boundarySkin = 1e-7
function Path.firstChange(world, x, z, dx, dz)
  if not world.elevations or (dx == 0 and dz == 0) then
    return nil
  end
  local cx, cz = math.floor(x + 0.5), math.floor(z + 0.5)
  local height = Ground.cell(world, cx, cz)
  local sx, sz = dx < 0 and -1 or 1, dz < 0 and -1 or 1
  local tx = dx ~= 0 and (cx + sx * 0.5 - x) / dx or math.huge
  local tz = dz ~= 0 and (cz + sz * 0.5 - z) / dz or math.huge
  local stepX = dx ~= 0 and 1 / math.abs(dx) or math.huge
  local stepZ = dz ~= 0 and 1 / math.abs(dz) or math.huge
  while math.min(tx, tz) <= 1 do
    local t = math.min(tx, tz)
    if tx <= t then
      cx, tx = cx + sx, tx + stepX
    end
    if tz <= t then
      cz, tz = cz + sz, tz + stepZ
    end
    if Ground.cell(world, cx, cz) ~= height then
      -- Pick the outgoing side of an exact cell boundary in either direction.
      -- This is a numerical ownership tie-break, never a gameplay tolerance.
      return math.min(1, math.max(0, t) + boundarySkin / math.sqrt(dx * dx + dz * dz))
    end
  end
end
function Path.time(fraction, drag, duration)
  if drag == 0 then
    return duration * fraction
  end
  local travel = (1 - math.exp(-drag * duration)) / drag
  return -math.log(1 - drag * travel * fraction) / drag
end
return Path
