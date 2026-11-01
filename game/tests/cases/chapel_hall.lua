-- A painted hall: its surfaces agree with their layout, what is drawn is what
-- is walked on, and nothing it adds closes a route.
local F = require('tests.support.fixtures')
local Art = require('src.content.art.chapel_hall')
local Maps = require('src.content.maps.index')
local T = {}
function T.run()
  local lines = {}
  local check = F.checker(lines, 'chapel hall: ', 'chapel hall: ')
  local W = require('src.world.arena')
  local Ground = require('src.physics.ground')
  local Halls = require('src.render.kit.halls')
  local world = W.new('proving')
  local hall = world.decor.halls[1]
  check('the proving ground places its hall', hall ~= nil and hall.kit == 'chapel')
  for name, path in pairs(Art.images) do
    check('surface image exists: ' .. name, love.filesystem.getInfo(path) ~= nil)
  end
  for name, path in pairs(Art.tiles) do
    check('tile image exists: ' .. name, love.filesystem.getInfo(path) ~= nil)
  end
  for name, surface in pairs(Art.surfaces) do
    check('surface names a known image: ' .. name, Art.images[surface.image] ~= nil)
  end
  local bay = Art.surfaces.bay_a
  check(
    'a niche recedes where its layout says, and the wall beside it does not',
    Art.relief(bay, 1.9, 2) < -0.5 and Art.relief(bay, 3.25, 2) == 0
  )
  check('below its sill a niche has no depth', Art.inside(bay.features[1], 1.9, 0.2) < 0)
  check(
    'every room of the proving ground is painted',
    Halls.covers(world, 10, 20) and Halls.covers(world, 10, 7) and Halls.covers(world, 24, 20)
  )
  for _, s in ipairs(hall.sarcophagi) do
    for z = s.z1, s.z2 do
      check(
        'a sarcophagus is solid to a walker: ' .. s.x .. ',' .. z,
        Ground.cell(world, s.x, z) >= 1
      )
    end
  end
  local step = require('src.content.tuning').terrain.stepHeight
  local previous = 0
  for _, z in ipairs({ 11, 10, 9, 8, 7 }) do
    local height = Ground.cell(world, 10, z)
    check('the altar steps can be climbed at z ' .. z, height - previous <= step + 1e-8)
    previous = height
  end
  check('the altar table is solid', Ground.cell(world, 10, 6) > step)
  check('both halls share their steps', Ground.cell(world, 38, 8) == Ground.cell(world, 10, 8))
  for z = 1, #world.map do
    for x = 1, #world.map[z] do
      if world.map[z][x] ~= 1 then
        assert(Halls.covers(world, x, z), 'an open cell has no painted room: ' .. x .. ',' .. z)
      end
    end
  end
  local seen, open = { [29] = { [10] = true } }, { { 10, 29 } }
  while #open > 0 do
    local c = table.remove(open)
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      local x, z = c[1] + d[1], c[2] + d[2]
      local row = world.map[z]
      if row and row[x] == 0 and not (seen[z] and seen[z][x]) then
        if Ground.cell(world, x, z) - Ground.cell(world, c[1], c[2]) <= step + 1e-8 then
          seen[z] = seen[z] or {}
          seen[z][x] = true
          open[#open + 1] = { x, z }
        end
      end
    end
  end
  check('the altar stays reachable on foot', seen[7] and seen[7][10])
  check('the door to the nave stays reachable on foot', seen[27] and seen[27][18])
  local count = 0
  for _, placed in ipairs(world.decor.halls) do
    for _, part in ipairs(Halls.kits[placed.kit].build(world, placed)) do
      count = count + #part.vertices
      check('a part has whole triangles: ' .. part.path, #part.vertices % 3 == 0)
      local first = part.vertices[1]
      for i = 1, 12 do
        assert(first[i] == first[i], 'hall vertex is not a number: ' .. part.path)
      end
    end
  end
  check('the map stays inside its vertex budget ' .. count, count > 0 and count < 1300000)
  local old = Maps:get('floor')
  check('a map without halls declares none', not (old.decor and old.decor.halls))
  return lines
end
return T
