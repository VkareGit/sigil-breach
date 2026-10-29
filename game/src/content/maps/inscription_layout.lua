-- An inscription belongs to a named painted surface, not to an unrelated
-- world-space point. u/v locate its centre (left->right, bottom->top).
-- Width/height are a reserved box in metres; the renderer fits without stretch.
local finite = require('src.core.mathx').finite
local L = {}
function L.surface(decor, id)
  local found
  for _, panel in ipairs(decor.murals or {}) do
    if panel.id == id then
      assert(not found, 'duplicate painted surface id: ' .. id)
      found = panel
    end
  end
  return assert(found, 'unknown inscription surface: ' .. tostring(id))
end
function L.check(item, decor)
  assert(type(item.surface) == 'string', 'inscription requires a named surface')
  assert(
    item.x == nil and item.y == nil and item.z == nil and item.yaw == nil,
    'surface inscription cannot also declare a world position'
  )
  local panel = L.surface(decor, item.surface)
  assert(panel.wallMounted, 'inscription surface must be wall-mounted')
  for _, key in ipairs({ 'u', 'v', 'width', 'height', 'margin' }) do
    assert(finite(item[key]), 'inscription ' .. key .. ' must be finite')
  end
  assert(
    item.width > 0 and item.height > 0 and item.margin >= 0.04,
    'inscription needs positive bounds and a visible margin'
  )
  local w, h = panel.width or panel.size, panel.size
  local cx, cy = item.u * w, item.v * h
  assert(
    cx - item.width / 2 >= item.margin
      and cx + item.width / 2 <= w - item.margin
      and cy - item.height / 2 >= item.margin
      and cy + item.height / 2 <= h - item.margin,
    'inscription exceeds painted surface or its margin: ' .. item.surface
  )
end
function L.resolve(item, decor, aspect, out)
  local panel = L.surface(decor, item.surface)
  local yaw = panel.yaw
  local sx, sz = math.cos(yaw), -math.sin(yaw)
  local nx, nz = math.sin(yaw), math.cos(yaw)
  local offset = (0.5 - item.u) * (panel.width or panel.size)
  -- A shallow physical offset keeps ink on its own plaster, even obliquely.
  out.x, out.z = panel.x + sx * offset + nx * 0.004, panel.z + sz * offset + nz * 0.004
  out.width = math.min(item.width, item.height / aspect)
  out.height = out.width * aspect
  out.y = panel.y + item.v * panel.size - out.height / 2
  out.yaw, out.surface = yaw, panel
  return out
end
return L
