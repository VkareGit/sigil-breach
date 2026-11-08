-- Painters of styled things (PLAN G3). Every module of render/painters is a
-- painter: it claims what it paints by its data (an art, a style, a flag) and
-- paints it, or answers false. The places that draw ask here, in the
-- painters' order, and fall back to their own plain drawing; a new style is a
-- new painter file, never an edit of those places. A painter declares:
--   hazards = { [hazard kind] = { ground = fn, air = fn } }
--   residues = { [view list] = fn(r, g, burst, age) }
--   cast = fn(r, g, e)         projectile = fn(r, g, b)
local Registry = require('src.core.registry')
local Painters = Registry:new('painters')
local DIR = 'src/render/painters'
local files = love.filesystem.getDirectoryItems(DIR)
table.sort(files)
for _, file in ipairs(files) do
  local name = file:match('^(.+)%.lua$')
  assert(name, DIR .. ' holds only painters: ' .. file)
  Painters:register(name, require('src.render.painters.' .. name))
end
-- Paint a hazard's phase ('ground' or 'air'); true when a painter claimed it.
function Painters.hazard(phase, r, g, h, ...)
  for _, id in ipairs(Painters:ids()) do
    local kinds = Painters:get(id).hazards
    local paint = kinds and kinds[h.kind] and kinds[h.kind][phase]
    if paint and paint(r, g, h, ...) then
      return true
    end
  end
  return false
end
-- Paint a body's cast; true when a painter claimed it.
function Painters.cast(r, g, e)
  for _, id in ipairs(Painters:ids()) do
    local paint = Painters:get(id).cast
    if paint and paint(r, g, e) then
      return true
    end
  end
  return false
end
-- Paint a projectile; true when a painter claimed it.
function Painters.projectile(r, g, b)
  for _, id in ipairs(Painters:ids()) do
    local paint = Painters:get(id).projectile
    if paint and paint(r, g, b) then
      return true
    end
  end
  return false
end
-- The painter of the residues kept in this view list, or nil.
function Painters.residue(list)
  for _, id in ipairs(Painters:ids()) do
    local residues = Painters:get(id).residues
    if residues and residues[list] then
      return residues[list]
    end
  end
end
return Painters
