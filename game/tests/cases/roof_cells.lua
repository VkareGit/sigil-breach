local Fixtures = require('tests.support.fixtures')
local Roof = require('src.physics.roof_cell')
local Ground = require('src.physics.ground')
local Ballistics = require('src.combat.ballistics')
local Sphere = require('src.physics.sphere_cast')
local T = require('src.content.tuning')
local Tests = {}
function Tests.run()
  local lines = {}
  local check = Fixtures.checker(lines, 'vault: ', 'vault: ')
  local near = Fixtures.within(1e-6)
  -- y = 4 + u: an independent analytic plane, not another call to height().
  local slope = { 4, 7, { 4, 5, 5, 4 } }
  local t, n = Roof.cast(slope, 4, 4, 4, 1, 4, 0, 1, 0, 0, 10)
  check(
    'point ray meets analytic inclined plane and outward normal',
    near(t, 3.5) and near(n[1], 1 / math.sqrt(2)) and near(n[2], -1 / math.sqrt(2))
  )
  t = Roof.cast(slope, 4, 4, 4, 1, 4, 0, 1, 0, 0.1, 10)
  check('finite radius meets the plane before its centre', near(t, 3.5 - 0.1 * math.sqrt(2)))
  local fast = Roof.cast(slope, 4, 4, 4, 1, 4, 0, 100, 0, 0.1, 1)
  check('high speed does not tunnel', near(fast * 100, t))
  check('short range stays clear', not Roof.cast(slope, 4, 4, 4, 1, 4, 0, 1, 0, 0.1, 2))
  check('a ray above and moving away misses', not Roof.cast(slope, 4, 4, 4, 8, 4, 0, 1, 0, 0, 3))
  check('initial overlap is immediate', Roof.cast(slope, 4, 4, 4, 5, 4, 0, 0, 0, 0.1, 1) == 0)
  local flat = { 4, 6, { 4, 4, 4, 4 } }
  check(
    'expanded-box corner is not a sphere contact',
    not Roof.cast(flat, 4, 4, 3.3, 5, 3.3, 0, 0, 0, 0.25, 1)
  )
  check(
    'rounded corner really inside radius contacts',
    Roof.cast(flat, 4, 4, 3.4, 5, 3.4, 0, 0, 0, 0.25, 1) == 0
  )
  check(
    'same profile reused at a different cell has no stale coordinates',
    near(Roof.cast(flat, 8, 8, 8, 1, 8, 0, 1, 0, 0, 10), 3)
  )
  local deck = { 4, 8, { 4, 5, 6, 5, 6.2 } }
  local w = {
    width = 7,
    depth = 7,
    floor = 2.25,
    map = {},
    seals = {},
    decks = { [4] = { [4] = { deck } } },
    geometryRevision = 1,
  }
  for z = 1, 7 do
    w.map[z] = {}
    for x = 1, 7 do
      w.map[z][x] = 0
    end
  end
  local owner = require('src.render.resources').new('vault regression')
  local mesh = require('src.render.world_mesh').prepare(w, owner)
  local triangles = 0
  for i = 1, mesh:getVertexCount(), 3 do
    local a, b, c = { mesh:getVertex(i) }, { mesh:getVertex(i + 1) }, { mesh:getVertex(i + 2) }
    if a[5] < -0.01 and a[2] > 3 + w.floor then
      local x, y, z = (a[1] + b[1] + c[1]) / 3, (a[2] + b[2] + c[2]) / 3, (a[3] + b[3] + c[3]) / 3
      triangles = triangles + 1
      local point = Ballistics.world(w, x, w.floor + 1, z, 0, 1, 0, 20)
      local sphere = Sphere.world(w, x, w.floor + 1, z, 0, 1, 0, 20, 0, T.floorSurface)
      check(
        'visible triangle agrees with ground/ray/sphere at raised datum ' .. triangles,
        near(Ground.ceiling(w, x, z, w.floor + 1), y)
          and near(point, y - w.floor - 1)
          and near(sphere, point)
      )
    end
  end
  check('centre sample produces four visible triangles', triangles == 4)
  owner:release()
  -- Interior sample locations across all fan sectors, including their seams.
  for _, delta in ipairs({
    { 0, 0 },
    { -0.35, -0.12 },
    { 0.22, -0.37 },
    { 0.4, 0.19 },
    { -0.2, 0.36 },
    {
      0.3,
      0.3,
    },
  }) do
    local x, z = 4 + delta[1], 4 + delta[2]
    local ray = Ballistics.world(w, x, w.floor + 1, z, 0, 1, 0, 20)
    check(
      'profile fan is watertight ' .. delta[1] .. ':' .. delta[2],
      near(ray, Ground.ceiling(w, x, z, w.floor + 1) - w.floor - 1)
    )
  end
  local Maps = require('src.content.maps.index')
  local Schema = require('src.content.maps.schema')
  local function reject(edit)
    local def = require('src.core.schema').copy(Maps:get('proving'))
    edit(def)
    return not pcall(Schema.check, def, 'invalid-vault')
  end
  check(
    'inverted profile rejected before rendering',
    reject(function(d)
      d.decks[1].bottoms[1] = 15
    end)
  )
  check(
    'profile outside one cell rejected',
    reject(function(d)
      d.decks[1].x2 = d.decks[1].x1 + 1
    end)
  )
  check(
    'false light parameter rejected',
    reject(function(d)
      d.lamps[1].brightness = false
    end)
  )
  check(
    'unknown relic rejected',
    reject(function(d)
      d.decor.props[1].art = 'missing'
    end)
  )
  return lines
end
return Tests
