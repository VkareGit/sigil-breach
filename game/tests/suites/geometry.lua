local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, renderer)
  local B = require('src.combat.ballistics')
  local Projectiles = require('src.combat.projectiles')
  local Layout = require('src.ui.layout')
  local T = require('src.content.tuning')
  local Damage = require('src.combat.damage')
  local Weapons = require('src.content.weapons')
  local lines = {}
  local check = Fixtures.checker(lines, 'v08 ', '')
  local near = Fixtures.within(1e-7)
  local function dot(a, b)
    return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
  end
  local function fresh()
    local g = G.new('floor')
    g.ephemeral = true
    g:start()
    g.player.yaw = math.pi
    g.player.x = 16
    g.player.z = 27
    g.player.armor = 0
    g.enemies = {}
    g.pickups = {}
    g.bullets = {}
    g.view.particles = {}
    return g
  end
  -- Sample the complete pellet pattern in a local orthonormal aim plane, including
  -- steep pitch. A world-yaw offset would incorrectly narrow the cone near zenith.
  for _, pitch in ipairs({ -1.4, -0.8, 0, 0.8, 1.4 }) do
    local yaw = 0.73
    local forward = { B.direction(yaw, pitch) }
    local right = { math.cos(yaw), 0, -math.sin(yaw) }
    local up =
      { -math.sin(yaw) * math.sin(pitch), math.cos(pitch), -math.cos(yaw) * math.sin(pitch) }
    local unit, cone, centred = true, true, true
    local sumX, sumY = 0, 0
    for i = 1, 20 do
      local h, v = B.pellet(i, 2, 20)
      local d = { B.spreadDirection(yaw, pitch, h, v) }
      local depth = dot(d, forward)
      unit = unit and near(dot(d, d), 1)
      cone = cone
        and near(dot(d, right) / depth, math.tan(h))
        and near(dot(d, up) / depth, math.tan(v))
      sumX = sumX + dot(d, right) / depth
      sumY = sumY + dot(d, up) / depth
    end
    centred = near(sumX, 0) and near(sumY, 0)
    check('pellet directions remain unit length at pitch ' .. pitch, unit)
    check('pellet cone retains both angular axes at pitch ' .. pitch, cone and centred)
  end
  local grows = true
  for _, count in ipairs({ 10, 20 }) do
    for i = 1, count do
      local h, v = B.pellet(i, 1, count)
      local d = { B.spreadDirection(0.6, 0.9, h, v) }
      local f = { B.direction(0.6, 0.9) }
      local depth = dot(d, f)
      local r = { math.cos(0.6), 0, -math.sin(0.6) }
      local u = { -math.sin(0.6) * math.sin(0.9), math.cos(0.9), -math.cos(0.6) * math.sin(0.9) }
      local x3, y3 = dot(d, r) * 3 / depth, dot(d, u) * 3 / depth
      local x9, y9 = dot(d, r) * 9 / depth, dot(d, u) * 9 / depth
      grows = grows and near(x9, x3 * 3) and near(y9, y3 * 3)
    end
  end
  check('actual ten- and twenty-pellet footprints triple from 3 to 9 metres', grows)
  local axis = { B.spreadDirection(-1.2, 0.9, 0, 0) }
  local straight = { B.direction(-1.2, 0.9) }
  check(
    'zero-spread shot follows the exact reticle direction',
    near(axis[1], straight[1]) and near(axis[2], straight[2]) and near(axis[3], straight[3])
  )
  local g = fresh()
  local back = g:spawn('imp', 16, 22)
  local front = g:spawn('imp', 16, 24)
  local target, distance = B.trace(g, math.pi, 0, 24)
  check(
    'nearest animated body wins when enemy storage order is reversed',
    target == front and near(distance, 3)
  )
  front.hp = 0
  front.deathTime = require('src.content.enemies').defaults.corpse.settle + 1
  target = B.trace(g, math.pi, 0, 24)
  check('settled dead bodies do not block a later shot', target == back)
  g = fresh()
  g.player.x = 13
  g.player.z = 25
  local hidden = g:spawn('imp', 11, 25)
  local _, d, _, _, _, kind = B.trace(g, -math.pi / 2, 0, 24)
  check(
    'solid pillar stops a shot before a hidden body',
    kind == 'wall' and near(d, 1 - B.pillarRadius) and hidden.hp == hidden.maxHp
  )
  g = fresh()
  g:spawn('imp', 16, 24)
  local _, _, _, y, _, floorKind = B.trace(g, math.pi, -0.9, 24)
  check(
    'downward ray stops on the floor before reaching the enemy',
    floorKind == 'floor' and near(y, 0.025)
  )
  local cap = B.cylinderShape({ x = 16, z = 27 }, 16, 4, 27, 0, -1, 0, 24, 0.43, 0.08, 2.35)
  check('vertical ray intersects the top cap of a demon', near(cap, 1.65))
  check(
    'parallel ray outside a demon cylinder has no false hit',
    B.cylinderShape({ x = 16, z = 27 }, 17, 4, 27, 0, -1, 0, 24, 0.43, 0.08, 2.35) == nil
  )
  local range, _, rangeKind = B.world(g.world, 16, 1.38, 27, 0, 0, -1, 0.1)
  check(
    'an unobstructed ray preserves its maximum range',
    near(range, 0.1) and rangeKind == 'range'
  )
  -- Each actual ray uses its own travel distance; total report must agree with
  -- the public armor/falloff formula rather than a post-volley distance shortcut.
  g = fresh()
  local armored = g:spawn('armored', 16, 21)
  armored.hp = 1000
  armored.resistances = { physical = 0.2 }
  g:shoot()
  local expected, absorbed = 0, 0
  for _, ray in ipairs(g.view.shotReport.rays) do
    if ray.target == armored.id then
      local dealt, blocked = Damage.surface(
        Weapons.attack(g, 1),
        armored,
        ray.distance,
        { zone = ray.part, material = ray.material }
      )
      expected = expected + dealt
      absorbed = absorbed + blocked
    end
  end
  check(
    'volley damage sums per-ray distance, armor and resistance',
    g.view.shotReport.pelletsHit > 0
      and near(1000 - armored.hp, expected)
      and near(g.view.shotReport.damage, expected)
  )
  check(
    'armor feedback uses the same per-ray absorbed damage',
    near(g.view.shotReport.blocked, absorbed) and absorbed > 0
  )
  g = fresh()
  g.player.x = 12.51
  g.player.z = 25
  g.player.yaw = -math.pi / 2
  g:shoot()
  local clipped = true
  for _, trace in ipairs(g.view.traces) do
    clipped = clipped and trace.x1 > trace.x2 and trace.x1 < g.player.x
  end
  check(
    'near-wall tracers start before their hit instead of beyond the wall',
    clipped and #g.view.traces > 0
  )
  -- Motion preference affects presentation only, including after recoil has begun.
  local reports = {}
  for i, motion in ipairs({ false, true }) do
    g = fresh()
    g.view.motion = motion
    g.player.pitch = 0.32
    g.player.jump = 0.6
    g.player.crouch = 0.3
    g.view.recoil = 0.8
    g.view.shake = 0.7
    g.view.land = 0.5
    g.bob = 2
    g.roll = 0.4
    g.player.arsenal.exorcist.reserve = 0
    g:shoot()
    reports[i] = g.view.shotReport.rays
  end
  local identical = true
  for i, a in ipairs(reports[1]) do
    local b = reports[2][i]
    for _, key in ipairs({ 'x', 'y', 'z', 'distance', 'dx', 'dy', 'dz' }) do
      identical = identical and near(a[key], b[key])
    end
  end
  check('motion setting and cosmetic recoil cannot change shot direction or damage path', identical)
  local ox, oy, oz = B.origin(g)
  check(
    'shot origin includes jump and crouch but excludes landing shake',
    near(ox, 16) and near(oz, 27) and near(oy, 1.68)
  )
  local viewports = { { 960, 540 }, { 1280, 720 }, { 1024, 768 }, { 1720, 720 }, { 1920, 1080 } }
  for index, size in ipairs(viewports) do
    g = fresh()
    g.player.yaw = 0.73
    g.player.pitch = (index - 3) * 0.23
    g.player.jump = 0.2 * index
    g.player.crouch = 0.07 * index
    g.view.recoil = 0.7
    g.view.land = 0.8
    g.view.shake = 0.5
    g.view.bank = 0.4
    g.view.fovKick = 4
    g.view.motion = index % 2 == 0
    renderer:draw(g, size[1], size[2])
    ox, oy, oz = B.origin(g)
    local dx, dy, dz = B.direction(g.player.yaw, g.player.pitch)
    local px, py = renderer:project(ox + dx * 8, oy + dy * 8, oz + dz * 8)
    local vx, vy, vw, vh = Layout.scene(g, size[1], size[2])
    local scale, xoff, yoff = Layout.viewport(size[1], size[2])
    local aimed = px
      and near(vx + px / renderer.w * vw, xoff + Layout.aimX * scale, 1e-5)
      and near(vy + py / renderer.h * vh, yoff + Layout.aimY * scale, 1e-5)
    check('ray projects into the GUI reticle at ' .. size[1] .. 'x' .. size[2], aimed)
    check(
      'world ends exactly where the status bar begins at ' .. size[1] .. 'x' .. size[2],
      near(vy + vh, yoff + Layout.barTop * scale) and near(renderer.camera[2], oy)
    )
  end
  g = fresh()
  g.state = 'shop'
  local x, y, w, h = Layout.scene(g, 1024, 768)
  check(
    'shop backdrop uses the complete viewport without an in-game status bar',
    x == 0 and y == 0 and w == 1024 and h == 768
  )
  -- Continuous projectile collision must agree at both 30 Hz and 120 Hz, even
  -- when an entire body or wall lies between the sampled endpoints.
  local function bullet(x, y, z, vx, vy, vz, life, big)
    return {
      x = x,
      y = y,
      z = z,
      vx = vx,
      vy = vy,
      vz = vz,
      life = life or 2,
      big = big,
      color = {
        0.8,
        0.1,
        0.03,
      },
    }
  end
  g = fresh()
  g.bullets = { bullet(16, 1.2, 23, 0, 0, 1200) }
  Projectiles.update(g, 1 / 30)
  check(
    'fast projectile cannot tunnel through a player in one tick',
    g.player.hp == 86 and #g.bullets == 0 and near(g.view.particles[1].z, 26.66)
  )
  g = fresh()
  g.player.x = 11
  g.player.z = 25
  g.bullets = { bullet(13, 1.2, 25, -1200, 0, 0) }
  Projectiles.update(g, 1 / 30)
  check(
    'pillar collision wins over the player behind it',
    g.player.hp == 100
      and #g.bullets == 0
      and near(
        g.view.particles[1].x,
        12 + B.pillarRadius + require('src.content.combat_defaults').attacks.boltRadius
      )
  )
  g = fresh()
  g.player.x = 13
  g.player.z = 25
  g.bullets = { bullet(15, 1.2, 25, -1200, 0, 0) }
  Projectiles.update(g, 1 / 30)
  check(
    'player collision wins when it lies before the next pillar',
    g.player.hp == 86 and near(g.view.particles[1].x, 13.34)
  )
  g = fresh()
  g.bullets = { bullet(16, 0.2, 25, 0, -200, 0) }
  Projectiles.update(g, 1 / 30)
  check(
    'descending projectile terminates when its sphere touches the floor',
    g.player.hp == 100
      and #g.bullets == 0
      and near(
        g.view.particles[1].y,
        T.floorSurface + require('src.content.combat_defaults').attacks.boltRadius
      )
  )
  g = fresh()
  g.player.x = 16
  g.player.z = 27
  g.bullets = { bullet(16, 4, 27, 0, -200, 0) }
  Projectiles.update(g, 1 / 30)
  check(
    'vertical projectile hits the player cap before the floor',
    -- 0.24: one knight volume for melee and projectiles: height + own radius.
    g.player.hp == 86
      and near(
        g.view.particles[1].y,
        require('src.content.characters').standard().body.height + 0.12
      )
  )
  g = fresh()
  g.player.x = 17
  g.bullets = { bullet(16, 1.2, 27, 0, 0, 0) }
  Projectiles.update(g, 0.02, { x = 15, z = 27, jump = 0, crouch = 0 })
  check(
    'relative sweep catches a player crossing a stationary projectile',
    g.player.hp == 86 and #g.bullets == 0
  )
  g = fresh()
  g.player.jump = 2
  g.bullets = { bullet(16, 1.2, 23, 0, 0, 200) }
  Projectiles.update(g, 0.025)
  check('jumping above a low projectile avoids damage', g.player.hp == 100 and #g.bullets == 1)
  g = fresh()
  g.player.crouch = 0.65
  g.bullets = { bullet(16, 1.6, 23, 0, 0, 200) }
  Projectiles.update(g, 0.025)
  check(
    'crouched player clears a projectile above the lowered head',
    g.player.hp == 100 and #g.bullets == 1
  )
  g = fresh()
  g.bullets = { bullet(16, 1.6, 23, 0, 0, 200) }
  Projectiles.update(g, 1 / 30)
  check('the same projectile strikes a standing player', g.player.hp == 86 and #g.bullets == 0)
  g = fresh()
  g.player.invuln = 0.2
  g.bullets = { bullet(16, 1.2, 23, 0, 0, 200) }
  Projectiles.update(g, 1 / 30)
  check(
    'dash invulnerability consumes the impacting projectile without damage',
    g.player.hp == 100
      and #g.bullets == 0
      and require('src.session.stats').total(g, 'damageTaken') == 0
  )
  g = fresh()
  g.bullets = { bullet(16, 1.2, 23, 0, 0, 200, 0.005) }
  Projectiles.update(g, 1 / 30)
  check(
    'short-lived projectile travels only its remaining lifetime',
    g.player.hp == 100 and #g.bullets == 0 and near(g.view.particles[1].z, 24)
  )
  g = fresh()
  local expired = bullet(16, 1.2, 27, 0, 0, 200)
  expired.life = 0
  g.bullets = { expired }
  Projectiles.update(g, 0.02)
  check(
    'already expired projectile cannot damage an overlapping player',
    g.player.hp == 100 and #g.bullets == 0
  )
  g = fresh()
  g.bullets = { bullet(16, 1.2, 23, 0, 0, 200) }
  Projectiles.update(g, 0)
  check(
    'zero-duration update leaves the projectile unchanged',
    #g.bullets == 1 and g.bullets[1].z == 23 and g.bullets[1].life == 2
  )
  g = fresh()
  g.bullets = { bullet(16.4, 1.2, 23, 0, 0, 200, 2, true) }
  Projectiles.update(g, 1 / 30)
  check(
    'large projectile uses its wider hit radius and damage',
    g.player.hp == 78 and #g.bullets == 0
  )
  g = fresh()
  g.bullets = { bullet(16.4, 1.2, 23, 0, 0, 200) }
  Projectiles.update(g, 0.025)
  check(
    'normal projectile misses outside the smaller collision radius',
    g.player.hp == 100 and #g.bullets == 1
  )
  local impacts = {}
  for i, step in ipairs({ 1 / 30, 1 / 120 }) do
    g = fresh()
    g.bullets = { bullet(16, 1.2, 23, 0, 0, 200) }
    for _ = 1, 4 do
      Projectiles.update(g, step)
    end
    impacts[i] = { hp = g.player.hp, z = g.view.particles[1].z, count = #g.bullets }
  end
  check(
    '30 Hz and 120 Hz projectile updates agree on hit point and damage',
    impacts[1].hp == impacts[2].hp
      and near(impacts[1].z, impacts[2].z)
      and impacts[1].count == 0
      and impacts[2].count == 0
  )
  g = fresh()
  g.bullets = { bullet(16, 1.2, 23, 0, 0, 200), bullet(16, 1.2, 24, 0, 0, 200) }
  Projectiles.update(g, 1 / 30)
  check(
    'multiple impacts respect the existing damage grace interval',
    g.player.hp == 86
      and require('src.session.stats').total(g, 'damageTaken') == 14
      and #g.bullets == 0
  )
  g = fresh()
  g.player.hp = 1
  g.bullets = { bullet(16, 1.2, 23, 0, 0, 200), bullet(16, 1.2, 24, 0, 0, 200) }
  local safe = pcall(Projectiles.update, g, 1 / 30)
  check(
    'lethal projectile can clear the bullet array without invalid removal',
    safe and g.state == 'dead' and g.player.hp == 0 and #g.bullets == 0
  )
  -- Other v0.8 suites return their actual PASS lines, so the published total is
  -- based on executed checks rather than a manually maintained release number.
  for _, module in ipairs({
    'tests.cases.art',
    'tests.cases.bitmap_ui',
    'tests.cases.test_field',
  }) do
    local more = require(module).run(G, renderer)
    assert(type(more) == 'table', module .. ' must return PASS lines')
    for _, line in ipairs(more) do
      assert(line:sub(1, 5) == 'PASS ', module .. ' returned a non-passing result')
      lines[#lines + 1] = line
    end
  end
  love.mouse.setRelativeMode(false)
  return lines
end
return Tests
