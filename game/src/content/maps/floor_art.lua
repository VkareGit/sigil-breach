-- Conservative rectangular support check for map-authored flat pigment.
-- A decal never bridges a step, a wall or a missing floor. Rotated footprints
-- use their bounding rectangle; keep them inside the authored clear space.
local finite = require('src.core.mathx').finite
local Environment = require('src.content.art.environment')
local Floor = {}
function Floor.check(items, map, opened)
  for _, item in ipairs(items or {}) do
    assert(Environment[item.art], 'floor art: unknown artwork')
    for _, key in ipairs({ 'width', 'depth', 'brightness' }) do
      assert(finite(item[key]) and item[key] > 0, 'floor art: invalid ' .. key)
    end
    assert(item.y == nil, 'floor art: height comes from the supporting floor')
    assert(item.yaw == nil or finite(item.yaw), 'floor art: invalid yaw')
    local c, s = math.abs(math.cos(item.yaw or 0)), math.abs(math.sin(item.yaw or 0))
    local hx, hz = (c * item.width + s * item.depth) / 2, (s * item.width + c * item.depth) / 2
    local height
    for z = math.floor(item.z - hz + 0.5 + 1e-8), math.floor(item.z + hz + 0.5 - 1e-8) do
      for x = math.floor(item.x - hx + 0.5 + 1e-8), math.floor(item.x + hx + 0.5 - 1e-8) do
        assert(opened[z] and opened[z][x], 'floor art: unsupported footprint')
        for _, pillar in ipairs(map.pillars or {}) do
          assert(pillar[1] ~= x or pillar[2] ~= z, 'floor art: crosses a pillar')
        end
        local level = 0
        for _, area in ipairs(map.elevations or {}) do
          if x >= area.x1 and x <= area.x2 and z >= area.z1 and z <= area.z2 then
            level = area.height
          end
        end
        assert(height == nil or height == level, 'floor art: crosses a floor step')
        height = level
      end
    end
  end
end
return Floor
