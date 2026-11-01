-- Shared by showcase/build and focused acceptance: captures are regenerated
-- beside the reports, never copied forward from a previous executable.
local Review = {}
function Review.run(G, renderer, output)
  local lines = { 'Foundation UI and physical handoff: current renderer, current bitmap glyphs.' }
  local function append(receipts)
    for _, line in ipairs(receipts) do
      lines[#lines + 1] = line
    end
  end
  append(require('tests.cases.charge_presentation').run(G, renderer))
  -- The loading page at every shape of window.
  local UI = require('src.ui.interface')
  for _, size in ipairs({
    { 960, 540 },
    { 1024, 768 },
    { 1280, 720 },
    { 1720, 720 },
    { 1920, 1080 },
  }) do
    local capture = love.graphics.newCanvas(size[1], size[2])
    love.graphics.setCanvas(capture)
    require('src.ui.loading').draw(UI, 1, 1, size[1], size[2])
    love.graphics.setCanvas()
    local data = capture:newImageData()
    local png = data:encode('png')
    local out = assert(io.open(output .. '/loading-' .. size[1] .. 'x' .. size[2] .. '.png', 'wb'))
    out:write(png:getString())
    out:close()
    png:release()
    data:release()
    capture:release()
  end
  local file = assert(io.open(output .. '/foundation-ui-review.txt', 'w'))
  file:write(table.concat(lines, '\n') .. '\n')
  file:close()
  return #lines - 1
end
return Review
