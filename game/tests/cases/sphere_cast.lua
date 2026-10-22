-- Finite missiles meet the same rounded walls, pillar caps and ground at any tick rate.
local Fixtures = require('tests.support.fixtures')
local Sphere = require('src.physics.sphere_cast')
local Collision = require('src.physics.collision')
local Projectiles = require('src.combat.projectiles')
local Tuning = require('src.content.tuning')
local Tests = {}
function Tests.run(Game)
  local lines = {}
  local check = Fixtures.checker(lines, 'sphere cast: ', 'sphere cast: ')
  local function world(tile)
    local w = { size = 20, map = {} }
    for z = 1, w.size do
      w.map[z] = {}
      for x = 1, w.size do
        w.map[z][x] = 0
      end
    end
    w.map[10][10] = tile or 0
    return w
  end
  local w = world(1)
  local d, normal, kind = Sphere.world(w, 7, 1, 10, 1, 0, 0, 6, 0.2, Tuning.floorSurface)
  check(
    'wall contact occurs one radius before the centreline',
    kind == 'wall' and math.abs(d - 2.3) < 1e-6 and normal[1] < -0.99
  )
  d, normal, kind = Sphere.world(w, 7, 1, 10.65, 1, 0, 0, 6, 0.2, Tuning.floorSurface)
  local corner = 2.5 - math.sqrt(0.2 ^ 2 - 0.15 ^ 2)
  check(
    'rounded wall edge catches a grazing sphere whose centre misses',
    kind == 'wall' and math.abs(d - corner) < 1e-6 and normal[3] > 0
  )
  local _, _, clear = Sphere.world(w, 7, 1, 10.71, 1, 0, 0, 6, 0.2, Tuning.floorSurface)
  check('a sphere outside the real rounded edge stays clear', clear == 'range')
  d, _, kind = Sphere.world(w, 10, 6, 10, 0, -1, 0, 4, 0.2, Tuning.floorSurface)
  check(
    'sphere touches a wall cap before its centre does',
    kind == 'wall' and math.abs(d - (6 - Collision.heights.wall - 0.2)) < 1e-6
  )
  w = world(2)
  d, normal, kind = Sphere.world(w, 7, 1, 10.55, 1, 0, 0, 6, 0.2, Tuning.floorSurface)
  local side = 3 - math.sqrt((Collision.pillarRadius + 0.2) ^ 2 - 0.55 ^ 2)
  check(
    'pillar sides are rounded, including finite-radius grazing',
    kind == 'wall' and math.abs(d - side) < 1e-6 and normal[3] > 0
  )
  d, normal, kind =
    Sphere.world(w, 7, Collision.heights.pillar + 0.15, 10, 1, 0, 0, 6, 0.2, Tuning.floorSurface)
  local rim = 3 - Collision.pillarRadius - math.sqrt(0.2 ^ 2 - 0.15 ^ 2)
  check(
    'the capped pillar rim uses a rounded sphere contact, not an expanded cylinder',
    kind == 'wall' and math.abs(d - rim) < 1e-6 and normal[2] > 0
  )
  _, _, clear =
    Sphere.world(w, 7, Collision.heights.pillar + 0.21, 10, 1, 0, 0, 6, 0.2, Tuning.floorSurface)
  check('a sphere clearing the capital is not blocked by an infinite pillar', clear == 'range')
  w = world()
  w.floor = 3
  d, normal, kind = Sphere.world(w, 7, 4, 10, 0, -1, 0, 6, 0.2, Tuning.floorSurface)
  check(
    'floor contact uses world height and the projectile radius',
    kind == 'floor' and math.abs(d - (1 - Tuning.floorSurface - 0.2)) < 1e-7 and normal[2] == 1
  )
  d, _, kind = Sphere.world(w, -8, 4, 10, 1, 0, 0, 1, 0.2, Tuning.floorSurface)
  check(
    'a sphere already far outside the map cannot bypass its boundary',
    kind == 'wall' and d == 0
  )
  -- Exercise the actual projectile system, not just the geometric helper.
  for _, rate in ipairs({ 60, 120, 240 }) do
    for _, tile in ipairs({ 1, 2 }) do
      local g = Fixtures.arena(Game)
      g.world = world(tile)
      g.player.x, g.player.z = 3, 3
      local b = {
        x = 7,
        y = 1,
        z = tile == 1 and 10.65 or 10.55,
        vx = 30,
        vy = 0,
        vz = 0,
        life = 1,
        radius = 0.2,
      }
      g.bullets = { b }
      for _ = 1, rate do
        Projectiles.update(g, 1 / rate)
        if #g.bullets == 0 then
          break
        end
      end
      local expected = tile == 1 and corner or side
      check(
        'actual grazing projectile stops at the same contact: tile '
          .. tile
          .. ', '
          .. rate
          .. ' Hz',
        #g.bullets == 0 and math.abs(b.x - 7 - expected) < 1e-6
      )
    end
    for _, radius in ipairs({ 0.05, 0.4 }) do
      local g = Fixtures.arena(Game)
      g.world = world()
      g.player.x, g.player.z = 3, 3
      local b = { x = 7, y = 2, z = 10, vx = 0, vy = -30, vz = 0, life = 1, radius = radius }
      g.bullets = { b }
      for _ = 1, rate do
        Projectiles.update(g, 1 / rate)
        if #g.bullets == 0 then
          break
        end
      end
      check(
        'actual floor impact radius ' .. radius .. ' at ' .. rate .. ' Hz',
        #g.bullets == 0 and math.abs(b.y - Tuning.floorSurface - radius) < 1e-7
      )
    end
  end
  return lines
end
return Tests
