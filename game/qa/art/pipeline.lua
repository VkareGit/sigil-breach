-- The creature pipeline modes (plan v10 V7; qa/runtime.lua): each writes its
-- result into the QA output, and the scripts install it.
--   --sheet-export=<atlas>    the sheet re-measured   sheet-<atlas>.lua
--   --sheet-spec=<file>       a new atlas's sheet      sheet-<id>.lua
--   --anatomy-export=<id>     an annotation as data    anatomy-<id>.lua
--   --anatomy-layers=<file>   annotation from layers   anatomy-<id>.lua
--   --check-creature=<id>     every element checked   creature-<id>.txt
-- Returns how many things failed (the process exit code is not 0 then).
local Pipeline = {}
local function write(path, text)
  local file = assert(io.open(path, 'wb'))
  file:write(text)
  file:close()
  print('wrote ' .. path)
end
local function load(path)
  local file = assert(io.open(path, 'rb'), 'cannot read ' .. path)
  local text = file:read('*a')
  file:close()
  return assert(loadstring(text, path))()
end
function Pipeline.run(values, output)
  local failed = 0
  local Tool = require('qa.art.sheet_tool')
  local Export = require('qa.art.anatomy_export')
  local Atlases = require('src.content.art.atlases')
  local Anatomy = require('src.content.art.anatomy_regions')
  if values['--sheet-export'] then
    local id = values['--sheet-export']
    local sheet = assert(Atlases.sheets[id], 'unknown atlas ' .. id)
    local measured = Tool.measure(sheet)
    for index, frame in ipairs(measured.frames) do
      if frame.feet ~= sheet.frames[index].feet then
        print(
          id .. ' frame ' .. index .. ' feet ' .. sheet.frames[index].feet .. ' -> ' .. frame.feet
        )
      end
    end
    write(output .. '/sheet-' .. id .. '.lua', Tool.text(measured))
  end
  if values['--sheet-spec'] then
    local sheet = Tool.propose(load(values['--sheet-spec']))
    write(output .. '/sheet-' .. sheet.id .. '.lua', Tool.text(sheet))
  end
  if values['--anatomy-export'] then
    local id = values['--anatomy-export']
    local annotation = assert(Anatomy.layouts[id], 'unknown annotation ' .. id)
    local text = Export.text(id, annotation)
    if not Export.same(Export.read(text), annotation) then
      print('export of ' .. id .. ' does not read back to the same annotation')
      failed = failed + 1
    end
    write(output .. '/anatomy-' .. id .. '.lua', text)
  end
  if values['--anatomy-layers'] then
    local legend = load(values['--anatomy-layers'])
    local sheet = assert(Atlases.sheets[legend.atlas], 'unknown atlas ' .. tostring(legend.atlas))
    local annotation = require('qa.art.anatomy_layers').annotation(sheet, legend)
    for index, frame in ipairs(annotation.frames) do
      for _, problem in ipairs(Anatomy.problems(frame, legend.id .. '/' .. index)) do
        print(problem)
        failed = failed + 1
      end
    end
    write(output .. '/anatomy-' .. legend.id .. '.lua', Export.text(legend.id, annotation))
  end
  if values['--check-creature'] then
    local id = values['--check-creature']
    local lines, missing = require('qa.art.creature_check').run(id)
    lines[#lines + 1] = missing == 0 and ('creature ' .. id .. ': complete')
      or ('creature ' .. id .. ': ' .. missing .. ' missing')
    print(table.concat(lines, '\n'))
    write(output .. '/creature-' .. id .. '.txt', table.concat(lines, '\n') .. '\n')
    failed = failed + missing
  end
  return failed
end
return Pipeline
