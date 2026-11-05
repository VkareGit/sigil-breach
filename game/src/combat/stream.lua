-- One finite tapered stream, shared by contact and presentation.
local Anchor = require('src.enemies.contact_anchor')
local Ground = require('src.physics.ground')
local Bodies = require('src.combat.bodies')
local Ballistics = require('src.combat.ballistics')
local Stream = {}
function Stream.shape(g, e, a, observer)
  local x, y, z = Anchor.point(g, e, e.phase, e.x, e.z, a.anchor, observer)
  x, y, z = x or e.x, y or a.height, z or e.z
  return {
    x = x,
    y = Ground.of(g.world, e) + y,
    z = z,
    dx = e.lungeX,
    dz = e.lungeZ,
    reach = a.reach,
    startWidth = a.startWidth,
    endWidth = a.endWidth,
    startHeight = a.startHeight,
    endHeight = a.endHeight,
    fall = a.fall,
  }
end
function Stream.test(g, s, body, point)
  local radius, clearance, height = Bodies.extent(g, body)
  local dx, dz = point.x - s.x, point.z - s.z
  local along = dx * s.dx + dz * s.dz
  -- The closed mouth and the far edge have no invisible reach behind them.
  if along < 0 or along >= s.reach then
    return false
  end
  local t = along / s.reach
  local width = s.startWidth + (s.endWidth - s.startWidth) * t
  local lateral = dx * s.dz - dz * s.dx
  if math.abs(lateral) >= width + radius then
    return false
  end
  local half = s.startHeight + (s.endHeight - s.startHeight) * t
  local cy = s.y - s.fall * t
  local feet = Ground.of(g.world, point) + (point.jump or point.leapY or 0)
  local low, high = feet + clearance, feet + height - (point.crouch or 0)
  if high < cy - half or low >= cy + half then
    return false
  end
  local y = (math.max(low, cy - half) + math.min(high, cy + half)) * 0.5
  local dy = y - s.y
  local length = math.sqrt(dx * dx + dy * dy + dz * dz)
  local hit, _, kind =
    Ballistics.world(g.world, s.x, s.y, s.z, dx / length, dy / length, dz / length, length)
  if kind ~= 'range' and hit < length - 1e-6 then
    return false
  end
  return true,
    {
      geometry = 'tapered-stream',
      sourcePoint = { x = s.x, y = s.y, z = s.z },
      samplePoint = { x = point.x, y = y, z = point.z },
      bounds = { bottom = cy - half, top = cy + half, radius = width },
    }
end
return Stream
