-- The painted creature atlases (plan v10 V7): every sheet listed in
-- content/art/sheets/index.lua, and any registered later (a mod, a test),
-- with what is derived from it (content/art/sheet.lua). The modules the game
-- reads are views of these tables: enemy_frames (layouts), enemy_art
-- (entries, kinds), enemy_idle (idle), art/sources (sizes) and the named poses
-- the animation asks for (poses, plan v11 E1).
local Sheet = require('src.content.art.sheet')
local Atlases =
  { kinds = {}, sheets = {}, layouts = {}, entries = {}, idle = {}, sizes = {}, poses = {} }
function Atlases.register(sheet)
  local problems = Sheet.problems(sheet)
  assert(#problems == 0, table.concat(problems, '\n'))
  assert(not Atlases.sheets[sheet.id], 'atlas already registered: ' .. sheet.id)
  -- An image two atlases paint from has one size (the first registration's).
  for _, source in ipairs(sheet.sources) do
    local known = Atlases.sizes[source.path]
    assert(
      not known or (known[1] == source.size[1] and known[2] == source.size[2]),
      'image registered with another size: ' .. source.path
    )
    Atlases.sizes[source.path] = known or source.size
  end
  Atlases.sheets[sheet.id] = sheet
  Atlases.layouts[sheet.id] = Sheet.layout(sheet)
  Atlases.entries[sheet.id] = Sheet.entry(sheet)
  Atlases.idle[sheet.id] = Sheet.idle(sheet)
  Atlases.poses[sheet.id] = Sheet.poses(sheet)
  Atlases.kinds[#Atlases.kinds + 1] = sheet.id
  return sheet
end
function Atlases.unregister(id)
  local sheet = Atlases.sheets[id]
  if not sheet then
    return nil
  end
  Atlases.sheets[id], Atlases.layouts[id], Atlases.entries[id], Atlases.idle[id] =
    nil, nil, nil, nil
  -- An image another atlas still paints from keeps its size.
  for _, source in ipairs(sheet.sources) do
    local shared = false
    for _, other in pairs(Atlases.sheets) do
      for _, s in ipairs(other.sources) do
        shared = shared or s.path == source.path
      end
    end
    if not shared then
      Atlases.sizes[source.path] = nil
    end
  end
  Atlases.poses[id] = nil
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
