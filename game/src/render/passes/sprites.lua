-- Painted sprites: the world objects of this pass (render/world_objects.lua:
-- murals, the Ember, props, painted supplies, the gallery), then the demons
-- themselves (alive, and dead for 25 s), one instanced draw per image.
local WorldObjects = require('src.render.world_objects')
local Corpse = require('src.enemies.corpse')
local Pools = require('src.session.world')
local Pass = {}
function Pass.draw(r, g, time, view)
  love.graphics.setShader(r.spriteShader)
  WorldObjects.draw(r, g, 'sprites', view, time)
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.hp > 0 or Corpse.visible(e) then
      r:enemy(g, e, r.bodies)
    end
  end
  r:drawBodies()
end
return Pass
