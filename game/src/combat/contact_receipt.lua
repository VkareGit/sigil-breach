-- Optional event-only geometry, made after a contact has been accepted. These
-- values contain no body/definition pointers and never drive damage or a second
-- hit test. point is the closest point on the body; sphereCenter is distinct.
local Receipt = {}

function Receipt.sphere(x, y, z, radius, cx, cz, bottom, top, bodyRadius)
  local dx, dz = x - cx, z - cz
  local distance = math.sqrt(dx * dx + dz * dz)
  local scale = distance > 0 and math.min(1, bodyRadius / distance) or 1
  return {
    geometry = 'sphere-cylinder',
    radius = radius,
    sphereCenter = { x = x, y = y, z = z },
    point = {
      x = cx + dx * scale,
      y = math.max(bottom, math.min(top, y)),
      z = cz + dz * scale,
    },
    bounds = { x = cx, z = cz, bottom = bottom, top = top, radius = bodyRadius },
  }
end

return Receipt
