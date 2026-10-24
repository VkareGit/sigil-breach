-- Keep each sprite's opaque feet on the floor despite varying transparent margins.
local Atlas = {}
function Atlas.load(path, columns, rows, bands, columnBands, resources)
  local data = love.image.newImageData(path)
  local w, h = data:getDimensions()
  local feet, frames = {}, {}
  for frame = 1, columns * rows do
    local col, row = (frame - 1) % columns, math.floor((frame - 1) / columns)
    local x0, x1 = math.ceil(col * w / columns), math.floor((col + 1) * w / columns) - 1
    local xcuts = columnBands and columnBands[row + 1]
    if xcuts then
      x0, x1 = xcuts[col + 1], xcuts[col + 2] - 1
    end
    -- Authored rows have uneven gutters. Preserve source pixel scale, not cell height.
    local cuts = bands and (type(bands[1]) == 'table' and bands[col + 1] or bands)
    local y0, y1 =
      math.ceil(cuts and cuts[row + 1] or row * h / rows),
      math.floor(cuts and cuts[row + 2] or (row + 1) * h / rows) - 1
    local cellHeight = y1 - y0 + 1
    local bottom = y1
    for y = y1, y0, -1 do
      local count = 0
      for x = x0, x1 do
        local _, _, _, a = data:getPixel(x, y)
        if a > 0.65 then
          count = count + 1
        end
      end
      if count >= 3 then
        bottom = y
        break
      end
    end
    feet[frame] = (y1 - bottom) / cellHeight
    frames[frame] = {
      rect = { x0 / w, y0 / h, (x1 - x0 + 1) / w, cellHeight / h },
      height = cellHeight / (h / rows),
      width = (x1 - x0 + 1) / (w / columns),
    }
  end
  local image = resources and resources:image(path, nil, data) or love.graphics.newImage(data)
  image:setFilter('nearest', 'nearest')
  data:release()
  return image, feet, frames
end
return Atlas
