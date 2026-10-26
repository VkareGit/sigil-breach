-- The cell grid of a world (plan v10 V3): width cells along x, depth cells
-- along z, cells 1..width x 1..depth, a cell's centre at its integer
-- coordinates. A map states width and depth, or size for a square one; a
-- hand-made world that names only size is square.
local Grid = {}
function Grid.width(w)
  return w.width or w.size
end
function Grid.depth(w)
  return w.depth or w.size
end
-- The longer side (scales of square overviews and atlases).
function Grid.span(w)
  return math.max(Grid.width(w), Grid.depth(w))
end
-- One integer per cell (flow fields, visited sets): z rows of width cells.
function Grid.key(w, x, z)
  return z * Grid.width(w) + x
end
-- The cell of a world point.
function Grid.cell(x, z)
  return math.floor(x + 0.5), math.floor(z + 0.5)
end
return Grid
