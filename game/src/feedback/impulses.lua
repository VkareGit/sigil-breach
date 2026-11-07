-- PLAN E5: the one way presentation impulses meet in a view. Responses join:
-- a weaker one that arrives while a stronger one lasts never lowers it.
local Impulses = {}
-- The camera's shake (render/camera.lua reads it; systems/clocks.lua lets it fade).
function Impulses.shake(view, amount)
  view.shake = math.max(view.shake or 0, amount)
end
return Impulses
