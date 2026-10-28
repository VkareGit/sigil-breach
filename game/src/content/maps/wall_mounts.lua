-- Authoring check for flat ornaments attached to cardinal masonry faces.
-- Check every crossed cell, not only the centre: a long frieze must stop at
-- a doorway. This is a content-time check, never per-frame clipping.
local M = {}
function M.check(item, width, opened, label, columns, rows)
  if item.wallMounted == nil or item.wallMounted == false then
    return
  end
  assert(item.wallMounted == true, label .. '.wallMounted must be boolean')
  local yaw = assert(item.yaw, label .. ': wall-mounted art requires yaw')
  local nx, nz = math.sin(yaw), math.cos(yaw)
  assert(math.abs(nx * nz) < 1e-8, label .. ': wall mount requires a cardinal face')
  -- All authored flat wall art stands 0.08–0.20 m in front of its backing.
  -- A quarter-metre probe must reach masonry, throughout the full width.
  local x, z = item.x - nx * 0.25, item.z - nz * 0.25
  local alongX = math.abs(nz) > 0.5
  local centre = alongX and x or z
  local first = math.floor(centre - width / 2 + 0.5 + 1e-8)
  local last = math.floor(centre + width / 2 + 0.5 - 1e-8)
  for i = first, last do
    local cx = alongX and i or math.floor(x + 0.5)
    local cz = alongX and math.floor(z + 0.5) or i
    assert(
      cx >= 1 and cx <= columns and cz >= 1 and cz <= rows and not (opened[cz] and opened[cz][cx]),
      label .. ': unsupported wall ornament at cell ' .. cx .. ',' .. cz
    )
  end
end
return M
