local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, check)
  local C = require('src.physics.collision')
  local K = require('src.physics.kinematics')
  local T = require('src.content.tuning')
  local near = Fixtures.within(1e-7)
  local w = { size = 15, map = {} }
  for z = 1, 15 do
    w.map[z] = {}
    for x = 1, 15 do
      w.map[z][x] = (x == 1 or z == 1 or x == 15 or z == 15) and 1 or 0
    end
  end
  w.map[8][8] = 1
  check(
    'rounded pillar clearance is a circle rather than an invisible square',
    not C.solid(w, 7.3, 7.3, 0.25) and C.solid(w, 7.35, 7.35, 0.25)
  )
  check('large bodies still detect a whole enclosed solid tile', C.solid(w, 8, 8, 1.2))
  local p = { x = 4, z = 8 }
  local vx, vz, hit = C.move(w, p, 8, 0, 0.22)
  check(
    'one fast movement cannot tunnel through a complete pillar',
    hit and near(p.x, 7.28, 1e-6) and near(vx, 0) and near(vz, 0)
  )
  p = { x = 12, z = 8 }
  C.move(w, p, -8, 0, 0.22)
  check('reverse sweep reaches the same geometric contact distance', near(p.x, 8.72, 1e-6))
  p = { x = 7.4, z = 8 }
  C.move(w, p, 3, 0, 0.22)
  check(
    'a shallow initial overlap is recovered on its near side before movement',
    near(p.x, 7.28, 1e-6) and not C.solid(w, p.x, p.z, 0.22)
  )
  for z = 2, 14 do
    w.map[z][8] = 1
  end
  p = { x = 7, z = 5 }
  vx, vz, hit = C.move(w, p, 3, 3, 0.22)
  check(
    'wall contact preserves all tangent travel and clips only inward velocity',
    hit and near(p.x, 7.28, 1e-6) and near(p.z, 8) and near(vx, 0) and near(vz, 3)
  )
  C.move(w, p, 0, 2, 0.22)
  check('sliding across adjoining tile seams does not snag', near(p.z, 10))
  C.move(w, p, -1, 0, 0.22)
  check('moving away from a wall releases contact immediately', p.x < 6.3)
  p = { x = 7, z = 5, vx = 6, vz = 9 }
  C.move(w, p, 1, 1, 0.22, p)
  check(
    'contact projects final velocity independently of average frame displacement',
    near(p.vx, 0) and near(p.vz, 9)
  )
  check(
    'line of sight checks the destination instead of skipping its last sample',
    not C.visible(w, 7.4, 8, 7.51, 8)
  )
  check(
    'line of sight is symmetric across the same solid boundary',
    C.visible(w, 7.1, 5, 7.1, 11) == C.visible(w, 7.1, 11, 7.1, 5)
      and not C.visible(w, 4, 8, 12, 8)
      and not C.visible(w, 12, 8, 4, 8)
  )
  for x = 2, 14 do
    w.map[8][x] = 1
  end
  p = { x = 7.15, z = 7.2, vx = 0.9, vz = 0.6 }
  C.move(w, p, 0.9, 0.6, 0.2, p)
  check(
    'simultaneous corner planes stop without creating backwards motion',
    near(p.x, 7.3, 1e-6) and near(p.z, 7.3, 1e-6) and near(p.vx, 0) and near(p.vz, 0)
  )
  for x = 2, 14 do
    w.map[8][x] = 0
  end
  -- Deterministic geometric stress: rapid movement and many radii, no RNG pollution.
  for z = 2, 14 do
    w.map[z][8] = 0
  end
  w.map[8][8] = 1
  local seed = 12345
  local function rand()
    seed = (seed * 16807) % 2147483647
    return seed / 2147483647
  end
  local ok = true
  local tested = 0
  for _ = 1, 2500 do
    local radius = 0.1 + rand() * 0.65
    local x, z = 2 + rand() * 11, 2 + rand() * 11
    if not C.solid(w, x, z, radius) then
      p = { x = x, z = z }
      C.move(w, p, (rand() - 0.5) * 16, (rand() - 0.5) * 16, radius)
      ok = ok and not C.solid(w, p.x, p.z, radius - 1e-6)
      tested = tested + 1
    end
  end
  check(
    '2500 seeded continuous movement trials leave no body inside geometry ('
      .. tested
      .. ' valid starts)',
    ok and tested > 2000
  )
  for _, damping in ipairs({ 12, 20, 30 }) do
    local x, v = K.spring(3, -7, 1, 100, damping, 0.6)
    local a, b = 3, -7
    for _ = 1, 72 do
      a, b = K.spring(a, b, 1, 100, damping, 1 / 120)
    end
    check('weapon spring is step-independent at damping ' .. damping, near(x, a) and near(v, b))
  end
  local apex = require('src.content.characters').standard().movement.jumpSpeed / T.gravity
  local h, v =
    K.vertical(0, require('src.content.characters').standard().movement.jumpSpeed, T.gravity, apex)
  check(
    'jump apex matches v squared over twice gravity',
    near(
      h,
      require('src.content.characters').standard().movement.jumpSpeed
        * require('src.content.characters').standard().movement.jumpSpeed
        / (2 * T.gravity)
    ) and near(v, 0)
  )
  local a, b = 0, require('src.content.characters').standard().movement.jumpSpeed
  for _ = 1, 30 do
    a, b = K.vertical(a, b, T.gravity, 1 / 120)
  end
  h, v =
    K.vertical(0, require('src.content.characters').standard().movement.jumpSpeed, T.gravity, 0.25)
  check('free jump parabola is identical under subdivided time', near(h, a) and near(v, b))
  local impact
  h, v, impact = K.vertical(0.1, -8, T.gravity, 0.2)
  check(
    'landing computes impact speed at the floor rather than after it',
    h == 0 and v == 0 and near(impact, -math.sqrt(64 + 2 * T.gravity * 0.1))
  )
  local function fresh()
    local g = G.new()
    g.ephemeral = true
    g.state = 'playing'
    g.enemies = {}
    g.pickups = {}
    g.player.armor = 0
    return g
  end
  local g = fresh()
  local other = fresh()
  g:update(0.1, { forward = 1, dash = true })
  for i = 1, 12 do
    other:update(1 / 120, { forward = 1, dash = i == 1 })
  end
  check(
    'coarse callers keep all elapsed time and the same movement as 120Hz',
    near(g.elapsed, 0.1)
      and near(g.player.x, other.player.x)
      and near(g.player.z, other.player.z)
      and near(g.player.dashTimer, other.player.dashTimer)
  )
  g = fresh()
  local start = g.player.z
  g:dash(0, -1)
  for _ = 1, 18 do
    g:update(1 / 120, {})
  end
  g:update(0.005, {})
  check(
    'dash travels full configured duration including its fractional final step',
    near(
      start - g.player.z,
      require('src.content.characters').standard().movement.dashSpeed
        * require('src.content.characters').standard().movement.dashTime,
      1e-6
    )
  )
  local guard = require('src.content.characters').standard().body.rollIframes
  g = fresh()
  g.player.invuln = guard + 0.1
  g:dash(0, -1)
  check('dashing never shortens existing damage immunity', g.player.invuln == guard + 0.1)
  g = fresh()
  g.player.invuln = guard * 0.5
  g:dash(0, -1)
  check('a dodge raises a shorter immunity to its own', g.player.invuln == guard)
  g = fresh()
  g.player.hp = 1
  g.pickups = { { x = g.player.x, z = g.player.z, kind = 'health', amount = 25 } }
  g.bullets =
    { { x = g.player.x, y = 1, z = g.player.z - 0.5, vx = 0, vy = 0, vz = 120, life = 2 } }
  g:update(1 / 120, {})
  check(
    'a lethal hit cannot collect a health pickup later in the same tick',
    g.state == 'dead' and g.player.hp == 0 and #g.pickups == 1
  )
  g = fresh()
  g.state = 'paused'
  local breath = g.player.resources.stamina
  check(
    'paused direct dash cannot spend resources or grant invulnerability',
    not g:dash(1, 0) and g.player.resources.stamina == breath and g.player.invuln == 0
  )
end
return Tests
