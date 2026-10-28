-- Wall paintings and subdued fire for the approved chapel direction.
-- Every panel lies against an existing wall; no fake opening or collision.
-- size = height in metres, width = width. Coordinates are world-facing planes.
return function(map)
  local murals = map.decor.murals
  local function paint(art, x, z, yaw, width, height, y, brightness)
    murals[#murals + 1] = {
      art = art,
      x = x,
      z = z,
      yaw = yaw,
      width = width,
      size = height,
      y = y or 0.18,
      brightness = brightness or 1,
      wallMounted = art ~= 'chapel_judgment_crown',
    }
  end
  for _, cx in ipairs({ 10, 38 }) do
    -- Pale surviving plaster on the axis gives the brown demon a quiet foil.
    paint('chapel_witnesses', cx, 5.62, 0, 7.0, 3.68, 0.10, 1.26)
    -- The upper register lies on the vertical face of the perimeter slab,
    -- not a floating card across the open apse (slab begins at y = 4.2).
    paint('chapel_judgment_crown', cx, 6.62, 0, 8.76, 4.12, 3.90, 1.12)
    for _, side in ipairs({ -1, 1 }) do
      local yaw = -side * math.pi / 2
      for _, z in ipairs({ 15.3 }) do
        paint('chapel_mourners', cx + side * 7.38, z, yaw, 6.4, 3.68, 0.18, 0.64)
      end
      -- A red-ivory dado continues underneath the two bays, joining the cycle.
      for _, z in ipairs({ 15.3, 22.3, 27.65 }) do
        -- The inner side of each hall opens into the nave at z=25.5.
        -- A dado belongs to masonry; it cannot bridge that opening.
        local entrance = (cx == 10 and side == 1) or (cx == 38 and side == -1)
        if not (entrance and z > 26) then
          paint('chapel_frieze', cx + side * 7.36, z, yaw, z > 26 and 3.65 or 6.4, 0.24, 0.12, 0.80)
        end
      end
      -- The lateral shoulders of the stepped apse continue its materials.
      paint('chapel_mourners', cx + side * 4.38, 9.75, yaw, 3.0, 3.6, 0.18, 0.80)
    end
    for _, offset in ipairs({ -4.65, 4.65 }) do
      paint('chapel_mourners', cx + offset, 29.38, math.pi, 4.4, 3.68, 0.18, 0.62)
    end
  end
  map.decor.inscriptions = {
    { id = 'binding', x = 7.1, z = 5.66, y = 2.6, yaw = 0, width = 2.4 },
    { id = 'binding', x = 35.1, z = 5.66, y = 2.6, yaw = 0, width = 2.4 },
    { id = 'threshold', x = 24, z = 39.34, y = 2.15, yaw = math.pi, width = 3.6 },
  }
  local function relic(art, x, z, height, y, yaw)
    map.decor.props[#map.decor.props + 1] = {
      art = art,
      x = x,
      z = z,
      y = y or 0,
      size = height,
      yaw = yaw,
      wallMounted = yaw ~= nil,
      brightness = 0.90,
    }
  end
  -- Funerary objects belong to the side bays, not the attack lanes. The
  -- tiny floor fragments are below the existing step height; larger relics
  -- stand against masonry which already supplies their collision.
  for _, cx in ipairs({ 10, 38 }) do
    for _, side in ipairs({ -1, 1 }) do
      relic('ossuary_niche', cx + side * 4.65, 29.32, 1.65, 0.30, math.pi)
      relic('funerary_shelf', cx + side * 7.30, 23.4, 0.66, 1.0, -side * math.pi / 2)
      relic('fallen_masonry', cx + side * 4.1, 11.0, 0.15)
      relic('cold_brazier', cx + side * 6, 14.8, 0.78)
    end
    local inward = cx == 10 and 1 or -1
    relic('cold_brazier', cx - inward * 6, 25, 0.78)
    relic('broken_binding', cx + inward * 8.5, 25.62, 1.0, 0, 0)
    relic('spent_censer', cx + inward * 9.0, 25.85, 0.22)
    relic('broken_capital', cx + inward * 7.8, 25.8, 0.18)
  end
  relic('ossuary_niche', 13.64, 3.5, 1.75, 0.15, math.pi / 2)
  relic('ossuary_niche', 34.36, 3.5, 1.75, 0.15, -math.pi / 2)
  -- Stand in front of the painted plaster as well as in front of masonry.
  relic('funerary_shelf', 17.72, 35.5, 0.65, 1.0, math.pi / 2)
  relic('funerary_shelf', 30.28, 35.5, 0.65, 1.0, -math.pi / 2)
  for _, spot in ipairs({ { 28, 32 }, { 20, 22 }, { 28, 22 }, { 20, 12 }, { 22, 4 } }) do
    relic('cold_brazier', spot[1], spot[2], 0.78)
  end
  map.decor.floorArt = {
    {
      art = 'binding_scorch',
      x = 18.5,
      z = 27.5,
      width = 2.4,
      depth = 2.8,
      yaw = math.pi / 2,
      brightness = 0.9,
    },
    {
      art = 'binding_scorch',
      x = 29.5,
      z = 27.5,
      width = 2.4,
      depth = 2.8,
      yaw = -math.pi / 2,
      brightness = 0.9,
    },
    { art = 'binding_scorch', x = 10, z = 11, width = 2.4, depth = 2.4, yaw = 0, brightness = 0.7 },
    { art = 'binding_scorch', x = 38, z = 11, width = 2.4, depth = 2.4, yaw = 0, brightness = 0.7 },
  }
  for _, hall in ipairs({ { 10, 5, 13, 27, 7.2 }, { 38, 5, 13, 27, 7.2 }, { 24, 4, 10, 31, 7 } }) do
    for z = hall[3] + 3.5, hall[4] - 3.5, 7 do
      for _, side in ipairs({ -1, 1 }) do
        map.decor.arches[#map.decor.arches + 1] = {
          x = hall[1],
          z = z,
          yaw = side * math.atan2(3.5, hall[2]),
          halfSpan = math.sqrt(hall[2] ^ 2 + 3.5 ^ 2),
          spring = 4.6,
          rise = hall[5],
          radius = 0.10,
        }
      end
    end
  end
  -- Repeated bays guide the eye along the nave without hanging a panel in a
  -- doorway. The narthex is wider, so its walls have separate coordinates.
  for _, side in ipairs({ -1, 1 }) do
    local yaw = -side * math.pi / 2
    for _, z in ipairs({ 13.5, 20.5 }) do
      paint('chapel_procession', 24 + side * 4.38, z, yaw, 6.4, 3.68, 0.18, 0.66)
    end
    paint('chapel_mourners', 24 + side * 6.38, 35.5, yaw, 6.4, 3.68, 0.18, 0.72)
  end
  paint('chapel_judgment', 24, 1.62, 0, 4.8, 3.68, 0.1, 1.10)
  for _, offset in ipairs({ -4.1, 0, 4.1 }) do
    paint(
      offset == 0 and 'chapel_plaster' or 'chapel_mourners',
      24 + offset,
      39.38,
      math.pi,
      3.95,
      3.68,
      0.18,
      0.75
    )
  end
  for _, lamp in ipairs(map.lamps) do
    local altar = lamp[2] < 11
    lamp.scale = altar and 1.12 or 0.88
    lamp.lightHeight = map.lampHeight * lamp.scale / 1.7
    lamp.brightness = altar and 0.80 or 0.62
    lamp.color = altar and { 1.45, 1.04, 0.70 } or { 0.84, 0.61, 0.39 }
  end
end
