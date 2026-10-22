local N = {}
function N.shrine(g)
  local shrine = require('src.run.descent').shrine
  local p = g.player
  local dx, dz = shrine.x - p.x, shrine.z - p.z
  local angle = (math.atan2(dx, dz) - p.yaw + math.pi) % (2 * math.pi) - math.pi
  return {
    distance = math.sqrt(dx * dx + dz * dz),
    angle = angle,
    visible = require('src.world.arena').visible(g.world, p.x, p.z, shrine.x, shrine.z),
    direction = math.abs(angle) > math.pi * 0.65 and 'BEHIND YOU'
      or (angle < -0.18 and 'TO THE LEFT' or (angle > 0.18 and 'TO THE RIGHT' or 'AHEAD')),
  }
end
return N
