-- Independent source-art landmarks: x, upper face, lower face, and an empty
-- point above the skull (ears/horns do not count as head). These are semantic
-- visual measurements, not points generated from the collision model.
local T = {}
local faces = {
  stolas = {
    { 29, 181, 60, 104, 28 },
    { 30, 544, 60, 105, 28 },
    { 31, 905, 78, 122, 46 },
    { 32, 1285, 82, 122, 50 },
    { 33, 184, 409, 445, 377 },
    { 34, 544, 418, 454, 386 },
    { 35, 905, 451, 487, 419 },
    { 36, 1267, 409, 450, 377 },
    { 37, 182, 776, 816, 744 },
    { 38, 545, 775, 815, 743 },
    { 39, 909, 783, 822, 751 },
    { 40, 1268, 774, 815, 742 },
    { 1, 130, 84, 108, 57 },
    { 2, 374, 93, 115, 66 },
    { 3, 631, 93, 115, 67 },
    { 4, 263, 122, 168, 78 },
    { 5, 751, 118, 161, 72 },
    { 6, 1408, 93, 114, 66 },
    { 7, 136, 355, 377, 328 },
    { 8, 378, 355, 377, 328 },
    { 9, 632, 359, 380, 331, 'effect' },
    { 10, 893, 355, 377, 328 },
    { 11, 1153, 357, 377, 329 },
    { 12, 1408, 354, 376, 327 },
    { 13, 120, 579, 595, 552 },
    { 19, 124, 797, 809, 774 },
    { 20, 370, 805, 816, 781 },
    { 21, 631, 805, 817, 782 },
    { 22, 256, 598, 619, 561 },
    { 23, 747, 582, 604, 545 },
    { 24, 1406, 800, 812, 777 },
  },
  buer = {
    { 1, 207, 104, 147, 69 },
    { 2, 535, 109, 145, 75 },
    { 3, 856, 114, 150, 81 },
    { 4, 1163, 111, 147, 76 },
    { 5, 176, 393, 427, 362 },
    { 6, 478, 389, 418, 357 },
    { 7, 833, 420, 449, 388 },
    { 8, 1157, 447, 473, 415 },
    { 9, 128, 685, 705, 657 },
    { 13, 181, 975, 1006, 944 },
    { 14, 482, 980, 1010, 948 },
    { 15, 800, 980, 1011, 948 },
    { 16, 1137, 974, 1004, 942 },
    { 17, 428, 157, 218, 102 },
    { 18, 1003, 147, 208, 93 },
    { 19, 480, 746, 801, 692 },
    { 20, 1033, 765, 823, 711 },
  },
}
local shoulders = {
  [1] = { { 135, 145 }, { 157, 166 } },
  [2] = { { 465, 142 }, { 487, 168 } },
  [3] = { { 767, 145 }, { 793, 169 } },
  [4] = { { 1070, 150 }, { 1108, 172 } },
  [5] = { { 125, 440 }, { 140, 453 } },
  [7] = { { 751, 443 }, { 780, 471 } },
  [8] = { { 1085, 441 }, { 1100, 482 } },
  [17] = { { 326, 224 }, { 355, 258 } },
  [18] = { { 882, 216 }, { 921, 250 } },
  [19] = { { 350, 814 }, { 396, 837 } },
  [20] = { { 914, 825 }, { 947, 857 } },
}
function T.run(check, renderer)
  local Geometry = require('src.enemies.geometry')
  local B = require('src.combat.ballistics')
  local Catalog = require('src.render.fresco_enemies')
  renderer = renderer or {}
  if not renderer.animations then
    Catalog.onDemand(renderer)
  end
  local count = 0
  local function verify(name, ok)
    count = count + 1
    if check then
      check(name, not not ok)
    else
      assert(ok, name)
    end
  end
  for kind, points in pairs(faces) do
    Geometry.register(kind, renderer.frames[kind], renderer.feet[kind])
    local loaded = {}
    for _, point in ipairs(points) do
      local frame, x, upper, lower, air = unpack(point)
      local entry = Catalog.entries[kind]
      local path = entry.path
      for _, replacement in ipairs(entry.replacements or {}) do
        for _, target in pairs(replacement.targets) do
          if target == frame then
            path = replacement.path
          end
        end
      end
      if not loaded[path] then
        loaded[path] = love.image.newImageData(path)
      end
      local data = loaded[path]
      local iw, ih = data:getDimensions()
      local r = renderer.frames[kind][frame].rect
      local g = { mode = 'field', player = { x = 0, z = 8 }, time = 0, testField = {} }
      local e = { kind = kind, id = 7, hp = 100, x = 0, z = 0, previewFrame = frame }
      local _, _, _, _, _, _, width, height, base = Geometry.pose(g, e)
      local function worldPoint(y, px)
        return (((px or x) - r[1] * iw) / (r[3] * iw) - 0.5) * width,
          base + (1 - (y - r[2] * ih) / (r[4] * ih)) * height
      end
      local function ray(y, distance, px)
        g.player.z = distance
        local tx, ty = worldPoint(y, px)
        local oy = 1.38
        local length = math.sqrt(tx * tx + (ty - oy) ^ 2 + distance * distance)
        return B.body(
          g,
          e,
          0,
          oy,
          distance,
          tx / length,
          (ty - oy) / length,
          -distance / length,
          40
        )
      end
      local upperAlpha = select(4, data:getPixel(x, upper))
      local lowerAlpha = select(4, data:getPixel(x, lower))
      verify(
        kind .. ' pose ' .. frame .. ' independent face landmarks lie on real source pigment',
        upperAlpha > 0.65 and lowerAlpha > 0.65
      )
      local tags, named = true, true
      for _, distance in ipairs({ 3, 8, 16 }) do
        for _, y in ipairs({ upper, (upper + lower) * 0.5, lower }) do
          local hit, part, surface = ray(y, distance)
          tags = tags and hit ~= nil and part == 'head'
          named = named and surface ~= nil and surface.shapeId == 'head'
        end
      end
      verify(
        kind .. ' pose ' .. frame .. ' forehead nose and jaw are head contacts at 3/8/16 m',
        tags
      )
      local clear = true
      local aboveAlpha = select(4, data:getPixel(x, air))
      for _, distance in ipairs({ 3, 8, 16 }) do
        local hit, part, surface = ray(air, distance)
        if aboveAlpha <= 0.05 or point[6] == 'effect' then
          clear = clear and hit == nil
        else
          -- A painted mane is flesh; horns also block shots. Neither is skull.
          clear = clear and hit ~= nil and part ~= 'head' and surface ~= nil
        end
      end
      verify(
        kind .. ' pose ' .. frame .. ' clear air misses and painted ornaments are not headshots',
        clear
      )
      verify(kind .. ' pose ' .. frame .. ' independent face contacts name the head surface', named)
      if kind == 'buer' and shoulders[frame] then
        local pigment, body = true, true
        for _, p in ipairs(shoulders[frame]) do
          pigment = pigment and select(4, data:getPixel(p[1], p[2])) > 0.65
          for _, distance in ipairs({ 3, 8, 16 }) do
            local hit, part = ray(p[2], distance, p[1])
            body = body and hit ~= nil and part == 'torso'
          end
        end
        verify(
          'buer pose ' .. frame .. ' shoulder and rib landmarks are actual flesh pixels',
          pigment
        )
        verify(
          'buer pose '
            .. frame
            .. ' raised shoulder and upper ribs remain body contacts at 3/8/16 m',
          body
        )
      end
    end
    for _, data in pairs(loaded) do
      data:release()
    end
  end
  local g = { mode = 'field', player = { x = 0, z = 8 }, time = 0, testField = {} }
  local e = { kind = 'buer', id = 7, hp = 100, x = 0, z = 0, previewFrame = 1 }
  local Surface = require('src.enemies.surface')
  local reused = Surface.prepare(g, e)
  local firstParts = reused.parts
  e.previewFrame = 6
  Surface.prepare(g, e, reused)
  verify(
    'changing Buer pose replaces all cached surfaces instead of leaving a ghost shoulder',
    reused.frame == 6
      and reused.parts ~= firstParts
      and reused.parts == require('src.content.art.anatomy_regions').layouts.buer.frames[6].parts
  )
  return count
end
return T
