-- Explicit body volumes: the optional hit representation of a creature whose
-- appearance chooses hit = 'volumes' (cylinders named by its anatomy profile
-- in enemies/hit_volumes.lua). The painted creatures (hit = 'painted', the
-- default) meet shots on their painted surface (enemies/surface.lua) and
-- never prepare volumes. Shape identity is distinct from the damage zone: two
-- legs may share zone 'lower'. Also the pose metadata check the renderer runs
-- at load (register) and the shared pose (pose: enemies/pose.lua).
local Pose = require('src.enemies.pose')
local EnemyArt = require('src.content.enemy_art')
local HV = require('src.enemies.hit_volumes')
local Archetypes = require('src.content.enemies')
local Ground = require('src.physics.ground')
local Geometry = { layouts = EnemyArt.layouts }
local profiles = HV.profiles
local cache = setmetatable({}, { __mode = 'k' })
function Geometry.register(kind, frames, feet)
  -- Compatibility validation only: rendering can never install simulation data.
  local layout = assert(Geometry.layouts[kind], 'unknown authored layout')
  assert(#frames == #layout.frames and #feet == #layout.feet, 'sprite metadata count differs')
  for index, frame in ipairs(frames) do
    assert(
      frame.width == layout.frames[index].width
        and frame.height == layout.frames[index].height
        and feet[index] == layout.feet[index],
      'sprite metadata registration differs'
    )
  end
end
function Geometry.profile(name)
  return profiles[name]
end
Geometry.pose = Pose.base
-- True when shots meet this body's explicit volumes (its appearance chose
-- hit = 'volumes'); false for a painted body.
function Geometry.uses(e)
  return Archetypes.look(e).hit == 'volumes'
end
-- The body's volumes in world height for the current pose. Only for a body
-- that uses them (Geometry.uses); a painted body has none.
function Geometry.volumes(g, e)
  local look = Archetypes.look(e)
  assert(look.hit == 'volumes', 'a painted body meets shots on its surface (enemies/surface.lua)')
  local profile =
    assert(profiles[look.anatomy], 'unknown body-volume profile ' .. tostring(look.anatomy))
  local frame, _, lean, _, _, size, width, height, baseY = Geometry.pose(g, e)
  local shapes = assert(
    profile.frameShapes and profile.frameShapes[frame] or profile.shapes,
    'body-volume profile ' .. look.anatomy .. ' has no shapes for frame ' .. frame
  )
  local yaw = math.atan2(g.player.x - e.x, g.player.z - e.z)
  local rx, rz = math.cos(yaw), -math.sin(yaw)
  local ground = Ground.height(g.world)
  local volumes = cache[e] or {}
  cache[e] = volumes
  local body = Archetypes.of(e)
  for index, shape in ipairs(shapes) do
    assert(
      not shape.shape or shape.shape == 'cylinder',
      'unsupported body-volume shape: ' .. tostring(shape.shape)
    )
    local v = volumes[index] or {}
    volumes[index] = v
    v.id, v.zone, v.name = shape.id, shape.zone, shape.zone
    v.shape = shape.shape or 'cylinder'
    v.material = shape.material or (body and body.body.struck) or 'flesh'
    v.bottom, v.top = baseY + height * shape.bottom, baseY + height * shape.top
    -- Sprite shear happens after stretch, in local units, before objectScale.
    local localY = ((v.bottom + v.top) * 0.5 - baseY) / size
    local shift = localY * lean * size + (shape.x - 0.5) * width
    v.x, v.z = e.x + rx * shift, e.z + rz * shift
    v.radius = width * shape.radius
    v.bottom, v.top = ground + v.bottom, ground + v.top
  end
  for index = #volumes, #shapes + 1, -1 do
    volumes[index] = nil
  end
  return volumes
end
function Geometry.find(g, e, id)
  for _, shape in ipairs(Geometry.volumes(g, e)) do
    if shape.id == id then
      return shape
    end
  end
end
return Geometry
