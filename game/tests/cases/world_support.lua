-- A technical heightfield, never a new playable map. Every assertion uses
-- production construction, movement, contacts and mesh generation.
local Fixtures = require('tests.support.fixtures')
local Test = {}
function Test.run(Game, renderer)
  local Maps = require('src.content.maps.index')
  local Schema = require('src.core.schema')
  local World = require('src.world.arena')
  local Ground = require('src.physics.ground')
  local B = require('src.combat.ballistics')
  local Sphere = require('src.physics.sphere_cast')
  local Flight = require('src.physics.ordnance_flight')
  local Surface = require('src.enemies.surface')
  local Geometry = require('src.render.world_mesh')
  local lines = {}
  local check = Fixtures.checker(lines, 'space: ', 'space: ')
  local function near(a, b)
    return math.abs(a - b) < 1e-6
  end
  local definition = {
    id = 'support_fixture',
    size = 12,
    floor = 3,
    rooms = { { 2, 2, 11, 11 } },
    pillars = { { 9, 3 } },
    spawn = { x = 4, z = 6, yaw = math.pi / 2 },
    portal = { x = 10, z = 10 },
    ember = { x = 10, z = 9 },
    zones = { { name = 'FIXTURE' } },
    anchors = { secret = { x = 3, z = 3 } },
    decor = { props = { { frame = 6, x = 3, z = 3, size = 1, brightness = 1 } } },
    elevations = {
      { x1 = 5, x2 = 5, z1 = 6, z2 = 6, height = 0.24 },
      { x1 = 6, x2 = 6, z1 = 6, z2 = 6, height = 0.48 },
      { x1 = 7, x2 = 7, z1 = 6, z2 = 6, height = 0.72 },
      { x1 = 8, x2 = 9, z1 = 5, z2 = 7, height = 0.96 },
      { x1 = 5, x2 = 5, z1 = 8, z2 = 8, height = 2 },
      { x1 = 9, x2 = 9, z1 = 3, z2 = 3, height = 1 },
    },
  }
  Maps:register(definition.id, definition)
  local ok, reason = pcall(function()
    local g = Game.new('classic', definition.id)
    g.testing = true
    g:start()
    local w, p = g.world, g.player
    check(
      'datum and per-cell support are distinct',
      Ground.height(w) == 3 and Ground.height(w, 8, 6) == 3.96
    )
    local _, _, hit = World.move(w, p, 4.6, 0, 0.22, p)
    check(
      'a walk climbs all authored risers without a jump or wall hit',
      not hit and near(p.x, 8.6) and p.jump == 0
    )
    local _, eye = B.origin(g)
    check(
      'camera and shot origin follow raised support',
      near(eye, Ground.height(w, p.x, p.z) + require('src.content.knight').body.eye)
    )
    local _, _, down = World.move(w, p, 1.5, 0, 0.22, p)
    check(
      'leaving a ledge preserves world height instead of teleporting down',
      not down and near(p.jump, 0.96) and near(Ground.height(w, p.x, p.z) + p.jump, 3.96)
    )
    for _ = 1, 120 do
      g:update(1 / 120, {})
    end
    check('the knight falls and lands on the lower support', p.jump == 0 and p.jumpV == 0)
    p.x, p.z, p.jump = 4, 8, 0
    local _, _, blocked = World.move(w, p, 2, 0, 0.22, p)
    check('a high riser stops a swept body at its near face', blocked and p.x < 4.5 and p.x > 4.2)
    local distance, normal = B.world(w, 4, 3.5, 8, 1, 0, 0, 3)
    check('hitscan meets the same riser', near(distance, 0.5) and normal[1] == -1)
    local sphere = Sphere.world(w, 4, 3.5, 8, 1, 0, 0, 3, 0.1, 0)
    check('finite missile meets it one radius earlier', near(sphere, 0.4))
    local cap = B.world(w, 9, 10, 3, 0, -1, 0, 6)
    check('raised column ray cap includes its supporting elevation', near(cap, 1.2))
    local sphereCap = Sphere.world(w, 9, 10, 3, 0, -1, 0, 6, 0.1, 0)
    check('sphere and ray agree on a raised column cap', near(sphereCap, 1.1))
    local corner = B.world(w, 8, 3.5, 3.49, 1, 0, 0, 2)
    local above = B.world(w, 8, 4.5, 3.49, 1, 0, 0, 2)
    check(
      'square foundation stops shots below a round column but leaves its upper corners clear',
      near(corner, 0.5) and near(above, 2)
    )
    local top, n = B.world(w, 8, 6, 6, 0, -1, 0, 5)
    check(
      'downward ray hits the actual top',
      near(top, 6 - 3.96 - require('src.content.tuning').floorSurface) and n[2] == 1
    )
    check(
      'high riser occludes sight but a small stair does not',
      not World.visible(w, 4, 8, 6, 8) and World.visible(w, 4, 6, 6, 6)
    )
    -- Sight runs between the bodies' own eyes, not one shared plane.
    local Rules = require('src.combat.rules')
    local base = Ground.height(w, 4, 8)
    check(
      'a two-metre riser hides low eyes and not eyes above it',
      not World.visible(w, 4, 8, 6, 8, base + 1, base + 1)
        and World.visible(w, 4, 8, 6, 8, base + 2.6, base + 2.6)
    )
    -- A creature looks from its painted head as posed now: small and large
    -- demons differ, and a leap carries the eyes with it.
    local Pose = require('src.enemies.pose')
    local imp = g:spawn('imp', 6, 8)
    local margrave = g:spawn('boss', 7, 9)
    local _, impHead = Pose.anchor(g, imp, 'head')
    local _, margraveHead = Pose.anchor(g, margrave, 'head')
    check(
      'a creature looks from its own painted head, the larger one from higher',
      near(Rules.eye(g, imp), Ground.height(w, 6, 8) + impHead)
        and near(Rules.eye(g, margrave), Ground.height(w, 7, 9) + margraveHead)
        and margraveHead > impHead
    )
    local grounded = Rules.eye(g, imp)
    imp.leapY = 0.5
    check('a leaping creature looks from its leap', near(Rules.eye(g, imp), grounded + 0.5))
    imp.leapY = 0
    -- Bodies meet up to their painted bodies as posed, not one shared box.
    local Surface = require('src.enemies.surface')
    local impTop, margraveTop = Surface.top(g, imp), Surface.top(g, margrave)
    check(
      'a creature stands as tall as its painted body, the larger one taller',
      impTop > impHead and margraveTop > margraveHead and margraveTop > impTop
    )
    local over = g:spawn('imp', imp.x + 0.1, imp.z)
    over.leapY = impTop + 0.05
    local clears = not Rules.bodiesOverlap(g, imp, over)
    over.leapY = impTop - 0.05
    check(
      'a leap clears a body only above its painted crown',
      clears and Rules.bodiesOverlap(g, imp, over)
    )
    table.remove(g.enemies)
    local low = { x = 6, z = 8, hp = 1, leapY = 0 }
    local high = { x = 6, z = 8, hp = 1, leapY = 2.1 }
    local stated = Rules.bodiesOverlap(g, low, high)
    high.leapY = 2.3
    check(
      'a body that states its height keeps it (the neutral body: 2.2 m)',
      stated and not Rules.bodiesOverlap(g, low, high)
    )
    local knightEye = require('src.content.knight').body.eye
    p.x, p.z, p.jump, p.crouch = 4, 8, 0, 0
    local standing = Rules.eye(g, p)
    p.jump, p.crouch = 0.4, 0
    local jumping = Rules.eye(g, p)
    p.jump, p.crouch = 0, 0.43
    local crouched = Rules.eye(g, p)
    check(
      "the knight's eye follows his jump and his crouch",
      near(standing, base + knightEye)
        and near(jumping, standing + 0.4)
        and near(crouched, standing - 0.43)
    )
    p.crouch = 0
    check(
      'a demon seeing the knight uses both bodies, or his eye at a remembered place',
      Rules.sees(g, imp, g.player)
          == World.visible(w, imp.x, imp.z, p.x, p.z, Rules.eye(g, imp), Rules.eye(g, p))
        and Rules.sees(g, imp, g.player, 4, 6)
          == World.visible(
            w,
            imp.x,
            imp.z,
            4,
            6,
            Rules.eye(g, imp),
            Ground.height(w, 4, 6) + knightEye
          )
    )
    check('navigation finds the stairs to the podium', World.flow(w, 8, 6)[6 * w.size + 4] ~= nil)
    check(
      'navigation cannot climb an isolated two-metre block',
      World.flow(w, 5, 8)[8 * w.size + 4] == nil
    )
    local b = { x = 8, y = 2, z = 6, vx = 0, vy = 0, vz = 0 }
    Flight.advance(
      w,
      b,
      1,
      18.5,
      0,
      { groundDrag = 9, bounce = 1, keep = 0.7, settle = 99, maxContacts = 8 }
    )
    check(
      'ordnance lands on the authored podium in datum-relative flight space',
      b.grounded and near(b.y, 0.96001)
    )
    b = { x = 9, y = 7, z = 3, vx = 0, vy = 0, vz = 0 }
    local flightConfig = { groundDrag = 9, bounce = 1, keep = 0.7, settle = 99, maxContacts = 8 }
    Flight.advance(w, b, 1, 18.5, 0, flightConfig)
    check(
      'ordnance settles on the same raised capital as ray and sphere',
      b.grounded and near(b.y, 5.80001)
    )
    b = { x = 8.51, y = 2, z = 3.49, vx = 0, vy = 0, vz = 0 }
    Flight.advance(w, b, 1, 18.5, 0, flightConfig)
    check(
      'ordnance lands on the foundation corner outside the shaft',
      b.grounded and near(b.y, 1.00001)
    )
    local enemy = g:spawn('imp', 8, 6)
    enemy.awake = false
    local painted = Surface.prepare(g, enemy, {})
    local shown = renderer:enemyPlacement(g, enemy)
    check(
      'painted contact and rendered pose share the same elevated base',
      near(painted.baseY, shown.baseY)
    )
    local Melee = require('src.combat.melee')
    local target = { x = 5, z = 8, jump = 0, crouch = 0 }
    check(
      'a low swing cannot hit through the podium into a raised body',
      not Melee.contact(g, 4.7, 8, 5.2, 8, 0.8, 0.1, target, target)
    )
    check(
      'a swing at the same elevated height can make contact',
      Melee.contact(g, 4.9, 8, 5.2, 8, 2.8, 0.1, target, target)
    )
    local meshResources = require('src.render.resources').new('heightfield fixture')
    local mesh = Geometry.prepare(w, meshResources)
    local lowest = math.huge
    for i = 1, mesh:getVertexCount() do
      local _, y = mesh:getVertex(i)
      lowest = math.min(lowest, y)
    end
    check('rendered floor and walls respect the datum', near(lowest, 3))
    local columnTop = -math.huge
    for i = 1, mesh:getVertexCount() do
      local x, y, z = mesh:getVertex(i)
      if math.abs(x - 9) < 0.7 and math.abs(z - 3) < 0.7 then
        columnTop = math.max(columnTop, y)
      end
    end
    check('column mesh and contact capital have the same world height', near(columnTop, 8.8))
    meshResources:release()
    check(
      'new map does not inherit Limbo decorations',
      #w.decor.props == 1 and w.decor.arches == nil
    )
    w.decor.props[1].x = 4
    w.anchors.secret.x = 4
    check(
      'instance edits cannot mutate map definitions',
      definition.decor.props[1].x == 3 and definition.anchors.secret.x == 3
    )
    local malformed = Schema.inherit(definition, {
      elevations = {
        { x1 = 4, x2 = 5, z1 = 4, z2 = 5, height = 1 },
        { x1 = 5, x2 = 6, z1 = 4, z2 = 5, height = 2 },
      },
    })
    local accepted = pcall(Maps.register, Maps, 'bad_support', malformed)
    check(
      'overlapping support declarations fail transactionally',
      not accepted and not Maps:has('bad_support')
    )
    malformed = Schema.inherit(definition, { floor = 0 / 0 })
    check(
      'non-finite map geometry fails before allocation',
      not pcall(Maps.register, Maps, 'bad_support', malformed)
    )
    malformed = Schema.inherit(
      definition,
      { decor = { arches = { { x = 5, z = 5, spring = 2, rise = 1, halfSpan = 0 / 0 } } } }
    )
    check(
      'decoration recipes reject non-finite dimensions before rendering',
      not pcall(Maps.register, Maps, 'bad_support', malformed)
    )
    malformed =
      Schema.inherit(definition, { rooms = { [1] = { 2, 2, 3, 3 }, [3] = { 5, 5, 6, 6 } } })
    check(
      'a sparse map list cannot silently discard its later geometry',
      not pcall(Maps.register, Maps, 'bad_support', malformed)
    )
    p.x, p.z, p.yaw, p.pitch, p.jump = 8, 10, math.pi, 0, 0
    renderer:draw(g, 960, 540)
    local pixels = renderer.canvas:newImageData()
    local encoded = pixels:encode('png')
    local file = assert(io.open(require('qa.output').path('world-support.png'), 'wb'))
    file:write(encoded:getString())
    file:close()
    encoded:release()
    pixels:release()
  end)
  Maps:unregister(definition.id)
  Maps:unregister('bad_support')
  assert(ok, reason)
  return lines
end
return Test
