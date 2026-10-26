-- Incoming weight is readable before it lands: the orb grows with the
-- packet's impact, its ember takes the damage-type colour and a short
-- trail behind it shows speed and direction (src/feedback/weight.lua colours).
local Weight = require('src.feedback.weight')
local Ground = require('src.physics.ground')
local Pools = require('src.session.world')
local COLORS = require('src.render.effects').colors
local Pass = {}
function Pass.draw(r, g)
  local lg = love.graphics
  lg.setShader(r.shader)
  lg.setDepthMode('less', false)
  for _, b in ipairs(Pools.of(g, 'projectiles')) do
    local packet = b.packet or {}
    local heavy = math.min(1, (packet.impact or (b.big and 60 or 40)) / 120)
    -- Fairness: the painted rim is the collision radius (orb mesh radius .09),
    -- never smaller; impact shows in the trail and the core, not in the hitbox.
    local radius = b.radius or (b.big and 0.26 or 0.12)
    local scale = radius / 0.09 / 0.82 * 1.04
    local tint = Weight.typeColor(packet.damageType)
    -- Floor marker: where the projectile passes, readable while dodging.
    lg.setDepthMode('less', false)
    r:object(r.warning, b.x, Ground.of(g.world, b) + 0.03, b.z, 0, radius * 2.2, tint, 0.45)
    local vx, vy, vz = b.vx or 0, b.vy or 0, b.vz or 0
    local speed = math.sqrt(vx * vx + vy * vy + vz * vz)
    if speed > 0.01 then
      local step = math.min(0.22, speed * 0.035) / speed
      for i = 3, 1, -1 do
        local k = 1 - i * 0.24
        local trail = r.trailTint or { 0, 0, 0 }
        r.trailTint = trail
        trail[1], trail[2], trail[3] = tint[1] * 0.55, tint[2] * 0.55, tint[3] * 0.55
        r:object(
          r.orb,
          b.x - vx * step * i,
          b.y - vy * step * i,
          b.z - vz * step * i,
          0,
          scale * 0.62 * k,
          trail
        )
      end
    end
    -- A dark rim of the same pigment (not a black disc) keeps the silhouette
    -- readable on bright plaster without punching a hole in the fresco.
    local rim = r.rimTint or { 0, 0, 0 }
    r.rimTint = rim
    rim[1], rim[2], rim[3] = 0.04 + tint[1] * 0.16, 0.03 + tint[2] * 0.12, 0.03 + tint[3] * 0.12
    r:object(r.orb, b.x, b.y, b.z, 0, scale * 0.82, rim)
    r:object(r.orb, b.x, b.y, b.z, 0, scale * 0.56, tint)
    r:object(r.orb, b.x, b.y, b.z, 0, scale * (0.22 + 0.12 * heavy), COLORS.bone)
  end
end
return Pass
