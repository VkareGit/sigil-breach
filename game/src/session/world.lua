-- The ECS world of one session: pools over the session's own arrays (the
-- session stays their owner, so existing code and saves keep working),
-- component schemas and prefabs. Systems query it; factories spawn from it.
local World = require('src.core.ecs')
local Components = require('src.session.components')
local M = {}
function M.new(g)
  local w = World:new()
  Components.declare(w)
  -- Pools: every member has the pool's components (hand-made members too).
  w:pool('enemies', function()
    return g.enemies
  end, Components.pools.enemies)
  w:pool('projectiles', function()
    return g.bullets
  end, Components.pools.projectiles)
  w:pool('hazards', function()
    return g.hazards
  end, Components.pools.hazards)
  w:pool('pickups', function()
    return g.pickups
  end, Components.pools.pickups)
  w:pool('charges', function()
    return g.charges
  end, Components.pools.charges)
  w:single('knight', function()
    return g.player
  end, Components.pools.knight)
  Components.prefabs(w)
  return w
end
return M
