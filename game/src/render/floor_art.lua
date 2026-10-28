-- Persistent painted traces are map scenery, separate from damage telegraphs
-- and temporary impact marks. One reusable quad; no simulation mutations,
-- per-frame native allocations, or special branches for individual maps.
local Environment = require('src.content.art.environment')
local Ground = require('src.physics.ground')
local Art = {}
local corners = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
local indices = { 1, 2, 3, 1, 3, 4 }
function Art.init(r)
  local vertices = {}
  for i = 1, 6 do
    vertices[i] = { 0, 0, 0, 0, 0, 1, 1, 1, 1 }
  end
  r.floorArtVertices = vertices
  r.floorArtMesh = r.native:own(love.graphics.newMesh({
    { 'VertexPosition', 'float', 3 },
    { 'VertexTexCoord', 'float', 2 },
    { 'VertexColor', 'float', 4 },
  }, vertices, 'triangles', 'stream'))
end
function Art.draw(r, g)
  local entries = (g.world.decor or {}).floorArt
  if not entries or #entries == 0 then
    return
  end
  local lg, shader = love.graphics, r.markShader
  lg.push('all')
  lg.setShader(shader)
  lg.setDepthMode('less', false)
  lg.setColor(1, 1, 1)
  r:cameraUniforms(shader)
  shader:send('objectPos', r:vec3(0, 0, 0))
  shader:send('objectScale', 1)
  shader:send('objectYaw', 0)
  for _, item in ipairs(entries) do
    local entry = Environment[item.art]
    local uv, yaw = entry.rect, item.yaw or 0
    local c, s = math.cos(yaw), math.sin(yaw)
    local y = Ground.height(g.world, item.x, item.z) + 0.012
    local red, green, blue = r.lighting:sample(item.x, y, item.z)
    local gain = item.brightness or 1
    for j, index in ipairs(indices) do
      local q, vertex = corners[index], r.floorArtVertices[j]
      local x, z = q[1] * item.width * 0.5, q[2] * item.depth * 0.5
      vertex[1], vertex[2], vertex[3] = item.x + x * c + z * s, y, item.z - x * s + z * c
      vertex[4], vertex[5] = uv[1] + (q[1] + 1) * 0.5 * uv[3], uv[2] + (q[2] + 1) * 0.5 * uv[4]
      vertex[6], vertex[7], vertex[8], vertex[9] = red * gain, green * gain, blue * gain, 1
    end
    r.floorArtMesh:setVertices(r.floorArtVertices)
    r.floorArtMesh:setTexture(r.resources:image(entry.path, entry))
    lg.draw(r.floorArtMesh)
  end
  lg.pop()
end
return Art
