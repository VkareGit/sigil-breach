-- PLAN E5: the one way presentation impulses meet in a view. Responses join:
-- a weaker one that arrives while a stronger one lasts never lowers it.
local Kinematics = require('src.physics.kinematics')
local Impulses = {}
-- The camera's shake (render/camera.lua reads it; systems/clocks.lua lets it fade).
function Impulses.shake(view, amount)
  view.shake = math.max(view.shake or 0, amount)
end
-- A blow to one spring of the view (key and key .. 'V'): velocity given at the
-- start of the step that shows it, its motion moved on by age at once, so it
-- shows in the frame of the event's flash. The springs are linear: the added
-- motion is a spring of its own, moved alone and added to what is there.
function Impulses.kick(view, key, velocity, spring, age)
  local x, v = Kinematics.spring(0, velocity, 0, spring[1], spring[2], age)
  local rate = key .. 'V'
  view[key], view[rate] = (view[key] or 0) + x, (view[rate] or 0) + v
end
return Impulses
