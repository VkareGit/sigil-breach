-- The painted creature atlases (plan v10 V7): every sheet listed in
-- content/art/sheets/index.lua, and any registered later (a mod, a test),
-- with what is derived from it (content/art/sheet.lua). The modules the game
-- reads are views of these tables: enemy_frames (layouts), enemy_art
-- (entries, kinds), enemy_idle (idle) and art/sources (sizes).
local Sheet = require('src.content.art.sheet')
local Atlases = { kinds = {}, sheets = {}, layouts = {}, entries = {}, idle = {}, sizes = {} }
function Atlases.register(sheet)
  local problems = Sheet.problems(sheet)
  assert(#problems == 0, table.concat(problems, '\n'))
  assert(not Atlases.sheets[sheet.id], 'atlas already registered: ' .. sheet.id)
  for _, source in ipairs(sheet.sources) do
    Atlases.sizes[source.path] = source.size
  end
  Atlases.sheets[sheet.id] = sheet
  Atlases.layouts[sheet.id] = Sheet.layout(sheet)
  Atlases.entries[sheet.id] = Sheet.entry(sheet)
  Atlases.idle[sheet.id] = Sheet.idle(sheet)
  Atlases.kinds[#Atlases.kinds + 1] = sheet.id
  return sheet
end
function Atlases.unregister(id)
  local sheet = Atlases.sheets[id]
  if not sheet then
    return nil
  end
  for _, source in ipairs(sheet.sources) do
    Atlases.sizes[source.path] = nil
  end
  Atlases.sheets[id], Atlases.layouts[id], Atlases.entries[id], Atlases.idle[id] =
    nil, nil, nil, nil
  for index, kind in ipairs(Atlases.kinds) do
    if kind == id then
      table.remove(Atlases.kinds, index)
      break
    end
  end
  return sheet
end
for _, module in ipairs(require('src.content.art.sheets.index')) do
  Atlases.register(require(module))
end
return Atlases
