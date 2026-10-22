-- Run with a real LÖVE graphics context. This checks source transparency,
-- atlas coverage and the renderer's frame overrides, not game balance.
local T = {}
function T.run(check, renderer)
  local C = require('src.render.fresco_enemies')
  local own = not renderer
  renderer = renderer or {}
  if own then
    C.loadAll(renderer)
  end
  local count = 0
  local function verify(name, ok)
    count = count + 1
    if check then
      check(name, ok)
    else
      assert(ok, name)
    end
  end
  for _, kind in ipairs(C.kinds) do
    local entry = C.entries[kind]
    local image = renderer.animations[kind]
    local frames = renderer.frames[kind]
    local feet = renderer.feet[kind]
    verify(
      'fresco ' .. kind .. ' retains the complete gameplay animation timeline',
      #frames == C.frameCount(kind) and #feet == #frames
    )
    local paths = { [entry.path] = true }
    for _, supplement in ipairs(entry.replacements or {}) do
      paths[supplement.path] = true
    end
    for path in pairs(paths) do
      local data = love.image.newImageData(path)
      local w, h = data:getDimensions()
      local zero, total = 0, 0
      local border = 0
      for y = 0, h - 1 do
        for x = 0, w - 1 do
          local _, _, _, a = data:getPixel(x, y)
          if x % 4 == 0 and y % 4 == 0 then
            total = total + 1
            if a < 0.01 then
              zero = zero + 1
            end
          end
          if (x == 0 or y == 0 or x == w - 1 or y == h - 1) and a > 0.3 then
            border = border + 1
          end
        end
      end
      verify(
        'fresco ' .. path .. ' has true transparent space rather than a parchment card',
        zero / total > 0.3
      )
      verify(
        'fresco ' .. path .. ' has no opaque silhouette cut by its outside canvas',
        border == 0
      )
      data:release()
    end
    local finite = true
    local within = true
    local attached = true
    for frame, region in ipairs(frames) do
      local r = region.rect
      local source = renderer.frameImages[kind][frame] or image
      finite = finite
        and region.width > 0
        and region.width < 2
        and region.height > 0
        and region.height < 2
        and feet[frame] >= 0
        and feet[frame] < 0.95
      within = within
        and r[1] >= 0
        and r[2] >= 0
        and r[3] > 0
        and r[4] > 0
        and r[1] + r[3] <= 1.000001
        and r[2] + r[4] <= 1.000001
      attached = attached and source ~= nil
    end
    verify('fresco ' .. kind .. ' all UV rectangles stay within their assigned images', within)
    verify('fresco ' .. kind .. ' floor registration and source-aspect scales are finite', finite)
    verify('fresco ' .. kind .. ' every repaired frame retains its image reference', attached)
    local sourcePaths, loaded = {}, {}
    for frame = 1, #frames do
      sourcePaths[frame] = entry.path
    end
    for _, supplement in ipairs(entry.replacements or {}) do
      for _, frame in ipairs(supplement.targets) do
        sourcePaths[frame] = supplement.path
      end
    end
    local rowProblems, columnProblems = {}, {}
    for frame, region in ipairs(frames) do
      local path = sourcePaths[frame]
      if not loaded[path] then
        loaded[path] = love.image.newImageData(path)
      end
      local data = loaded[path]
      local w, h = data:getDimensions()
      local rect = region.rect
      local x0, y0 = math.floor(rect[1] * w + 0.5), math.floor(rect[2] * h + 0.5)
      local x1, y1 =
        math.floor((rect[1] + rect[3]) * w + 0.0001) - 1,
        math.floor((rect[2] + rect[4]) * h + 0.0001) - 1
      local top, bottom, left, right = 0, 0, 0, 0
      for x = x0, x1 do
        local _, _, _, a = data:getPixel(x, y0)
        if a > 0.65 then
          top = top + 1
        end
        local _, _, _, b = data:getPixel(x, y1)
        if b > 0.65 then
          bottom = bottom + 1
        end
      end
      for y = y0, y1 do
        local _, _, _, a = data:getPixel(x0, y)
        if a > 0.65 then
          left = left + 1
        end
        local _, _, _, b = data:getPixel(x1, y)
        if b > 0.65 then
          right = right + 1
        end
      end
      if frame > entry.columns and top > 3 then
        rowProblems[#rowProblems + 1] = frame .. ' top ' .. top
      end
      if frame <= entry.columns * 3 and bottom > 3 then
        rowProblems[#rowProblems + 1] = frame .. ' bottom ' .. bottom
      end
      if (frame - 1) % entry.columns > 0 and left > 6 then
        columnProblems[#columnProblems + 1] = frame .. ' left ' .. left
      end
      if frame % entry.columns > 0 and right > 6 then
        columnProblems[#columnProblems + 1] = frame .. ' right ' .. right
      end
    end
    for _, data in pairs(loaded) do
      data:release()
    end
    verify(
      'fresco ' .. kind .. ' rows isolate silhouettes [' .. table.concat(rowProblems, ', ') .. ']',
      #rowProblems == 0
    )
    verify(
      'fresco '
        .. kind
        .. ' columns isolate silhouettes ['
        .. table.concat(columnProblems, ', ')
        .. ']',
      #columnProblems == 0
    )
    for _, supplement in ipairs(entry.replacements or {}) do
      for _, frame in ipairs(supplement.targets) do
        verify(
          'fresco ' .. kind .. ' repaired pose ' .. frame .. ' does not use the rejected base cell',
          renderer.frameImages[kind][frame] ~= nil
        )
      end
    end
  end
  verify(
    'armored imp retains 24 action poses plus four painted watchful poses',
    #renderer.frames.armored == 28
  )
  return count
end
return T
