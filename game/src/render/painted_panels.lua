-- Bounded world-space panels shared by painted ground warnings.
local HazardArt = require('src.render.hazard_art')
local Rites = require('src.content.art.rites')
local Ground = require('src.physics.ground')
local Context = require('src.session.context')
local Panels = {}
local corners = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 0 }, { 1, 1 }, { 0, 1 } }
local function geometry(r)
  local cache = r.paintedPanels
  if not cache then
    local count = Rites.panels.limit
    local vertices = {}
    for _ = 1, count * 6 do
      vertices[#vertices + 1] = { 0, 0, 0, 0, 0 }
    end
    cache = {
      vertices = vertices,
      mesh = r.native:own(
        love.graphics.newMesh(
          { { 'VertexPosition', 'float', 3 }, { 'VertexTexCoord', 'float', 2 } },
          vertices,
          'triangles',
          'dynamic'
        )
      ),
    }
    r.paintedPanels = cache
  end
  return cache
end
function Panels.draw(r, g, h, style, cell, count, radius, width, height, alpha, base)
  assert(count > 0 and count <= Rites.panels.limit, 'painted panels exceed their bounded mesh')
  local cache = geometry(r)
  local viewer = Context.viewer(g)
  for i = 1, count do
    local a = (i - 0.5) / count * math.pi * 2
    local x, z = math.sin(a) * radius, math.cos(a) * radius
    local dx, dz = viewer.x - h.x - x, viewer.z - h.z - z
    local near = math.min(1, (dx * dx + dz * dz) / (style.near * style.near))
    local yaw = math.atan2(dx, dz)
    for j, corner in ipairs(corners) do
      local v = cache.vertices[(i - 1) * 6 + j]
      local side = (0.5 - corner[1]) * width * near
      v[1], v[2], v[3] =
        x + math.cos(yaw) * side,
        (base or 0) + height * (0.5 + (corner[2] - 0.5) * near),
        z - math.sin(yaw) * side
      v[4], v[5] = corner[1], 1 - corner[2]
    end
  end
  cache.mesh:setVertices(cache.vertices)
  cache.mesh:setDrawRange(1, count * 6)
  love.graphics.push('all')
  love.graphics.setDepthMode('less', false)
  love.graphics.setColor(1, 1, 1)
  HazardArt.mesh(r, h, cell, cache.mesh, Ground.of(g.world, h), alpha)
  love.graphics.pop()
end
return Panels
