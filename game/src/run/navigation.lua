local Roles = require('src.core.roles')
local Text = require('src.content.text')
local N = {}
function N.shrine(g)
  local shrine = require('src.run.descent').shrine
  local p = Roles.controlled(g)
  local dx, dz = shrine.x - p.x, shrine.z - p.z
  local angle = (math.atan2(dx, dz) - p.yaw + math.pi) % (2 * math.pi) - math.pi
  return {
    distance = math.sqrt(dx * dx + dz * dz),
    angle = angle,
    visible = require('src.world.arena').visible(g.world, p.x, p.z, shrine.x, shrine.z),
    direction = Text.get(
      math.abs(angle) > math.pi * 0.65 and 'dir_behind'
        or (angle < -0.18 and 'dir_left' or (angle > 0.18 and 'dir_right' or 'dir_ahead'))
    ),
  }
end
return N
