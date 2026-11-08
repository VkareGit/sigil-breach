-- The creature packages (PLAN F4): one directory per creature under
-- content/creatures, holding its definition (init.lua) and its parts
-- (sheet, anatomy, audio, voices, words). What gathers a kind of part from
-- every package asks here, so a new creature is a new directory.
local ROOT = 'src/content/creatures'
local P = {}
-- The ids of every package, sorted.
function P.ids()
  local ids = {}
  for _, name in ipairs(love.filesystem.getDirectoryItems(ROOT)) do
    if love.filesystem.getInfo(ROOT .. '/' .. name, 'directory') then
      ids[#ids + 1] = name
    end
  end
  table.sort(ids)
  return ids
end
-- Every package's part of this name: { id, module }, by package id.
function P.parts(name)
  local parts = {}
  for _, id in ipairs(P.ids()) do
    if love.filesystem.getInfo(ROOT .. '/' .. id .. '/' .. name .. '.lua', 'file') then
      parts[#parts + 1] = { id = id, module = 'src.content.creatures.' .. id .. '.' .. name }
    end
  end
  return parts
end
return P
