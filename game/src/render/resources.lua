-- Explicit GPU ownership. Equal image variants may share a native handle;
-- filter/mipmap/wrap differences never mutate another consumer's artwork.
-- Scopes release deterministically; the LuaJIT guard also covers abandoned tools.
local Resources = {}
Resources.__index = Resources
local shared = {}

function Resources.new(label, checkpoint)
  local scope = setmetatable(
    { label = label, held = {}, owned = {}, closed = false, checkpoint = checkpoint },
    Resources
  )
  scope.guard = newproxy(true)
  getmetatable(scope.guard).__gc = function()
    scope:release()
  end
  return scope
end

function Resources:retain(key, create, destroy, descriptor)
  assert(not self.closed, 'resource scope is closed: ' .. tostring(self.label))
  if self.held[key] then
    return self.held[key].value
  end
  local entry = shared[key]
  if not entry then
    -- Failed construction never poisons the cache with a false success.
    entry = { value = assert(create()), destroy = destroy, refs = 0, descriptor = descriptor }
    shared[key] = entry
  end
  entry.refs = entry.refs + 1
  self.held[key] = entry
  if self.checkpoint then
    self.checkpoint(key)
  end
  return entry.value
end

function Resources:own(handle)
  assert(not self.closed, 'resource scope is closed: ' .. tostring(self.label))
  self.owned[handle] = true
  return handle
end

-- A variant is named once per (options table, path) and then reused, so the
-- lookup a renderer repeats every frame allocates nothing. An options table
-- is a descriptor: read when first seen, never changed after.
local defaults = {}
local variants = setmetatable({}, { __mode = 'k' })
local function variant(path, options)
  options = options or defaults
  local byPath = variants[options]
  if not byPath then
    byPath = {}
    variants[options] = byPath
  end
  local known = byPath[path]
  if known then
    return known.key, known.spec
  end
  local spec = {
    path = path,
    min = options.min or options.filter or 'nearest',
    mag = options.mag or options.filter or 'nearest',
    mipmaps = not not options.mipmaps,
    mipmapFilter = options.mipmapFilter or 'none',
    wrapX = options.wrapX or 'clamp',
    wrapY = options.wrapY or 'clamp',
  }
  assert(type(path) == 'string' and path ~= '', 'image resource needs a source path')
  local key = table.concat({
    'image',
    path,
    spec.min,
    spec.mag,
    tostring(spec.mipmaps),
    spec.mipmapFilter,
    spec.wrapX,
    spec.wrapY,
  }, '|')
  byPath[path] = { key = key, spec = spec }
  return key, spec
end
local function releaseImage(image)
  image:release()
end

function Resources:hasImage(path, options)
  local key = variant(path, options)
  return self.held[key] ~= nil
end

function Resources:image(path, options, decoded)
  local key, spec = variant(path, options)
  local held = self.held[key]
  if held then
    return held.value
  end
  return self:retain(key, function()
    local image = love.graphics.newImage(decoded or path, { mipmaps = spec.mipmaps })
    image:setFilter(spec.min, spec.mag)
    if spec.mipmapFilter ~= 'none' then
      image:setMipmapFilter(spec.mipmapFilter)
    end
    image:setWrap(spec.wrapX, spec.wrapY)
    spec.width, spec.height = image:getDimensions()
    return image
  end, releaseImage, spec)
end

-- Actual acquired dependencies, not a hand-maintained second asset catalogue.
function Resources:manifest()
  local out = {}
  for key, entry in pairs(self.held) do
    out[#out + 1] = { key = key, descriptor = entry.descriptor, refs = entry.refs }
  end
  table.sort(out, function(a, b)
    return a.key < b.key
  end)
  return out
end

function Resources:release()
  if self.closed then
    return
  end
  self.closed = true
  for key, entry in pairs(self.held) do
    entry.refs = entry.refs - 1
    if entry.refs == 0 then
      shared[key] = nil
      entry.destroy(entry.value)
    end
  end
  for handle in pairs(self.owned) do
    handle:release()
  end
  self.held, self.owned = {}, {}
end

return Resources
