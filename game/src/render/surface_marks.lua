local Marks = require('src.feedback.surface_marks')
local R = {}
local format = {
  { 'VertexPosition', 'float', 3 },
  { 'VertexTexCoord', 'float', 2 },
  { 'VertexColor', 'float', 4 },
}
local indices = { 1, 2, 3, 1, 3, 4 }
function R.init(r)
  r.markImage = love.graphics.newImage(Marks.path)
  r.markImage:setFilter('nearest', 'nearest')
  r.markMesh = love.graphics.newMesh(format, Marks.limit * 6, 'triangles', 'stream')
  r.markMesh:setTexture(r.markImage)
  r.markVertices = {}
  for i = 1, Marks.limit * 6 do
    r.markVertices[i] = { 0, 0, 0, 0, 0, 1, 1, 1, 1 }
  end
  r.markShader = love.graphics.newShader(require('src.render.shaders').surface)
end
local corners = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
function R.draw(r, g)
  local count = 0
  for _, d in ipairs(g.view.surfaceMarks or {}) do
    if (r.camera[1] - d.x) * d.nx + (r.camera[2] - d.y) * d.ny + (r.camera[3] - d.z) * d.nz > 0 then
      local ux, uy, uz = d.nz, 0, -d.nx
      if math.abs(d.ny) > 0.7 then
        ux, uy, uz = 1, 0, 0
      end
      local vx, vy, vz = d.ny * uz - d.nz * uy, d.nz * ux - d.nx * uz, d.nx * uy - d.ny * ux
      local cr, sr = math.cos(d.rotation), math.sin(d.rotation)
      local red, green, blue = r.lighting:sample(d.x, d.y, d.z)
      local col, row = (d.frame - 1) % 2, math.floor((d.frame - 1) / 2)
      for j, index in ipairs(indices) do
        local q = corners[index]
        local a, b = q[1] * d.size * 0.5 * d.stretch, q[2] * d.size * 0.5
        local u, v = a * cr - b * sr, a * sr + b * cr
        local vertex = r.markVertices[count + j]
        vertex[1], vertex[2], vertex[3] =
          d.x + ux * u + vx * v, d.y + uy * u + vy * v, d.z + uz * u + vz * v
        -- Clip at the edge of the painted panel instead of wrapping a flat card
        -- around a corner into air. The alpha gutter conceals this tiny trim.
        if d.surface == 'wall' then
          if d.nx ~= 0 then
            vertex[3] = math.max(
              math.floor(d.z + 0.5) - 0.497,
              math.min(math.floor(d.z + 0.5) + 0.497, vertex[3])
            )
          else
            vertex[1] = math.max(
              math.floor(d.x + 0.5) - 0.497,
              math.min(math.floor(d.x + 0.5) + 0.497, vertex[1])
            )
          end
          vertex[2] = math.max(0.005, vertex[2])
        end
        vertex[4], vertex[5] = (col + (q[1] + 1) * 0.5) * 0.5, (row + (q[2] + 1) * 0.5) * 0.5
        vertex[6], vertex[7], vertex[8], vertex[9] =
          math.min(1, red + 0.12),
          math.min(1, green + 0.12),
          math.min(1, blue + 0.12),
          Marks.alpha(d)
      end
      count = count + 6
      if count >= Marks.limit * 6 then
        break
      end
    end
  end
  if count == 0 then
    return
  end
  r.markMesh:setVertices(r.markVertices, 1, count)
  r.markMesh:setDrawRange(1, count)
  local shader = r.markShader
  r:cameraUniforms(shader)
  shader:send('objectPos', { 0, 0, 0 })
  shader:send('objectYaw', 0)
  shader:send('objectScale', 1)
  love.graphics.setShader(shader)
  love.graphics.setDepthMode('less', false)
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(r.markMesh)
end
return R
