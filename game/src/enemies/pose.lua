-- The complete authored placement of a creature, shared by collision and drawing.
-- Reads immutable art metadata and action clocks; never reads hit volumes or GPU state.
local Animation = require('src.enemies.animation')
local Archetypes = require('src.content.enemies')
local EnemyArt = require('src.content.enemy_art')
local AbilityArt = require('src.content.ability_art')
local AbilityPose = require('src.enemies.ability_pose')
local Roles = require('src.core.roles')
-- The bearing from body e to the viewer (core/roles.lua): what a
-- billboard turns to and what its back frames are judged against.
local function viewerYaw(g, e)
  local v = Roles.viewer(g)
  return math.atan2(v.x - e.x, v.z - e.z)
end
local Pose = {}
function Pose.base(g, e)
  local frame, hover, lean, sx, sy = Animation.pose(g, e)
  local atlas = Archetypes.look(e).atlas or e.kind
  local layout = assert(EnemyArt.layouts[atlas], 'unknown sprite placement: ' .. tostring(atlas))
  local region = assert(layout.frames[frame], 'unknown sprite frame')
  sx, sy = sx * region.width, sy * region.height
  local size = layout.size
  local width, height = size * sx, size * sy
  return frame, hover, lean, sx, sy, size, width, height, hover - layout.feet[frame] * height, atlas
end
-- Named art registration points belong to the painting, not a collision shape.
-- Local x is measured from the sprite centre; y is measured up from its UV base.
function Pose.anchor(g, e, name)
  local frame, _, lean, _, _, _, width, height, baseY, atlas = Pose.base(g, e)
  local anchor =
    assert(EnemyArt.layouts[atlas].frames[frame].registration[name], 'unknown art anchor')
  local y = baseY + anchor.y * height
  local shift = anchor.x * width + anchor.y * height * lean
  local yaw = viewerYaw(g, e)
  return e.x + math.cos(yaw) * shift, y, e.z - math.sin(yaw) * shift
end
function Pose.sample(g, e, out)
  local frame, hover, lean, sx, sy, size, _, _, baseY, atlas = Pose.base(g, e)
  local region = EnemyArt.layouts[atlas].frames[frame]
  local key, index, mirror = AbilityPose.select(g, e)
  local shift = 0
  local sourcePath = region.sourcePath
  if key then
    local sheet = AbilityArt[key]
    region = sheet.frames[index]
    local hx, hy, hz = Pose.anchor(g, e, 'head')
    local rise = 1 - region.head[2] - sheet.feet[index]
    local scale = (hy - hover) / (rise * region.height * size)
    sx, sy = region.width * scale, region.height * scale
    baseY = hover - sheet.feet[index] * size * sy
    local yaw = viewerYaw(g, e)
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
  p.yaw = viewerYaw(g, e)
  p.shift, p.painted, p.sourcePath = shift, key ~= nil, sourcePath
  p.ability, p.abilityFrame = key, index
  return p
end
return Pose
