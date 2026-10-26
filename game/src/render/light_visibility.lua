-- A cached 2.5D shadow atlas for the arena's solid walls and pillars.

local Grid = require('src.physics.grid')
-- A cached 2.5D shadow atlas for the arena's solid walls and pillars.
-- Each light has its own tile. Decorative arches are not geometry in this map.
local V = { resolution = 128, columns = 4, capacity = 14 }
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
function V.build(w, sources, owner)
  assert(owner, 'visibility atlas requires an explicit resource owner')
  local parts =
    { tostring(Grid.span(w)), tostring(V.resolution), tostring(V.columns), tostring(V.capacity) }
  for _, row in ipairs(w.map) do
    parts[#parts + 1] = table.concat(row, ',')
  end
  for _, s in ipairs(sources) do
    parts[#parts + 1] = ('%.17g,%.17g'):format(s.x, s.z)
  end
  local key = table.concat(parts, ';')
  return owner:retain('visibility|' .. key, function()
    local n = V.resolution
    local data = love.image.newImageData(n * 4, n * 4)
    local ao, blocked = {}, {}
    for z = 0, n - 1 do
      for x = 0, n - 1 do
        local span = Grid.span(w)
        local wx, wz = 0.5 + (x + 0.5) * span / n, 0.5 + (z + 0.5) * span / n
        ao[z * n + x + 1] = V.ambient(w, wx, wz)
        blocked[z * n + x + 1] = solid(w, math.floor(wx + 0.5), math.floor(wz + 0.5)) and 1 or 0
      end
    end
    for i, s in ipairs(sources) do
      assert(i <= V.capacity, 'Static light atlas capacity exceeded')
      local ox, oz = ((i - 1) % 4) * n, math.floor((i - 1) / 4) * n
      for z = 0, n - 1 do
        for x = 0, n - 1 do
          local visible = V.visible(
            w,
            s.x,
            s.z,
            0.5 + (x + 0.5) * Grid.span(w) / n,
            0.5 + (z + 0.5) * Grid.span(w) / n
          )
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
    local image = love.graphics.newImage(data)
    image:setFilter('linear', 'linear')
    return { key = key, image = image, data = data, size = Grid.span(w) }
  end, function(entry)
    entry.image:release()
    entry.data:release()
  end, { kind = 'generated visibility', width = V.resolution * 4, height = V.resolution * 4 })
end
function V.sample(entry, index, x, z)
  local n = V.resolution
  local px = math.max(0, math.min(n - 1, math.floor((x - 0.5) / entry.size * n)))
  local pz = math.max(0, math.min(n - 1, math.floor((z - 0.5) / entry.size * n)))
  return entry.data:getPixel(((index - 1) % 4) * n + px, math.floor((index - 1) / 4) * n + pz)
end
return V
