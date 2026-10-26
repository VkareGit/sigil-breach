-- A spatial hash of bodies on the ground plane (plan v10 V3): square cells of
-- a fixed size; a query returns every member whose cell overlaps a circle's
-- bounding square. Membership follows a body only when told (move); the
-- caller keeps it current. Cell lists are reused between builds: a rebuild
-- of the same hash allocates nothing once its cells exist.
--   local h = Spatial.new(size)
--   h:clear(); h:insert(e, x, z); h:move(e, x, z); h:query(x, z, r, out)
local Spatial = {}
Spatial.__index = Spatial
function Spatial.new(size)
  assert(type(size) == 'number' and size > 0, 'spatial hash needs a positive cell size')
  return setmetatable({ size = size, columns = {}, where = {}, used = {} }, Spatial)
end
-- The list of the cell holding (x, z), made on first use.
local function cellAt(h, x, z)
  local cx, cz = math.floor(x / h.size), math.floor(z / h.size)
  local column = h.columns[cx]
  if not column then
    column = {}
    h.columns[cx] = column
  end
  local list = column[cz]
  if not list then
    list = {}
    column[cz] = list
  end
  return list
end
-- Forget every member (cells stay allocated for the next build).
function Spatial:clear()
  for list in pairs(self.used) do
    for i = #list, 1, -1 do
      list[i] = nil
    end
    self.used[list] = nil
  end
  for e in pairs(self.where) do
    self.where[e] = nil
  end
end
function Spatial:insert(e, x, z)
  local list = cellAt(self, x, z)
  list[#list + 1] = e
  self.used[list] = true
  self.where[e] = list
end
function Spatial:remove(e)
  local list = self.where[e]
  if not list then
    return
  end
  for i = #list, 1, -1 do
    if list[i] == e then
      table.remove(list, i)
      break
    end
  end
  self.where[e] = nil
end
-- Follow a body to its new position.
function Spatial:move(e, x, z)
  local list = cellAt(self, x, z)
  if self.where[e] == list then
    return
  end
  self:remove(e)
  list[#list + 1] = e
  self.used[list] = true
  self.where[e] = list
end
-- Every member in the cells overlapping the square of half side r around
-- (x, z), appended to out (unordered; the caller filters and orders).
function Spatial:query(x, z, r, out)
  out = out or {}
  local s = self.size
  for cx = math.floor((x - r) / s), math.floor((x + r) / s) do
    local column = self.columns[cx]
    if column then
      for cz = math.floor((z - r) / s), math.floor((z + r) / s) do
        local list = column[cz]
        if list then
          for i = 1, #list do
            out[#out + 1] = list[i]
          end
        end
      end
    end
  end
  return out
end
return Spatial
