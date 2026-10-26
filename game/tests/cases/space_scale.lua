-- Plan v10 V3: space at scale. Maps of any rectangle, and the contracts
-- that keep cost from growing with the size of the world.
local Fixtures = require('tests.support.fixtures')
local Maps = require('src.content.maps.index')
local World = require('src.world.arena')
local Grid = require('src.physics.grid')
local Roles = require('src.core.roles')
local Tests = {}
-- A long hall: 48 cells along x, 16 along z.
local long = {
  id = 'fixture_long',
  width = 48,
  depth = 16,
  rooms = { { 2, 2, 47, 15 } },
  pillars = { { 24, 8 } },
  portal = { x = 46, z = 8 },
  spawn = { x = 4, z = 8, yaw = math.pi / 2 },
  ember = { x = 6, z = 8 },
  zones = { { name = 'LONG HALL' } },
}
function Tests.run(Game)
  local lines = {}
  local check = Fixtures.checker(lines, 'space at scale: ', 'space at scale: ')
  Maps:register(long.id, long)
  local ok, problem = pcall(function()
    local g = Game.new('classic', long.id)
    g.testing = true
    local w = g.world
    check(
      'a rectangular map keeps its width and depth (no square size)',
      Grid.width(w) == 48
        and Grid.depth(w) == 16
        and w.size == nil
        and #w.map == 16
        and #w.map[1] == 48
    )
    check(
      'bounds follow each axis',
      not World.solid(w, 40, 8, 0.3)
        and World.solid(w, 8, 16.6, 0.3)
        and World.solid(w, 48.4, 8, 0.3)
    )
    local body = { x = 30, z = 4 }
    World.move(w, body, 12, 0, 0.3)
    check('a body walks past the old 31-cell edge', math.abs(body.x - 42) < 1e-9)
    local Navigation = require('src.world.navigation')
    local field = World.flow(w, 46, 8)
    check(
      'the exact field covers its window around the goal, not the far end of the hall',
      field[Grid.key(w, 20, 8)] ~= nil and field[Grid.key(w, 3, 8)] == nil
    )
    local distance = Navigation.distance(w, 3, 8, 46, 8)
    local wx = Navigation.waypoint(w, 3, 8, 46, 8, 0)
    check(
      'beyond the window the regions give a distance and a step toward the goal',
      distance ~= nil and distance >= 32 and wx ~= nil and wx > 3
    )
    check(
      'sight runs the length of the hall past its pillar side',
      World.visible(w, 3, 4, 46, 4) and not World.visible(w, 20, 8, 28, 8)
    )
  end)
  Maps:unregister(long.id)
  assert(ok, problem)

  -- A 256 x 256 map of 16 x 16 rooms joined by one-cell doors.
  local rooms, side = {}, 256
  for rz = 0, 15 do
    for rx = 0, 15 do
      local x1, z1 = rx * 16 + 2, rz * 16 + 2
      rooms[#rooms + 1] = { x1, z1, x1 + 13, z1 + 13 }
      if rx < 15 then
        rooms[#rooms + 1] = { x1 + 14, z1 + 7, x1 + 15, z1 + 7 }
      end
      if rz < 15 then
        rooms[#rooms + 1] = { x1 + 7, z1 + 14, x1 + 7, z1 + 15 }
      end
    end
  end
  local maze = {
    id = 'fixture_rooms',
    size = side,
    rooms = rooms,
    portal = { x = 9, z = 9 },
    spawn = { x = 9, z = 9, yaw = 0 },
    ember = { x = 10, z = 9 },
    zones = { { name = 'ROOMS' } },
  }
  Maps:register(maze.id, maze)
  ok, problem = pcall(function()
    local Navigation = require('src.world.navigation')
    local g = Game.new('classic', maze.id)
    g.testing = true
    local w = g.world
    -- The regions are built once per geometry; a query then stays local.
    Navigation.distance(w, 9, 9, 249, 249)
    local fine, coarse = World.stats.visited, Navigation.stats.visited
    local distance = Navigation.distance(w, 25, 9, 233, 249)
    local wx, wz = Navigation.waypoint(w, 25, 9, 233, 249, 0)
    local visited = World.stats.visited - fine + Navigation.stats.visited - coarse
    check(
      'a path query across a 256 x 256 map visits a small part of it ('
        .. visited
        .. ' of 65536 cells)',
      distance ~= nil and wx ~= nil and visited < 65536 / 10
    )
    -- A demon walks through many rooms to a far goal, door after door.
    local demon = g:spawn('imp', 9, 9)
    demon.awake, demon.memory, demon.attack, demon.spawnAge = true, 1e9, 1e9, 1
    local goalX, goalZ = 89, 73
    Roles.controlled(g).x, Roles.controlled(g).z = goalX, goalZ
    g.state = 'playing'
    for _ = 1, 120 * 90 do
      demon.lastX, demon.lastZ, demon.visible = goalX, goalZ, false
      demon.sense = 1
      g:update(1 / 120, {})
      if math.abs(demon.x - goalX) + math.abs(demon.z - goalZ) < 3 then
        break
      end
    end
    check(
      'a demon crosses rooms of other sectors to reach a far goal',
      math.abs(demon.x - goalX) + math.abs(demon.z - goalZ) < 3
    )
    -- Clearance: a wide body does not fit a one-cell door; a narrow one does.
    local narrow = World.flow(w, 9, 9, 0)
    local wide = World.flow(w, 9, 9, World.class(0.9))
    check(
      'a body wider than a door has no route through it; the usual demons do',
      narrow[Grid.key(w, 25, 9)] ~= nil
        and wide[Grid.key(w, 25, 9)] == nil
        and World.class(0.55) == 0
    )
    -- The field cache keeps the most recently used fields.
    local first = World.flow(w, 30, 30)
    for i = 1, World.flowCacheSize - 1 do
      World.flow(w, 30 + i, 31)
      World.flow(w, 30, 30)
    end
    World.flow(w, 60, 60)
    check('the least recently used field gives way first', World.flow(w, 30, 30) == first)
  end)
  Maps:unregister(maze.id)
  assert(ok, problem)

  -- The indexed crowd separation equals the pass over every pair, bit for
  -- bit, in a dense crowd where bodies move far within one pass.
  local AI = require('src.enemies.ai')
  local Rules = require('src.combat.rules')
  local Pools = require('src.session.world')
  local Archetypes = require('src.content.enemies')
  local function crowd()
    local g = Fixtures.arena(Game)
    local kinds = { 'imp', 'armored', 'stolas', 'boss' }
    for i = 1, 150 do
      local x = 9 + (i * 37 % 97) / 97 * 14
      local z = 12 + (i * 53 % 89) / 89 * 9
      g:spawn(kinds[i % #kinds + 1], x, z)
    end
    return g
  end
  local function everyPair(g, dt)
    local S = Archetypes.defaults.separation
    local bodies = Pools.of(g, 'enemies')
    for i, a in ipairs(bodies) do
      if a.hp > 0 then
        for j = i + 1, #bodies do
          local b = bodies[j]
          local dx, dz = a.x - b.x, a.z - b.z
          local d = math.sqrt(dx * dx + dz * dz)
          local minimum = math.max(S.minimum, Rules.radius(a) + Rules.radius(b))
          if b.hp > 0 and d < minimum and Rules.bodiesOverlap(g, a, b) then
            local overlap = minimum - d
            if d < 0.001 then
              dx, dz, d = 1, 0, 1
            end
            local amount = math.min(S.step, dt * S.rate, overlap * S.share)
            local ma, mb = Rules.body(a).mass or 1, Rules.body(b).mass or 1
            local ga, gb = 2 * amount * mb / (ma + mb), 2 * amount * ma / (ma + mb)
            World.move(g.world, a, dx / d * ga, dz / d * ga, Rules.radius(a))
            World.move(g.world, b, -dx / d * gb, -dz / d * gb, Rules.radius(b))
          end
        end
      end
    end
  end
  local reference, indexed = crowd(), crowd()
  for _ = 1, 20 do
    everyPair(reference, 1 / 120)
    AI.separate(indexed, 1 / 120)
  end
  local same, moved = true, false
  local a, b = Pools.of(reference, 'enemies'), Pools.of(indexed, 'enemies')
  for i = 1, #a do
    same = same and a[i].x == b[i].x and a[i].z == b[i].z
  end
  local fresh = Pools.of(crowd(), 'enemies')
  for i = 1, #a do
    moved = moved or a[i].x ~= fresh[i].x
  end
  check(
    'indexed separation equals the pass over every pair, bit for bit (150 bodies, 20 steps)',
    same and moved and #a == 150
  )

  -- Rays skip bodies whose reach they never come near: the same hits.
  local B = require('src.combat.ballistics')
  local shot = crowd()
  local prepared = B.prepare(shot)
  local plain = {}
  for i, entry in ipairs(prepared) do
    plain[i] = { enemy = entry.enemy, surface = entry.surface, volumes = entry.volumes }
  end
  local equal, hits = true, 0
  for i = 1, 400 do
    local yaw = math.pi + (i % 40 - 20) * 0.02
    local pitch = (math.floor(i / 40) - 5) * 0.03
    local dx, dy, dz = B.direction(yaw, pitch)
    local t1, d1, _, _, _, k1, _, p1 = B.traceVector(shot, dx, dy, dz, 40, prepared)
    local t2, d2, _, _, _, k2, _, p2 = B.traceVector(shot, dx, dy, dz, 40, plain)
    equal = equal and t1 == t2 and d1 == d2 and k1 == k2 and p1 == p2
    hits = hits + (t1 and 1 or 0)
  end
  check(
    'rays with the reach filter meet the same parts at the same distances (400 rays)',
    equal and hits > 50
  )
  return lines
end
return Tests
