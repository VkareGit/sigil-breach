-- Stones falling while a support comes down. Nothing here is simulated: the
-- same id gives the same fall, and the ruin is already in the world.
local Builder = require('src.render.kit.builder')
local Breakables = require('src.content.breakables')
local Ruin = require('src.content.maps.breakables')
local Destruction = require('src.combat.destruction')
local Debris = { duration = 2.6, count = 72 }
local cos, sin, pi = math.cos, math.sin, math.pi
local plans = {}
-- One broken stone of about a metre at the origin.
function Debris.vertices()
  local list = Builder.list(nil)
  Builder.chunk(list, { 0, 0, 0 }, { 0.5, 0.34, 0.42 }, 0, 7, 0.55)
  return list
end
local function plan(def)
  local found = plans[def.id]
  if not found then
    local seed = 0
    for i = 1, #def.id do
      seed = (seed * 31 + def.id:byte(i)) % 9973
    end
    local rng = Builder.random(seed + 1)
    found = {}
    local hole = def.hole
    for i = 1, Debris.count do
      local stone = {}
      if i % 3 == 0 then
        -- The shaft itself.
        local a = rng() * 2 * pi
        stone.x, stone.z = def.cell[1] + cos(a) * 0.55, def.cell[2] + sin(a) * 0.55
        stone.y, stone.delay = 1 + rng() * 7.5, rng() * 0.3
      else
        -- The roof it carried, a little after.
        local a, d = rng() * 2 * pi, math.sqrt(rng())
        local reach = Ruin.holeEdge(hole, a) * d
        stone.x, stone.z = hole.x + cos(a) * reach, hole.z + sin(a) * reach
        stone.y, stone.delay = 10 + rng() * 5, 0.12 + rng() * 0.9
      end
      stone.size = 0.22 + rng() ^ 2 * 0.95
      stone.spin, stone.yaw = (rng() - 0.5) * 7, rng() * 6
      found[i] = stone
    end
    plans[def.id] = found
  end
  return found
end
function Debris.draw(r, g, mesh)
  local world = g.world
  for _, def in ipairs(Destruction.list(world)) do
    if Breakables[def.kind].collapses then
      local stage, at = Destruction.stage(world, def.id)
      local t = stage == 2 and g.elapsed - at or -1
      if t >= 0 and t < Debris.duration then
        for _, s in ipairs(plan(def)) do
          local fall = t - s.delay
          if fall > 0 then
            local y = s.y - 4.9 * fall * fall
            local rest = 0.25 * s.size
            local landed = y <= rest
            r:object(
              mesh,
              s.x,
              landed and rest - (t - s.delay - 1) * 0.4 or y,
              s.z,
              s.yaw + (landed and 0 or s.spin * fall),
              s.size
            )
          end
        end
      end
    end
  end
end
return Debris
