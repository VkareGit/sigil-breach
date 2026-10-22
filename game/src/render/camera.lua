-- Presentation-only camera and the projection of the authoritative firing ray.
-- Recoil can move the view; the reticle must still mark where the shot goes.
local T = require('src.content.tuning')
local Layout = require('src.ui.layout')
local Camera = {}
function Camera.roll(g)
  if g.view.motion == false then
    return 0
  end
  local t = g.time or 0
  local trauma = math.min(0.14, g.view.shake or 0)
  return math.max(-0.03, math.min(0.03, g.view.bank or 0)) * 0.9
    + trauma * (math.sin(t * 71) * 0.32 + math.sin(t * 113 + 1.3) * 0.18)
    + (g.view.rollPunch or 0)
end
function Camera.basis(g, right, up, forward)
  local p, motion = g.player, g.view.motion ~= false
  local yaw, pitch = p.yaw, p.pitch
  if g.state == 'menu' then
    yaw, pitch = math.pi - 0.30 + math.sin(g.time * 0.06) * 0.10, 0.22
  elseif motion then
    pitch = pitch + (g.view.aimKick or 0)
  end
  local sy, cy, sp, cp = math.sin(yaw), math.cos(yaw), math.sin(pitch), math.cos(pitch)
  local rx, ry, rz, ux, uy, uz = cy, 0, -sy, -sy * sp, cp, -cy * sp
  local roll = Camera.roll(g)
  local sr, cr = math.sin(roll), math.cos(roll)
  right[1], right[2], right[3] = rx * cr + ux * sr, ry * cr + uy * sr, rz * cr + uz * sr
  up[1], up[2], up[3] = ux * cr - rx * sr, uy * cr - ry * sr, uz * cr - rz * sr
  forward[1], forward[2], forward[3] = sy * cp, sp, cy * cp
  return (g.view.fov or T.baseFov) + (motion and (g.view.fovKick or 0) or 0)
end
local right, up, forward = {}, {}, {}
function Camera.dimensions(g, w, h)
  local _, _, vw, vh = Layout.scene(g, w, h)
  local height = Layout.hasBar(g) and math.floor(T.renderHeight * 5 / 6) or T.renderHeight
  return math.floor(height * vw / vh + 0.5), height
end
-- Logical GUI coordinates, accounting for the scene and GUI's distinct
-- viewports (the classic scene fills the window; the field has a status bar).
function Camera.reticle(g, w, h)
  local fov = Camera.basis(g, right, up, forward)
  local p = g.player
  local cp = math.cos(p.pitch)
  local dx, dy, dz = math.sin(p.yaw) * cp, math.sin(p.pitch), math.cos(p.yaw) * cp
  local depth = dx * forward[1] + dy * forward[2] + dz * forward[3]
  local vx, vy, vw, vh = Layout.scene(g, w, h)
  local scale, ox, oy = Layout.viewport(w, h)
  local rw, rh = Camera.dimensions(g, w, h)
  local zoom = 0.5 / math.tan(math.rad(fov) * 0.5)
  local x = vx + vw * 0.5 + vw * zoom * (dx * right[1] + dy * right[2] + dz * right[3]) / depth
  local y = vy + vh * 0.5 - vh * rw / rh * zoom * (dx * up[1] + dy * up[2] + dz * up[3]) / depth
  return (x - ox) / scale, (y - oy) / scale
end
return Camera
