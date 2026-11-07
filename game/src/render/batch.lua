-- Stream one compact instance record per particle, not 36 expanded vertices.
-- A batch of stamps (plan v10 V3) also carries each instance's alpha and is
-- lit like the world it lies on (the shadow pools under bodies).
local Mesh = require('src.render.mesh')
local B = {}
local white = { 1, 1, 1 }
local zero = { 0, 0, 0 }
-- stamps: instances with an alpha of their own, drawn with the stamp shader
-- under the world's own muzzle flash.
function B.new(source, capacity, stamps)
  local vertices = {}
  local width = stamps and 8 or 7
  for i = 1, capacity do
    vertices[i] = {}
    for k = 1, width do
      vertices[i][k] = 0
    end
  end
  local format = {
    { 'InstanceOffset', 'float', 3 },
    { 'InstanceScale', 'float', 1 },
    { 'InstanceTint', 'float', 3 },
  }
  if stamps then
    format[#format + 1] = { 'InstanceAlpha', 'float', 1 }
  end
  local instances = love.graphics.newMesh(format, capacity, 'points', 'stream')
  local mesh = Mesh.finish(source)
  for _, attribute in ipairs(format) do
    mesh:attachAttribute(attribute[1], instances, 'perinstance')
  end
  return setmetatable({
    capacity = capacity,
    vertices = vertices,
    instances = instances,
    mesh = mesh,
    count = 0,
    stamps = stamps,
  }, { __index = B })
end
function B:clear()
  self.count = 0
end
function B:add(x, y, z, scale, color, alpha)
  if self.count >= self.capacity then
    return false
  end
  color = color or white
  local v = self.vertices[self.count + 1]
  v[1], v[2], v[3], v[4], v[5], v[6], v[7] = x, y, z, scale, color[1], color[2], color[3]
  if self.stamps then
    v[8] = alpha or 1
  end
  self.count = self.count + 1
  return true
end
function B:draw(renderer, g)
  if self.count == 0 then
    return
  end
  self.instances:setVertices(self.vertices, 1, self.count)
  local shader = self.stamps and renderer.stampShader or renderer.particleShader
  renderer:cameraUniforms(shader)
  renderer.lighting:bind(shader)
  if self.stamps then
    shader:send('flash', g.view.muzzle * 7)
  else
    shader:send('flash', g.view.muzzle * 2.5) -- particles must not flare into orange specks
    shader:send('objectAlpha', 1)
  end
  shader:send('flashColor', g.view.flashColor)
  shader:send('objectPos', zero)
  shader:send('objectYaw', 0)
  shader:send('objectScale', 1)
  shader:send('tint', white)
  love.graphics.setShader(shader)
  love.graphics.drawInstanced(self.mesh, self.count)
  love.graphics.setShader(renderer.shader)
end
return B
