-- Opaque architecture: the sky, the world mesh, then the world objects of
-- this pass (render/world_objects.lua: the lamps' sparks, the seals).
local WorldObjects = require('src.render.world_objects')
local Environment = require('src.content.art.environment')
local Halls = require('src.render.kit.halls')
local Pass = {}
function Pass.draw(r, g, time, view)
  local lg = love.graphics
  r:sky(g)
  r:cameraUniforms(r.shader)
  r:cameraUniforms(r.spriteShader)
  -- The infernal witness is painted into the distant panorama. Reusing a live
  -- boss sprite here made it read as a giant hovering combat target.
  lg.setColor(1, 1, 1)
  lg.setShader(r.shader)
  lg.setDepthMode('less', true)
  lg.setMeshCullMode('none')
  r.shader:send('flash', g.view.muzzle * 7)
  r.shader:send('flashColor', g.view.flashColor)
  r.lighting:send(r.shader, g, r.camera, r.forward)
  local paint = g.world.decor and Environment[g.world.decor.stonePaint]
  r.shader:send('useStonePaint', paint and 1 or 0)
  if paint then
    r.shader:send('stoneAtlas', r.resources:image(paint.path, paint))
    r.shader:send('stoneRect', paint.rect)
  end
  r:object(r.worldMesh)
  Halls.draw(r, g, r.hallMeshes)
  WorldObjects.draw(r, g, 'architecture', view, time)
end
return Pass
