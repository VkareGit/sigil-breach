-- Stateless sampling of the common world view. Never holds a borrowed query,
-- changes encounter clocks, or knows a map/creature id. Caller owns `out`.
local Context = require('src.session.context')
local Queries = require('src.session.queries')
local Pools = require('src.session.world')
local Scene = {}
function Scene.weight(r, x, z)
  local dx = math.max(r.x1 - x, 0, x - r.x2)
  local dz = math.max(r.z1 - z, 0, z - r.z2)
  local t = math.max(0, 1 - math.sqrt(dx * dx + dz * dz) / r.fade)
  return t * t * (3 - 2 * t)
end
function Scene.sample(g, out)
  local config = g.world and g.world.decor and g.world.decor.soundscape
  local p = Context.viewer(g)
  out.config, out.stage, out.pressure, out.returning = config, 'traversal', 0, 0
  if not config or not p or g.state ~= 'playing' or g.map or g.help then
    out.config = nil
    return out
  end
  out.x, out.z = p.x, p.z
  local view = Queries.world(g)
  local active, pressure = false, 0
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.hp > 0 and e.awake then
      local d = math.sqrt((e.x - p.x) ^ 2 + (e.z - p.z) ^ 2)
      if d < 24 then
        active = true
        local near = math.max(0, 1 - d / 12)
        local committed = (e.ai == 'windup' or e.ai == 'strike') and 0.3 or 0
        pressure = math.max(pressure, near * 0.6 + committed)
      end
    end
  end
  if view.encounterStatus == 'active' and #(view.gates or {}) > 0 then
    out.stage = 'summoning'
  elseif active then
    out.stage = 'duel'
    out.pressure = math.min(1, pressure + math.max(0, 1 - (p.hp or 100) / (p.maxHp or 100)) * 0.25)
  elseif view.encounterFinished and view.encounterStatus == 'complete' then
    local age = math.max(0, (g.elapsed or 0) - view.encounterFinished)
    out.returning = math.min(1, math.max(0, age - config.aftermathHold) / config.aftermathFade)
    out.stage = out.returning < 1 and 'aftermath' or 'traversal'
  end
  return out
end
function Scene.spatial(scene, id)
  local sum, weight = 0, 0
  for _, r in ipairs(scene.config.regions or {}) do
    local w = Scene.weight(r, scene.x, scene.z)
    sum, weight = sum + (r.mix[id] or 0) * w, weight + w
  end
  return (sum + (scene.config.base[id] or 0) * math.max(0, 1 - weight)) / math.max(1, weight)
end
function Scene.gain(scene, id, pressure)
  local c, stage = scene.config, scene.stage
  if stage == 'traversal' then
    return Scene.spatial(scene, id)
  end
  if stage == 'duel' then
    local low, high = c.duel[id] or 0, c.pressure[id] or 0
    return low + (high - low) * pressure
  end
  local value = c[stage][id] or 0
  if stage == 'aftermath' then
    value = value + (Scene.spatial(scene, id) - value) * scene.returning
  end
  return value
end
return Scene
