-- Quads drawn together (plan v10 V3): one instanced draw for every quad that
-- shares a texture, not one draw per quad. A record per quad carries what a
-- single draw would send as uniforms, in the order of the format's
-- attributes. Groups are drawn in the order their first quad came, and the
-- quads of a group in the order they came.
local Instances = {}
Instances.__index = Instances
local QUAD_FORMAT = { { 'VertexPosition', 'float', 3 }, { 'VertexTexCoord', 'float', 2 } }
-- quad: the vertices of the quad (QUAD_FORMAT); format: the per-instance
-- attributes; owner: the resource scope that releases the meshes.
function Instances.new(quad, format, owner)
  local width = 0
  for _, attribute in ipairs(format) do
    width = width + attribute[3]
  end
  return setmetatable({
    quad = quad,
    format = format,
    width = width,
    owner = owner,
    groups = {},
    byKey = {},
    count = 0,
  }, Instances)
end
local function grow(self, group, capacity)
  local instances = self.owner:own(love.graphics.newMesh(self.format, capacity, 'points', 'stream'))
  for _, attribute in ipairs(self.format) do
    group.mesh:attachAttribute(attribute[1], instances, 'perinstance')
  end
  if group.instances then
    self.owner:free(group.instances)
  end
  group.instances, group.capacity = instances, capacity
end
local function open(self, key, image)
  local group = self.byKey[key]
  if group then
    return group
  end
  self.count = self.count + 1
  group = self.groups[self.count]
  if not group then
    group = {
      mesh = self.owner:own(love.graphics.newMesh(QUAD_FORMAT, self.quad, 'triangles', 'static')),
      records = {},
    }
    grow(self, group, 64)
    self.groups[self.count] = group
  end
  group.key, group.image, group.used = key, image, 0
  self.byKey[key] = group
  return group
end
-- The record of one more quad of image (key: the group, by default the
-- image); fill its fields in the format's order.
function Instances:add(image, key)
  local group = open(self, key or image, image)
  group.used = group.used + 1
  local record = group.records[group.used]
  if not record then
    record = {}
    for i = 1, self.width do
      record[i] = 0
    end
    group.records[group.used] = record
  end
  return record
end
-- Draw every group with the current shader and forget them; prepare(key),
-- when given, runs before each group's draw.
function Instances:draw(prepare)
  for i = 1, self.count do
    local group = self.groups[i]
    if group.used > group.capacity then
      local capacity = group.capacity
      while capacity < group.used do
        capacity = capacity * 2
      end
      grow(self, group, capacity)
    end
    group.instances:setVertices(group.records, 1, group.used)
    group.mesh:setTexture(group.image)
    if prepare then
      prepare(group.key)
    end
    love.graphics.drawInstanced(group.mesh, group.used)
    self.byKey[group.key] = nil
    group.key, group.image = nil, nil
  end
  self.count = 0
end
return Instances
