-- Linux companion to the PowerShell/GDI annotation tools. Source pixels and
-- rectangles come from the same CSV; this only writes diagnostic contact sheets.
local function read(path)
  local file = assert(io.open(path, 'rb'))
  local text = file:read('*a')
  file:close()
  return text
end
local function rows(path)
  local result, header = {}, nil
  for line in read(path):gmatch('[^\r\n]+') do
    if line:sub(1, 1) ~= '#' then
      local values = {}
      -- Export-Csv quotes every field and escapes a quote by doubling it.
      for value in line:gmatch('"([^"]*)"') do
        values[#values + 1] = value
      end
      if not header then
        header = values
      else
        local row = {}
        for i, key in ipairs(header) do
          row[key] = tonumber(values[i]) or values[i]
        end
        result[#result + 1] = row
      end
    end
  end
  return result
end
local function source(root, row)
  local image =
    love.graphics.newImage(love.filesystem.newFileData(read(root .. '/' .. row.image), row.image))
  image:setFilter('nearest', 'nearest')
  local quad = love.graphics.newQuad(row.x, row.y, row.w, row.h, image:getDimensions())
  return image, quad
end
local function save(canvas, path)
  love.graphics.setCanvas()
  local data = canvas:newImageData()
  local file = assert(io.open(path, 'wb'))
  file:write(data:encode('png'):getString())
  file:close()
  data:release()
  canvas:release()
  print(path)
end
function love.load(args)
  local ok, err = xpcall(function()
    local root, csv, output, mode = args[1], args[2], args[3], args[4]
    local frames = rows(csv)
    assert(#frames > 0, 'No selected frame rectangles')
    local lg = love.graphics
    if mode == 'contact' then
      local groups = {}
      for _, row in ipairs(frames) do
        groups[row.kind] = groups[row.kind] or {}
        table.insert(groups[row.kind], row)
      end
      for kind, group in pairs(groups) do
        local canvas = lg.newCanvas(1280, math.ceil(#group / 4) * 344)
        lg.setCanvas(canvas)
        lg.clear(44 / 255, 48 / 255, 45 / 255, 1)
        for i, row in ipairs(group) do
          local image, quad = source(root, row)
          local x, y = (i - 1) % 4 * 320, math.floor((i - 1) / 4) * 344
          lg.setColor(1, 1, 1)
          lg.draw(image, quad, x, y + 24, 0, 320 / row.w, 320 / row.h)
          lg.print(kind .. ' ' .. row.frame, x + 4, y + 2)
          lg.setColor(1, 1, 1, 85 / 255)
          for n = 1, 9 do
            lg.line(x + n * 32, y + 24, x + n * 32, y + 344)
            lg.line(x, y + 24 + n * 32, x + 320, y + 24 + n * 32)
          end
          quad:release()
          image:release()
        end
        save(canvas, output .. '/' .. kind .. '.png')
      end
    else
      local scale, points = tonumber(args[5]), args[6] or ''
      for _, row in ipairs(frames) do
        local canvas = lg.newCanvas(row.w * scale + 60, row.h * scale + 30)
        lg.setCanvas(canvas)
        lg.clear(40 / 255, 70 / 255, 40 / 255, 1)
        local image, quad = source(root, row)
        lg.setColor(1, 1, 1)
        lg.draw(image, quad, 50, 20, 0, scale, scale)
        for x = math.ceil(row.x / 16) * 16, row.x + row.w - 1, 16 do
          local px = 50 + (x - row.x) * scale
          lg.setColor(0, 1, 1, x % 64 == 0 and 0.8 or 0.4)
          lg.line(px, 20, px, 20 + row.h * scale)
          if x % 32 == 0 then
            lg.setColor(1, 1, 0)
            lg.print(x, px - 10, 3)
          end
        end
        for y = math.ceil(row.y / 16) * 16, row.y + row.h - 1, 16 do
          local py = 20 + (y - row.y) * scale
          lg.setColor(0, 1, 1, y % 64 == 0 and 0.8 or 0.4)
          lg.line(50, py, 50 + row.w * scale, py)
          if y % 32 == 0 then
            lg.setColor(1, 1, 0)
            lg.print(y, 2, py - 7)
          end
        end
        local n = 0
        for x, y in points:gmatch('(%d+),(%d+)') do
          n = n + 1
          local px, py = 50 + (tonumber(x) - row.x) * scale, 20 + (tonumber(y) - row.y) * scale
          lg.setColor(1, 0, 1)
          lg.line(px - 6, py, px + 6, py)
          lg.line(px, py - 6, px, py + 6)
          lg.print(n, px + 4, py - 16)
        end
        save(canvas, output .. '/' .. row.kind .. '-' .. row.frame .. '.png')
        quad:release()
        image:release()
      end
    end
  end, debug.traceback)
  if not ok then
    print(err)
  end
  love.event.quit(ok and 0 or 1)
end
