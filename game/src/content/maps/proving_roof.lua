-- Continuous triangulated groin vaults. A bay's transverse and longitudinal
-- barrels meet on diagonal ribs; the same authored samples build the solid
-- slab and its visible underside. No stair faces between neighbouring cells.
return function(map)
  local cells = {}
  for _, room in ipairs(map.rooms) do
    for z = room[2], room[4] do
      cells[z] = cells[z] or {}
      for x = room[1], room[3] do
        cells[z][x] = true
      end
    end
  end
  local function curve(offset, half)
    return math.sqrt(math.max(0, 1 - (offset / half) ^ 2))
  end
  local function bay(x, z, cx, half, start, rise)
    local dz = math.abs((z - start) % 7 - 3.5)
    return 4.8 + rise * math.max(curve(x - cx, half), curve(dz, 3.5))
  end
  local function raw(x, z)
    if z >= 34.5 and x >= 17.5 and x <= 30.5 then
      return 3.2 + 0.6 * curve(x - 24, 6.5)
    end
    if z >= 25.5 and z <= 29.5 and ((x >= 17.5 and x <= 19.5) or (x >= 28.5 and x <= 30.5)) then
      return 3.1 + 1.4 * curve(z - 27.5, 2)
    end
    if z <= 5.5 and ((x >= 13.5 and x <= 18.5) or (x >= 29.5 and x <= 34.5)) then
      return 3
    end
    if z >= 11.5 and z <= 29.5 then
      if x >= 2.5 and x <= 17.5 then
        return bay(x, z, 10, 5, 13, 7.2)
      end
      if x >= 30.5 and x <= 45.5 then
        return bay(x, z, 38, 5, 13, 7.2)
      end
    end
    if z >= 9.5 and z <= 38.5 and x >= 19.5 and x <= 28.5 then
      return bay(x, z, 24, 4, 10, 7)
    end
    if z >= 5.5 and z <= 11.5 and ((x >= 5.5 and x <= 14.5) or (x >= 33.5 and x <= 42.5)) then
      return 8.6
    end
    if x >= 21.5 and x <= 26.5 and z <= 9.5 then
      return 5.4
    end
    return 4.2
  end
  local function height(x, z)
    local h = raw(x, z)
    -- At every outer edge the masonry joins the 4.2 m wall. Interior samples
    -- rise continuously instead of placing a low slab across the whole bay.
    for _, dx in ipairs({ -0.01, 0.01 }) do
      for _, dz in ipairs({ -0.01, 0.01 }) do
        local xx, zz = math.floor(x + dx + 0.5), math.floor(z + dz + 0.5)
        if not (cells[zz] and cells[zz][xx]) then
          return math.min(h, 4.2)
        end
      end
    end
    return h
  end
  map.decks = {}
  for z = 1, map.depth do
    for x = 1, map.width do
      if cells[z] and cells[z][x] then
        local h = {
          height(x - 0.5, z - 0.5),
          height(x + 0.5, z - 0.5),
          height(x + 0.5, z + 0.5),
          height(x - 0.5, z + 0.5),
          height(x, z),
        }
        -- A vertical upper register at the rear of each apse. This is actual
        -- masonry (not an image masking empty air), carrying the Judgment.
        if z == 6 and ((x >= 6 and x <= 14) or (x >= 34 and x <= 42)) then
          h = { 4.2, 4.2, 4.2, 4.2, 4.2 }
        end
        local low = math.min(unpack(h))
        map.decks[#map.decks + 1] = {
          x1 = x,
          x2 = x,
          z1 = z,
          z2 = z,
          top = 13.2,
          thickness = 13.2 - low,
          bottoms = h,
        }
      end
    end
  end
end
