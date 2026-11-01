-- Heightfield movement uses point support and a distinct horizontal footprint.
-- These are behavioural regressions found by an independent F07 review.
local Fixtures = require('tests.support.fixtures')
local Test = {}
function Test.run(Game)
  local Maps = require('src.content.maps.index')
  local World = require('src.world.arena')
  local Ground = require('src.physics.ground')
  local Contact = require('src.combat.body_contact')
  local Actions = require('src.enemies.actions')
  local Body = require('src.enemies.body')
  local Rules = require('src.combat.rules')
  local Melee = require('src.combat.melee')
  local Presentation = require('src.session.presentation')
  local K = require('src.physics.kinematics')
  local gravity = require('src.content.tuning').gravity
  local lines = {}
  local check = Fixtures.checker(lines, 'terrain: ', 'terrain: ')
  local function near(a, b, epsilon)
    return math.abs(a - b) < (epsilon or 1e-7)
  end
  local definition = {
    id = 'terrain_motion_fixture',
    size = 12,
    floor = 3,
    rooms = { { 2, 2, 11, 11 } },
    spawn = { x = 3, z = 5, yaw = math.pi / 2 },
    portal = { x = 10, z = 10 },
    ember = { x = 10, z = 9 },
    zones = { { name = 'TERRAIN MOTION' } },
    elevations = {
      { x1 = 2, x2 = 4, z1 = 2, z2 = 11, height = 1 },
      { x1 = 8, x2 = 8, z1 = 4, z2 = 8, height = 0.24 },
    },
  }
  Maps:register(definition.id, definition)
  local oldLanding = Presentation.hooks['motion.landing']
  local landingCount = 0
  Presentation.hook('motion.landing', function(g, speed)
    landingCount = landingCount + 1
    if oldLanding then
      return oldLanding(g, speed)
    end
  end)
  local ok, reason = pcall(function()
    local function fresh()
      local g = Game.new('floor', definition.id)
      g.ephemeral = true
      g:start()
      return g
    end
    local g = fresh()
    local w, p = g.world, g.player
    local radius = Rules.radius({ kind = 'imp' })
      + require('src.content.characters').standard().body.radius
    p.x, p.z = 4.48 + radius, 5
    local e = g:spawn('imp', 4.3, 5)
    Contact.moveEnemy(g, e, 0.5, 0)
    check(
      'rejected enemy ledge crossing cannot double the support height',
      near(e.x, 4.48) and near(Ground.height(w, e.x, e.z) + (e.leapY or 0), 4)
    )
    check(
      'a rejected crossing does not fabricate an enemy flight lifecycle',
      e.leapY == nil and e.leapVY == nil
    )

    g = fresh()
    w, p = g.world, g.player
    p.x, p.z, p.vx, p.vz, p.yaw = 4.49, 5, 4, 0, math.pi / 2
    e = g:spawn('imp', 4.495 + radius, 5)
    e.awake = false
    g:update(1 / 120, { forward = 1 })
    check(
      'full knight update rejects provisional fall when another body blocks the edge',
      near(p.x, 4.495) and p.jump == 0 and p.jumpV == 0
    )

    g = fresh()
    w, p = g.world, g.player
    p.x, p.z, p.vx, p.vz, p.yaw = 4.4, 7, 4, 0, math.pi / 2
    local largest = 0
    for _ = 1, 12 do
      local x = p.x
      g:update(1 / 120, { forward = 1 })
      largest = math.max(largest, p.x - x)
    end
    check(
      'walking off a ledge never teleports the trailing footprint',
      largest < 0.06 and p.x > 4.5
    )
    check(
      'walking off a ledge preserves descending world height',
      Ground.height(w, p.x, p.z) + p.jump < 4 and p.jumpV < 0
    )

    p = { x = 4.55, z = 5, jump = 0.8, vx = 2, vz = 0 }
    World.move(w, p, 0.1, 0, 0.22, p)
    check(
      'trailing overlap may leave a riser without gaining velocity',
      near(p.x, 4.65) and p.vx == 2
    )
    local y = Ground.height(w, p.x, p.z) + p.jump
    p.vx = -2
    local _, _, blocked = World.move(w, p, -0.1, 0, 0.22, p)
    check(
      'sharp reversal into the old riser is blocked rather than tunnelling',
      blocked
        and near(p.x, 4.65, 1e-6)
        and p.vx == 0
        and near(Ground.height(w, p.x, p.z) + p.jump, y)
    )
    local x = p.x
    World.move(w, p, 0, 0.1, 0.22)
    check('the same overlap retains tangent motion', near(p.x, x) and near(p.z, 5.1))
    p = { x = 4.5000001, z = 5, jump = 0.8, vx = -8, vz = 2 }
    World.move(w, p, -1, 0.25, 0.22, p)
    check(
      'near-boundary reversal keeps the full tangent without repeated inward substeps',
      near(p.x, 4.5000001, 1e-6) and near(p.z, 5.25) and p.vx == 0 and p.vz == 2
    )

    p = { x = 7.2, z = 6, jump = 0.1 }
    local _, _, airBlocked = World.move(w, p, 0.5, 0, 0.22)
    check(
      'an airborne low body cannot auto-step up into a riser',
      airBlocked and p.x < 7.5 and near(Ground.height(w, p.x, p.z) + p.jump, 3.1)
    )
    p = { x = 7.2, z = 6, jump = 0 }
    local _, _, stepBlocked = World.move(w, p, 0.7, 0, 0.22)
    check(
      'the same authored riser is climbable by grounded feet',
      not stepBlocked and near(p.x, 7.9) and p.jump == 0 and near(Ground.height(w, p.x, p.z), 3.24)
    )

    local function flight(steps, duration)
      local e2 = {
        x = 4.49,
        z = 7,
        hp = 100,
        kind = 'imp',
        leapY = 0.005,
        leapVY = -1,
        leapVX = 4,
        leapVZ = 0,
      }
      local g2 = { world = w, player = { x = 10, z = 10, jump = 0, crouch = 0 }, enemies = { e2 } }
      local used = 0
      for _ = 1, steps do
        local _, time = Actions.flight(g2, e2, duration / steps)
        used = used + (time or 0)
      end
      return e2, used
    end
    for _, steps in ipairs({ 1, 2, 10 }) do
      local duration = 1 / 120
      local airborne, used = flight(steps, duration)
      check(
        'flight consumes the whole tick across a lower support (' .. steps .. ' slices)',
        near(used, duration)
          and near(airborne.x, 4.49 + 4 * duration)
          and near(
            Ground.height(w, airborne.x, airborne.z) + airborne.leapY,
            4.005 - duration - 0.5 * gravity * duration ^ 2
          )
          and near(airborne.leapVY, -1 - gravity * duration)
      )
    end
    local long, longUsed = flight(1, 0.2)
    local split, splitUsed = flight(24, 0.2)
    check(
      'a longer airborne traversal is invariant to time subdivision',
      near(longUsed, splitUsed)
        and near(long.x, split.x)
        and near(long.leapY, split.leapY)
        and near(long.leapVY, split.leapVY)
    )
    e = { x = 8, z = 6, hp = 100, kind = 'imp', leapY = 0.3, leapVY = -1, leapVX = 0, leapVZ = 0 }
    local landed, used =
      Actions.flight({ world = w, player = { x = 10, z = 10, jump = 0 } }, e, 0.5)
    check(
      'vertical enemy landing uses the raised platform and exact contact time',
      landed and e.leapY == nil and near(used, K.fallTime(0.3, -1, gravity))
    )
    check('near-support descending time retains precision', K.fallTime(1e-18, -1, gravity) > 0)

    local from = { x = 4.49, z = 5, jump = 0.005, crouch = 0 }
    local to = { x = 4.52, z = 5, jump = 1, crouch = 0 }
    local at = Melee.playerAt(from, to, 0.25, nil, w)
    check(
      'partial attack windows interpolate feet in world space across support changes',
      near(Ground.height(w, at.x, at.z) + at.jump, 4.00375)
    )

    g = fresh()
    p = g.player
    p.x, p.z = 8, 6
    landingCount = 0
    g:update(1 / 120, { jump = true })
    local airborne = p.jump > 0
    for _ = 1, 180 do
      g:update(1 / 120, {})
    end
    check('a real jump returns to the raised support', airborne and p.jump == 0 and p.jumpV == 0)
    check('that landing emits exactly one contact response', landingCount == 1)
    local function dashFall(steps)
      local session = fresh()
      local knight = session.player
      knight.x, knight.z = 4.49, 7
      knight.dashTimer, knight.dashX, knight.dashZ = 0.1, 1, 0
      for _ = 1, steps do
        session:update(1 / 120 / steps, {})
      end
      return knight
    end
    local d1, d10 = dashFall(1), dashFall(10)
    check(
      'knight gravity starts at the ledge, including when a dash tick is subdivided',
      near(d1.x, d10.x) and near(d1.jump, d10.jump) and near(d1.jumpV, d10.jumpV)
    )

    local function corpse(steps)
      local dead = {
        kind = 'imp',
        x = 4.49,
        z = 7,
        hp = 0,
        maxHp = 50,
        deathTime = 0,
        fallY = 0.005,
        fallVY = -1,
        pushX = 4,
        pushZ = 0,
      }
      local cg = { world = w, enemies = { dead } }
      for _ = 1, steps do
        Body.fall(cg, dead, 1 / 120 / steps)
      end
      return dead
    end
    local c1, c10 = corpse(1), corpse(10)
    check(
      'airborne corpse motion also preserves the remainder of a ledge-crossing tick',
      near(c1.x, c10.x)
        and near(c1.fallY, c10.fallY)
        and near(c1.fallVY, c10.fallVY)
        and near(c1.pushX, c10.pushX)
    )
    local function slidingCorpse(steps)
      local dead = {
        kind = 'imp',
        x = 4.49,
        z = 7,
        hp = 0,
        maxHp = 50,
        deathTime = 0,
        fallY = 0,
        fallVY = 0,
        pushX = 4,
        pushZ = 0,
      }
      local cg = { world = w, enemies = { dead } }
      for _ = 1, steps do
        Body.fall(cg, dead, 1 / 120 / steps)
      end
      return dead
    end
    c1, c10 = slidingCorpse(1), slidingCorpse(10)
    check(
      'a grounded corpse starts falling in the same tick it leaves support',
      c1.fallVY < 0 and c1.fallY < 1
    )
    check(
      'ground-to-air corpse drag and gravity do not depend on slicing the tick',
      near(c1.x, c10.x)
        and near(c1.fallY, c10.fallY)
        and near(c1.fallVY, c10.fallVY)
        and near(c1.pushX, c10.pushX)
    )
    g = fresh()
    w = g.world
    for z = 2, 11 do
      for x = 2, 4 do
        w.elevations[z][x] = 4
      end
    end
    local high, low = g:spawn('imp', 4.3, 7), g:spawn('imp', 4.6, 7)
    high.pushX, high.pushZ = 9, 0
    check(
      'momentum cannot jump between vertically disjoint bodies',
      not Rules.collide(g, high, low) and low.pushX == 0
    )
    local hx, lx = high.x, low.x
    require('src.enemies.ai').separate(g, 1 / 120)
    check(
      'crowd separation also respects the coarse vertical body interval',
      high.x == hx and low.x == lx
    )
  end)
  Presentation.hooks['motion.landing'] = oldLanding
  Maps:unregister(definition.id)
  assert(ok, reason)
  return lines
end
return Test
