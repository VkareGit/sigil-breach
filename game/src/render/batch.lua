-- Stream one compact instance record per particle, not 36 expanded vertices.
local M = require('src.render.mesh')
local B = {}
local white = { 1, 1, 1 }
local zero = { 0, 0, 0 }
function B.new(source, capacity)
  local vertices = {}
  for i = 1, capacity do
    vertices[i] = { 0, 0, 0, 0, 0, 0, 0 }
  end
  local instances = love.graphics.newMesh({
    { 'InstanceOffset', 'float', 3 },
    { 'InstanceScale', 'float', 1 },
    { 'InstanceTint', 'float', 3 },
  }, capacity, 'points', 'stream')
  local mesh = M.finish(source)
  for _, attribute in ipairs({ 'InstanceOffset', 'InstanceScale', 'InstanceTint' }) do
    mesh:attachAttribute(attribute, instances, 'perinstance')
  end
  return setmetatable(
    { capacity = capacity, vertices = vertices, instances = instances, mesh = mesh, count = 0 },
    { __index = B }
  )
end
function B:clear()
  self.count = 0
end
function B:add(x, y, z, scale, color)
  if self.count >= self.capacity then
    return false
  end
  color = color or white
  local v = self.vertices[self.count + 1]
  v[1], v[2], v[3], v[4], v[5], v[6], v[7] = x, y, z, scale, color[1], color[2], color[3]
  self.count = self.count + 1
  return true
end
function B:draw(renderer, g)
  if self.count == 0 then
    return
  end
  self.instances:setVertices(self.vertices, 1, self.count)
  local shader = renderer.particleShader
  renderer:cameraUniforms(shader)
  renderer.lighting:bind(shader)
  shader:send('flash', g.view.muzzle * 2.5) -- particles must not flare into orange specks
  shader:send('flashColor', g.view.flashColor)
  shader:send('objectPos', zero)
  shader:send('objectYaw', 0)
  shader:send('objectScale', 1)
  shader:send('tint', white)
  shader:send('objectAlpha', 1)
  love.graphics.setShader(shader)
  love.graphics.drawInstanced(self.mesh, self.count)
  love.graphics.setShader(renderer.shader)
end
return B
