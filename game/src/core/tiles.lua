-- What a cell of a map's grid is. A map stores the code; everything else asks the
-- tables below, indexed by code, built here once:
--   walkable     a body stands on it and routes cross it
--   solid        stone: it stops bodies, shots and sight
--   round        a round pillar inside its cell
--   masonry      a wall the painted hall builds on
--   speed        share of walking speed on it (default 1)
-- A new tile is one entry; codes stay single digits, as a saved row holds them.
local Tiles = { codes = {}, walkable = {}, solid = {}, round = {}, masonry = {}, speed = {} }
local count = 0
function Tiles.define(id, def)
  assert(not Tiles.codes[id], 'tile already defined: ' .. tostring(id))
  assert(count <= 9, 'a saved row holds single digits')
  local code = count
  count = count + 1
  Tiles.codes[id] = code
  Tiles[id] = code
  Tiles.walkable[code] = def.walkable or nil
  Tiles.solid[code] = def.solid or nil
  Tiles.round[code] = def.round or nil
  Tiles.masonry[code] = def.masonry or nil
  Tiles.speed[code] = def.speed or 1
  return code
end
-- A tile leaves with the mod that brought it, the last one first.
function Tiles.undefine(id)
  local code = Tiles.codes[id]
  assert(code == count - 1, 'tiles leave in reverse order')
  count = count - 1
  Tiles.codes[id], Tiles[id] = nil, nil
  Tiles.walkable[code], Tiles.solid[code], Tiles.round[code] = nil, nil, nil
  Tiles.masonry[code], Tiles.speed[code] = nil, nil
end
Tiles.define('floor', { walkable = true })
Tiles.define('wall', { solid = true, masonry = true })
Tiles.define('pillar', { solid = true, round = true })
-- Stone the painted map already draws: it stops bodies and has no mesh of its own.
Tiles.define('blocked', { solid = true })
return Tiles
