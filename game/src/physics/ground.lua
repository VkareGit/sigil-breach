-- The walkable ground (plan v5 G2): the one answer to "how high is the floor
-- here" for shots, missiles, thrown charges and hit volumes. Bodies keep
-- their heights relative to it (a jump, a leap, a fall, a crouch); missiles,
-- charges and rays live in world height. The floor of a cell is a heightfield
-- (its elevation, relative to the map datum). Plan v10 V3: a cell may also
-- carry decks, slabs above its floor (a bridge over a room), each with its
-- underside and top: w.decks[z][x] = { { bottom, top }, ... } upward. A
-- point at height y stands on the highest surface at or below y; a body
-- remembers the surface it stands on (o.level, world height), so its floor
-- stays its own as it walks under or over a deck.
local Ground = {}
local RoofCell = require('src.physics.roof_cell')
-- A point this close above a surface (m) still stands on it.
local touch = 1e-6
-- Height (m) of the floor of cell (x, z) above the datum.
function Ground.cell(world, x, z)
  local row = world and world.elevations and world.elevations[z]
  return row and row[x] or 0
end
-- The decks of cell (x, z) (nil: none).
function Ground.decks(world, x, z)
  local row = world and world.decks and world.decks[z]
  return row and row[x]
end
-- The surface of cell (x, z) under height y (both above the datum; y nil:
-- the floor of the cell).
function Ground.surface(world, x, z, y)
  local floor = Ground.cell(world, x, z)
  local decks = y and Ground.decks(world, x, z)
  if decks then
    for _, deck in ipairs(decks) do
      if deck[2] <= y + touch and deck[2] > floor then
        floor = deck[2]
      end
    end
  end
  return floor
end
-- Height (m) of the ground at (x, z) of a world (built by world/arena.lua);
-- y (world height, optional): the ground under that height.
function Ground.height(world, x, z, y)
  local datum = world and world.floor or 0
  if x == nil or z == nil then
    return datum
  end
  local cx, cz = math.floor(x + 0.5), math.floor(z + 0.5)
  if y == nil or not (world and world.decks) then
    return datum + Ground.cell(world, cx, cz)
  end
  return datum + Ground.surface(world, cx, cz, y - datum)
end
-- The ground under a body, a missile or anything with a place: its own
-- level when it keeps one (a world with decks), else the floor.
function Ground.of(world, o)
  return Ground.height(world, o.x, o.z, o.level)
end
-- The underside (world height) of the first deck above height y in the cell
-- at (x, z); nil when the cell is open to the sky above y.
function Ground.ceiling(world, x, z, y)
  local decks = Ground.decks(world, math.floor(x + 0.5), math.floor(z + 0.5))
  if not decks then
    return nil
  end
  local datum, best = world.floor or 0, nil
  for _, deck in ipairs(decks) do
    local bottom = datum + RoofCell.height(deck, x, z)
    if bottom > y + touch and (not best or bottom < best) then
      best = bottom
    end
  end
  return best
end
return Ground
