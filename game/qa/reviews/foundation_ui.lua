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
  append(require('tests.cases.gallery_loading').run(G, renderer))
  append(require('tests.cases.charge_presentation').run(G, renderer))
  local file = assert(io.open(output .. '/foundation-ui-review.txt', 'w'))
  file:write(table.concat(lines, '\n') .. '\n')
  file:close()
  return #lines - 1
end
return Review
