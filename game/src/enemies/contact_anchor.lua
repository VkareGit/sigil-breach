-- An attacking hand/muzzle is registered on the same source painting as its
-- visible pose. UV supplies sideways position and height, never invented depth.
-- Forward reach is a physical property of the action (content/defs/action.lua).
local Pose = require('src.enemies.pose')
local Anatomy = require('src.content.art.anatomy_regions')
local Anchor = {}
-- Sampling a past contact must not advance or temporarily mutate live AI:
-- the pose is read from a view of the body with its own phase and place.
-- The view and the sampled pose are reused (no allocation per claw sub-step);
-- the result is the same as with fresh tables: every field is written first.
local view, lens, pose = {}, {}, {}
setmetatable(view, lens)
-- observer (plan v11 E4): the body the strike is aimed at (default: the
-- creature's target, enemies/pose.lua: observerOf).
function Anchor.point(g, e, phase, x, z, name, observer)
  lens.__index = e
  view.phase, view.x, view.z = phase, x, z
  local p = Pose.sample(g, view, pose, observer or Pose.observerOf(g, e))
  lens.__index = nil
  local layout = p.ability and Anatomy.abilities[p.ability] or Anatomy.layouts[p.regions]
  local frame = layout and layout.frames[p.abilityFrame or p.frame]
  local anchor = frame and frame.anchors and frame.anchors[name]
  if not anchor then
    return nil
  end
  local u, v = anchor[1], anchor[2]
  if p.mirror == 1 then
    u = 1 - u
  end
  local y = (1 - v) * p.sy * p.size
  local lateral = (u - 0.5) * p.sx * p.size + y * p.lean + p.shift
  -- Height above the common ground, like all Melee.contact inputs.
  return x + math.cos(p.yaw) * lateral, p.baseY + y, z - math.sin(p.yaw) * lateral
end
return Anchor
