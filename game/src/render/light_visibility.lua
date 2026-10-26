-- A cached 2.5D shadow atlas for the arena's solid walls and pillars.
-- Each light in a slot has its own tile (r: the light reaches, g: contact
-- shade, b: a wall). A map no wider than window cells is covered whole by
-- every tile (texels cells per texel side, as the first circle always was);
-- on a larger map a tile covers the window around its light, and a separate
-- ground image carries the contact shade and walls of the whole map at the
-- same density (plan v10 V3). Tiles are baked when a light takes a slot.
local Grid = require('src.physics.grid')
local V = { resolution = 128, columns = 4, capacity = 14, texels = 4 }
-- Cells covered by one tile around its light on a large map.
V.window = V.resolution / V.texels
local function solid(w, x, z)
  return not (w.map[z] and w.map[z][x] == 0)
end
function V.visible(w, lx, lz, x, z)
  local cx, cz = math.floor(lx + 0.5), math.floor(lz + 0.5)
  local tx, tz = math.floor(x + 0.5), math.floor(z + 0.5)
  if solid(w, cx, cz) then
    return false
  end
  local dx, dz = x - lx, z - lz
  local sx, sz = dx >= 0 and 1 or -1, dz >= 0 and 1 or -1
  local ax, az = math.abs(dx), math.abs(dz)
  local ix, iz = ax > 1e-8 and 1 / ax or math.huge, az > 1e-8 and 1 / az or math.huge
  local nx = ax > 1e-8 and math.abs(cx + sx * 0.5 - lx) / ax or math.huge
  local nz = az > 1e-8 and math.abs(cz + sz * 0.5 - lz) / az or math.huge
  for _ = 1, Grid.width(w) + Grid.depth(w) + 4 do
    if cx == tx and cz == tz then
      return true
    end
    if math.abs(nx - nz) < 1e-7 then
      if solid(w, cx + sx, cz) and solid(w, cx, cz + sz) then
        return false
      end
      cx, cz = cx + sx, cz + sz
      nx, nz = nx + ix, nz + iz
    elseif nx < nz then
      cx = cx + sx
      nx = nx + ix
    else
      cz = cz + sz
      nz = nz + iz
    end
    -- The final cell can be a wall: its facing surface receives light.
    if cx == tx and cz == tz then
      return true
    end
    if solid(w, cx, cz) then
      return false
    end
  end
  return false
end
function V.ambient(w, x, z)
  local cx, cz = math.floor(x + 0.5), math.floor(z + 0.5)
  local nearest = 2
  for oz = -2, 2 do
    for ox = -2, 2 do
      if solid(w, cx + ox, cz + oz) then
        local dx = math.max(0, math.abs(x - cx - ox) - 0.5)
        local dz = math.max(0, math.abs(z - cz - oz) - 0.5)
        nearest = math.min(nearest, math.sqrt(dx * dx + dz * dz))
      end
    end
  end
  return 0.72 + 0.28 * math.min(1, nearest / 1.35)
end
-- Whether every tile covers the whole map (the map fits the window).
function V.whole(w)
  return Grid.span(w) <= V.window
end
-- The world corner (x, z) a tile of a light at (x, z) starts at, and the
-- cells its side covers.
function V.frame(w, x, z)
  if V.whole(w) then
    return 0.5, 0.5, Grid.span(w)
  end
  return x - V.window / 2, z - V.window / 2, V.window
end
-- The atlas corner of slot i, in texels.
local function corner(i)
  return ((i - 1) % V.columns) * V.resolution, math.floor((i - 1) / V.columns) * V.resolution
end
-- Contact shade and walls of a tile's texels (row by row from its corner).
local function shade(w, fx, fz, span)
  local n = V.resolution
  local ao, blocked = {}, {}
  for z = 0, n - 1 do
    for x = 0, n - 1 do
      local wx, wz = fx + (x + 0.5) * span / n, fz + (z + 0.5) * span / n
      ao[z * n + x + 1] = V.ambient(w, wx, wz)
      blocked[z * n + x + 1] = solid(w, math.floor(wx + 0.5), math.floor(wz + 0.5)) and 1 or 0
    end
  end
  return ao, blocked
end
-- Paint the tile of source s into data at slot i (s nil: shade only).
-- ao, blocked: the tile's shade when every tile shares one frame.
local function paint(w, data, i, s, ao, blocked)
  local n = V.resolution
  local ox, oz = corner(i)
  local fx, fz, span = V.frame(w, s and s.x or 0, s and s.z or 0)
  if not ao then
    ao, blocked = shade(w, fx, fz, span)
  end
  for z = 0, n - 1 do
    for x = 0, n - 1 do
      local visible = s
        and V.visible(w, s.x, s.z, fx + (x + 0.5) * span / n, fz + (z + 0.5) * span / n)
      data:setPixel(
        ox + x,
        oz + z,
        visible and 1 or 0,
        ao[z * n + x + 1],
        blocked[z * n + x + 1],
        1
      )
    end
  end
end
-- The contact shade and walls of the whole map at texels per cell (capped
-- by the largest texture), for a map larger than the window.
local function ground(w)
  local limit = love.graphics.getSystemLimits().texturesize
  local width = math.min(Grid.width(w) * V.texels, limit)
  local depth = math.min(Grid.depth(w) * V.texels, limit)
  local data = love.image.newImageData(width, depth)
  for z = 0, depth - 1 do
    for x = 0, width - 1 do
      local wx = 0.5 + (x + 0.5) * Grid.width(w) / width
      local wz = 0.5 + (z + 0.5) * Grid.depth(w) / depth
      data:setPixel(
        x,
        z,
        1,
        V.ambient(w, wx, wz),
        solid(w, math.floor(wx + 0.5), math.floor(wz + 0.5)) and 1 or 0,
        1
      )
    end
  end
  local image = love.graphics.newImage(data)
  image:setFilter('linear', 'linear')
  return image, data
end
-- slots: the sources in the atlas's slots at first (at most capacity).
-- private: the slots will change (V.place), so the atlas is the owner's
-- alone rather than shared with another owner of the same world.
function V.build(w, slots, owner, private)
  assert(owner, 'visibility atlas requires an explicit resource owner')
  local parts =
    { tostring(Grid.span(w)), tostring(V.resolution), tostring(V.columns), tostring(V.capacity) }
  for _, row in ipairs(w.map) do
    parts[#parts + 1] = table.concat(row, ',')
  end
  for _, s in ipairs(slots) do
    parts[#parts + 1] = ('%.17g,%.17g'):format(s.x, s.z)
  end
  if private then
    parts[#parts + 1] = tostring(owner)
  end
  local key = table.concat(parts, ';')
  return owner:retain('visibility|' .. key, function()
    local n = V.resolution
    local data = love.image.newImageData(n * V.columns, n * V.columns)
    local whole = V.whole(w)
    local ao, blocked
    if whole then
      -- One frame for every tile; the first carries the map's shade even
      -- without a light (the ground the world shader reads).
      ao, blocked = shade(w, V.frame(w, 0, 0))
      if #slots == 0 then
        paint(w, data, 1, nil, ao, blocked)
      end
    end
    for i, s in ipairs(slots) do
      assert(i <= V.capacity, 'Static light atlas capacity exceeded')
      paint(w, data, i, s, ao, blocked)
    end
    local image = love.graphics.newImage(data)
    image:setFilter('linear', 'linear')
    local entry = { key = key, image = image, data = data, size = Grid.span(w), world = w }
    entry.shade = whole and { ao, blocked } or nil
    entry.origins = {}
    for i, s in ipairs(slots) do
      local fx, fz = V.frame(w, s.x, s.z)
      entry.origins[i] = { fx, fz }
    end
    if whole then
      entry.ground, entry.groundData = image, nil
    else
      entry.ground, entry.groundData = ground(w)
    end
    return entry
  end, function(entry)
    entry.image:release()
    entry.data:release()
    if entry.groundData then
      entry.ground:release()
      entry.groundData:release()
    end
  end, { kind = 'generated visibility', width = V.resolution * 4, height = V.resolution * 4 })
end
-- Bake source s into slot i of a built atlas (a light taking a free slot).
function V.place(entry, i, s)
  assert(i <= V.capacity, 'Static light atlas capacity exceeded')
  local w, n = entry.world, V.resolution
  local tile = love.image.newImageData(n, n)
  if V.whole(w) then
    entry.shade = entry.shade or { shade(w, V.frame(w, 0, 0)) }
    paint(w, tile, 1, s, entry.shade[1], entry.shade[2])
  else
    paint(w, tile, 1, s)
  end
  local ox, oz = corner(i)
  entry.data:paste(tile, ox, oz, 0, 0, n, n)
  entry.image:replacePixels(tile, 1, 1, ox, oz, false)
  tile:release()
  local fx, fz = V.frame(w, s.x, s.z)
  entry.origins[i] = { fx, fz }
end
function V.sample(entry, index, x, z)
  local n = V.resolution
  local origin = entry.origins[index] or { 0.5, 0.5 }
  local span = V.whole(entry.world) and entry.size or V.window
  local px = math.max(0, math.min(n - 1, math.floor((x - origin[1]) / span * n)))
  local pz = math.max(0, math.min(n - 1, math.floor((z - origin[2]) / span * n)))
  local ox, oz = corner(index)
  return entry.data:getPixel(ox + px, oz + pz)
end
return V
