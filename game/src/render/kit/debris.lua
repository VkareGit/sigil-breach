-- Stones falling while a support comes down. Nothing here is simulated: the
-- same id gives the same fall, and the ruin is already in the world.
local Builder = require('src.render.kit.builder')
local Breakables = require('src.content.breakables')
local Ruin = require('src.content.maps.breakables')
local Destruction = require('src.combat.destruction')
local Fall = require('src.content.art.falling_stone')
local Debris = { duration = Fall.duration, count = Fall.count }
local cos, sin, pi = math.cos, math.sin, math.pi
local plans = {}
-- One broken stone of about a metre at the origin.
function Debris.vertices()
  local list = Builder.list(nil)
  Builder.chunk(list, { 0, 0, 0 }, Fall.half, 0, Fall.seed, Fall.shade)
  return list
end
local function plan(def)
  local found = plans[def.id]
  if not found then
    local seed = 0
    for i = 1, #def.id do
      seed = (seed * 31 + def.id:byte(i)) % 9973 -- constant: a string hash
    end
    local rng = Builder.random(seed + 1)
    found = {}
    local hole = def.hole
    for i = 1, Debris.count do
      local stone = {}
      if i % 3 == 0 then
        -- The shaft itself.
        local a = rng() * 2 * pi
        local S = Fall.shaft
        stone.x, stone.z = def.cell[1] + cos(a) * S.reach, def.cell[2] + sin(a) * S.reach
        stone.y, stone.delay = 1 + rng() * S.rise, rng() * S.delay
      else
        -- The roof it carried, a little after.
        local a, d = rng() * 2 * pi, math.sqrt(rng())
        local reach = Ruin.holeEdge(hole, a) * d
        stone.x, stone.z = hole.x + cos(a) * reach, hole.z + sin(a) * reach
        local R = Fall.roof
        stone.y, stone.delay = R.height + rng() * R.rise, R.delay + rng() * R.wait
      end
      stone.size = Fall.size + rng() ^ 2 * Fall.sizeVary
      stone.spin, stone.yaw = (rng() - 0.5) * Fall.spin, rng() * Fall.yaw
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
            local y = s.y - Fall.halfGravity * fall * fall
            local rest = Fall.rest * s.size
            local landed = y <= rest
            r:object(
              mesh,
              s.x,
              landed and rest - (t - s.delay - 1) * Fall.sink or y,
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
