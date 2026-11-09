-- Particles, the world objects on the ground (render/world_objects.lua:
-- supplies, the Ember's ring and the echo) and the stains on the
-- floor.
local FrameLook = require('src.content.art.frame_look')
local DecalLook = require('src.content.feedback_look').effects
local WorldObjects = require('src.render.world_objects')
local Archetypes = require('src.content.enemies')
local Ground = require('src.physics.ground')
local COLORS = require('src.render.effects').colors
-- A particle near the eye shrinks away (content/art/frame_look.lua).
local PARTICLE_NEAR = FrameLook.particleNear
local Pass = {}
function Pass.draw(r, g, time, view)
  local lg = love.graphics
  lg.setDepthMode('less', true)
  r.particleBatch:clear()
  local cx, cy, cz = r.camera[1], r.camera[2], r.camera[3]
  for _, a in ipairs(g.view.particles) do
    local near = math.min(1, ((a.x - cx) ^ 2 + (a.y - cy) ^ 2 + (a.z - cz) ^ 2) / PARTICLE_NEAR ^ 2)
    r.particleBatch:add(a.x, a.y, a.z, (a.size or 1) * math.min(1, a.life * 6) * near, a.color)
  end
  r.particleBatch:draw(r, g)
  WorldObjects.draw(r, g, 'ground', view, time)
  lg.setDepthMode('less', false)
  for _, d in ipairs(g.view.decals or {}) do
    local def = Archetypes.get(d.kind)
    local color = def and def.appearance.stain or COLORS.blood
    r:object(
      r.stain,
      d.x,
      Ground.of(g.world, d) + FrameLook.decal.lift,
      d.z,
      d.rotation,
      d.size,
      color,
      FrameLook.decal.alpha * math.min(1, (DecalLook.decalLife - d.age) / FrameLook.decal.fade)
    )
  end
end
return Pass
