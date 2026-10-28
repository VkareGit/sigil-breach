-- Read scene depth AFTER painted opaque surfaces and bodies have written it.
-- Blended gates never write depth: their holes must reveal the scene behind.
local WorldObjects = require('src.render.world_objects')
local Pass = {}
function Pass.draw(r, g, time, view)
  love.graphics.push('all')
  love.graphics.setDepthMode('less', false)
  WorldObjects.draw(r, g, 'translucent', view, time)
  love.graphics.pop()
end
return Pass
