-- The complete authored placement of a creature, shared by collision and drawing.
-- Reads immutable art metadata and action clocks; never reads hit volumes or GPU state.
local Animation = require('src.enemies.animation')
local Archetypes = require('src.content.enemies')
local EnemyArt = require('src.content.enemy_art')
local AbilityArt = require('src.content.ability_art')
local AbilityPose = require('src.enemies.ability_pose')
local Roles = require('src.core.roles')
local Pools = require('src.session.world')
-- The bearing from body e to its observer (plan v11 E4; enemies/animation.lua):
-- named by the caller, else the controlled knight. Never the camera.
local function viewerYaw(g, e, observer)
  local v = observer or Roles.controlled(g)
  return math.atan2(v.x - e.x, v.z - e.z)
end
local Pose = {}
-- The observer of a creature's own geometry (its sight, its stature, its
-- claws): the body it fights (e.target), else the controlled knight.
function Pose.observerOf(g, e)
  local controlled = Roles.controlled(g)
  local id = e and e.target
  -- (A hand-made controlled knight without an id stands for every knight.)
  if id == nil or (controlled and (controlled.id == id or controlled.id == nil)) then
    return controlled
  end
  return Pools.get(g, id) or controlled
end
function Pose.base(g, e, observer)
  local frame, hover, lean, sx, sy = Animation.pose(g, e, observer)
  local atlas = Archetypes.look(e).atlas or e.kind
  local layout = EnemyArt.layouts[atlas]
  if not layout then
    error('unknown sprite placement: ' .. tostring(atlas))
  end
  local region = assert(layout.frames[frame], 'unknown sprite frame')
  sx, sy = sx * region.width, sy * region.height
  local size = layout.size
  local width, height = size * sx, size * sy
  return frame, hover, lean, sx, sy, size, width, height, hover - layout.feet[frame] * height, atlas
end
-- Named art registration points belong to the painting, not a collision shape.
-- Local x is measured from the sprite centre; y is measured up from its UV base.
function Pose.anchor(g, e, name, observer)
  local frame, _, lean, _, _, _, width, height, baseY, atlas = Pose.base(g, e, observer)
  local anchor =
    assert(EnemyArt.layouts[atlas].frames[frame].registration[name], 'unknown art anchor')
  local y = baseY + anchor.y * height
  local shift = anchor.x * width + anchor.y * height * lean
  local yaw = viewerYaw(g, e, observer)
  return e.x + math.cos(yaw) * shift, y, e.z - math.sin(yaw) * shift
end
function Pose.sample(g, e, out, observer)
  local frame, hover, lean, sx, sy, size, _, _, baseY, atlas = Pose.base(g, e, observer)
  local region = EnemyArt.layouts[atlas].frames[frame]
  local key, index, mirror = AbilityPose.select(g, e)
  local shift = 0
  local sourcePath = region.sourcePath
  if key then
    local sheet = AbilityArt[key]
    region = sheet.frames[index]
    local hx, hy, hz = Pose.anchor(g, e, 'head', observer)
    local rise = 1 - region.head[2] - sheet.feet[index]
    local scale = (hy - hover) / (rise * region.height * size)
    sx, sy = region.width * scale, region.height * scale
    baseY = hover - sheet.feet[index] * size * sy
    local yaw = viewerYaw(g, e, observer)
    local targetX = (hx - e.x) * math.cos(yaw) - (hz - e.z) * math.sin(yaw)
    local headU = mirror == 1 and 1 - region.head[1] or region.head[1]
    local paintedX = (headU - 0.5) * sx * size + (1 - region.head[2]) * sy * size * lean
    shift = targetX - paintedX
    sourcePath = sheet.path
  end
  local p = out or {}
  p.atlas, p.frame, p.region, p.mirror = atlas, frame, region, mirror or 0
  -- The anatomy annotation of the atlas frames (an ability sheet has its own).
  p.regions = Archetypes.look(e).regions or atlas
  p.sx, p.sy, p.lean, p.size, p.baseY = sx, sy, lean, size, baseY
  p.yaw = viewerYaw(g, e, observer)
  p.shift, p.painted, p.sourcePath = shift, key ~= nil, sourcePath
  p.ability, p.abilityFrame = key, index
  return p
end
return Pose
