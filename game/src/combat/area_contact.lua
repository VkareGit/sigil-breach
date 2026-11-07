-- Ground attack cylinders. The collision result and its diagnostic receipt
-- come from this one query. Floors/decks are solid, not infinite 2D footprints.
local Ground = require('src.physics.ground')
local Bodies = require('src.combat.bodies')
local Ballistics = require('src.combat.ballistics')
local floorSkin = require('src.content.tuning').floorSurface
local Area = {}
local epsilon = 1e-6

-- Sample world height between endpoints, not the floor of the final cell.
-- The output is a swept point usable by melee as well (jump relative to level).
function Area.sample(g, body, previous, t, out)
  out = out or {}
  previous = previous or body
  local function air(b)
    return b.jump or b.leapY or 0
  end
  local from = Ground.of(g.world, previous) + air(previous)
  local to = Ground.of(g.world, body) + air(body)
  out.x = previous.x + (body.x - previous.x) * t
  out.z = previous.z + (body.z - previous.z) * t
  local feet = from + (to - from) * t
  out.level = g.world.decks and feet or nil
  out.jump = feet - Ground.of(g.world, out)
  out.crouch = (previous.crouch or 0) + ((body.crouch or 0) - (previous.crouch or 0)) * t
  return out
end

-- source carries x/z/level/radius. Volume describes heights and sampling only;
-- its top is clipped to the first solid ceiling over the emitting surface.
function Area.test(g, source, volume, body, point)
  point = point or body
  local floor = Ground.of(g.world, source)
  local bottom, top = floor + volume.bottom, floor + volume.top
  local ceiling = Ground.ceiling(g.world, source.x, source.z, floor)
  if ceiling then
    top = math.min(top, ceiling)
  end
  local feet = Ground.of(g.world, point) + (point.jump or point.leapY or 0)
  local radius, clearance, height = Bodies.extent(g, body)
  local low, high = feet, feet
  if volume.sample == 'body' then
    low, high = feet + clearance, feet + height - (point.crouch or 0)
  end
  if top <= bottom or high < bottom or low >= top then
    return false
  end
  local reach = source.radius + (volume.includeRadius and radius or 0)
  local dx, dz = point.x - source.x, point.z - source.z
  local distance = math.sqrt(dx * dx + dz * dz)
  if distance >= reach then
    return false
  end
  -- Trace inside the overlapping height band, just above the floor for feet.
  -- This sees walls, steps and decks using the same 3D world query as bullets.
  local y
  if volume.sample == 'body' then
    y = (math.max(bottom, low) + math.min(top, high)) * 0.5
  else
    y = math.min(top - epsilon, math.max(bottom, low) + floorSkin + epsilon)
  end
  if distance > epsilon then
    local hit, _, kind =
      Ballistics.world(g.world, source.x, y, source.z, dx / distance, 0, dz / distance, distance)
    if kind ~= 'range' and hit < distance - epsilon then
      return false
    end
  end
  return true,
    {
      geometry = volume.sample == 'feet' and 'radial-feet' or 'radial-column',
      sourcePoint = { x = source.x, y = floor, z = source.z },
      samplePoint = { x = point.x, y = feet, z = point.z },
      radius = source.radius,
      bounds = { bottom = bottom, top = top, radius = reach, sample = volume.sample },
    }
end
return Area
