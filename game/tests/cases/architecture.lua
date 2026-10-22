local Fixtures = require('tests.support.fixtures')
local Tests = {}

function Tests.run(G, renderer)
  local lines = {}
  local check = Fixtures.checker(lines, 'architecture: ', '')
  require('tests.cases.app_architecture').run(check)

  local World = require('src.world.arena')
  local Geometry = require('src.render.world_mesh')
  local Lights = require('src.render.lights')
  local original = love.graphics.newMesh
  love.graphics.newMesh = function()
    error('world data must not allocate GPU resources')
  end
  local ok, world = pcall(World.new, 'descent')
  love.graphics.newMesh = original
  check('world creation works without graphics allocation', ok and world.mesh == nil)
  check(
    'world contains lamps and collision before its first draw',
    #world.lamps > 0 and World.solid(world, 12, 25, 0.2) and not World.solid(world, 16, 27, 0.2)
  )

  local lights = Lights.new()
  lights:prepare(world)
  local oldSources, revision = lights.sources, world.geometryRevision
  local mesh = Geometry.prepare(world)
  check(
    'first rendering creates one cached mesh',
    mesh == world.mesh and Geometry.prepare(world) == mesh
  )
  local vertices = mesh:getVertexCount()
  World.rebuild(world)
  check(
    'rebuilding data invalidates geometry without eagerly allocating a replacement',
    world.geometryRevision == revision + 1 and world.mesh == mesh
  )
  lights:prepare(world)
  check(
    'light cache follows world data revision independently of mesh allocation',
    lights.sources ~= oldSources
  )
  local rebuilt = Geometry.prepare(world)
  check(
    'next render rebuilds identical arena geometry once',
    rebuilt ~= mesh and rebuilt:getVertexCount() == vertices
  )
  check('unchanged world reuses the rebuilt resource', Geometry.prepare(world) == rebuilt)
  rebuilt:release()
  world.mesh, world.meshRevision = nil, nil
  return lines
end

return Tests
