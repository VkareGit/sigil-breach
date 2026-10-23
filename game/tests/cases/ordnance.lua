local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(check)
  local X = require('src.combat.explosives')
  local P = require('src.combat.projectiles')
  local near = Fixtures.within(1e-7)
  local function world()
    local w = { size = 24, map = {} }
    for z = 1, 24 do
      w.map[z] = {}
      for x = 1, 24 do
        w.map[z][x] = (z == 1 or z == 24 or x == 1 or x == 24) and 1 or 0
      end
    end
    return w
  end
  local function charge(w, values)
    local b = { x = 10, y = 2, z = 10, vx = 3, vy = 2, vz = 1, fuse = 3, spin = 0 }
    for k, v in pairs(values or {}) do
      b[k] = v
    end
    return { world = w or world(), charges = { b }, state = 'playing' }, b
  end
  local function evolve(g, seconds, hz)
    for _ = 1, math.floor(seconds * hz + 0.5) do
      X.update(g, 1 / hz)
    end
    return g.charges[1]
  end
  local g, b = charge()
  X.update(g, 0.2)
  -- 0.20: charges fall under the one world gravity (tuning.gravity).
  local G = require('src.content.tuning').gravity
  check(
    'ordnance: free flight follows exact constant-acceleration position and velocity',
    near(b.x, 10.6)
      and near(b.y, 2 + 2 * 0.2 - 0.5 * G * 0.04)
      and near(b.z, 10.2)
      and near(b.vy, 2 - G * 0.2)
  )
  for _, hz in ipairs({ 30, 60, 120, 240 }) do
    local coarse, cb = charge(nil, { vx = 6, vy = -2, y = 0.8 })
    local fine, fb = charge(nil, { vx = 6, vy = -2, y = 0.8 })
    X.update(coarse, 0.8)
    evolve(fine, 0.8, hz)
    check(
      'ordnance: floor rebounds and settling agree at ' .. hz .. ' Hz',
      near(cb.x, fb.x, 2e-6)
        and near(cb.y, fb.y, 2e-6)
        and near(cb.vx, fb.vx, 2e-6)
        and near(cb.vy, fb.vy, 2e-6)
    )
  end
  local w = world()
  for z = 2, 23 do
    w.map[z][13] = 1
  end
  g, b = charge(w, { x = 10, y = 2, vx = 12, vy = 0, vz = 0 })
  X.update(g, 0.4)
  local expectedX = 12.5 - 1e-5 - 12 * 0.252 * (0.4 - 2.5 / 12)
  check(
    'ordnance: wall impact consumes the remaining tick after restitution',
    near(b.x, expectedX) and near(b.vx, -3.024)
  )
  local fine, fb = charge(w, { x = 10, y = 2, vx = 12, vy = 0, vz = 0 })
  evolve(fine, 0.4, 120)
  check(
    'ordnance: wall plus gravity has the same trajectory in one tick and 48 ticks',
    near(b.x, fb.x) and near(b.y, fb.y) and near(b.vy, fb.vy)
  )
  g, b = charge(nil, { x = 10, y = 6, z = 10, vx = 0, vy = -3, vz = 0 })
  g.world.map[10][10] = 2
  X.update(g, 0.3)
  check(
    'ordnance: descending charge hits the column top rather than falling inside it',
    b.y >= 4.8 and b.vy > 0
  )
  for _, z in ipairs({ 10.46, 10.48 }) do
    local pillar = world()
    pillar.map[10][10] = 2
    local free, freeBody = charge(nil, { x = 9, z = z, vx = 10, vy = 0, vz = 0 })
    g, b = charge(pillar, { x = 9, z = z, vx = 10, vy = 0, vz = 0 })
    X.update(free, 0.2)
    X.update(g, 0.2)
    check(
      'ordnance: tangent and square-corner paths clear the round pillar ' .. z,
      near(b.x, freeBody.x) and near(b.y, freeBody.y) and near(b.vx, freeBody.vx)
    )
  end
  w = world()
  w.map[10][10] = 2
  g, b = charge(w, { x = 9, z = 10.3, vx = 10, vy = 0, vz = 0 })
  local contactX = 10 - math.sqrt(0.46 ^ 2 - 0.3 ^ 2)
  local normalX, normalZ = (contactX - 10) / 0.46, 0.3 / 0.46
  local coefficients = require('src.content.tuning').explosives
  local reflectedX = (10 - coefficients.bounce * 10 * normalX ^ 2) * coefficients.keep
  local reflectedZ = -coefficients.bounce * 10 * normalX * normalZ * coefficients.keep
  X.update(g, 0.1)
  check(
    'ordnance: glancing pillar strike reflects about its radial normal',
    near(b.vx, reflectedX) and near(b.vz, reflectedZ) and b.z > 10.3
  )
  fine, fb = charge(w, { x = 9, z = 10.3, vx = 10, vy = 0, vz = 0 })
  evolve(fine, 0.1, 120)
  check(
    'ordnance: radial collision is independent of step subdivision',
    near(b.x, fb.x) and near(b.y, fb.y) and near(b.z, fb.z)
  )
  g, b = charge(w, { x = 10.48, z = 10.48, y = 6, vx = 0, vy = -3, vz = 0 })
  X.update(g, 0.3)
  check(
    'ordnance: a fall outside the circular cap does not land on its square bounds',
    b.y < 4.8 and b.vy < 0
  )
  g, b = charge(nil, { x = 10, y = 2, z = 10, vx = 10, vy = 0, vz = 10 })
  g.world.map[11][11] = 1
  X.update(g, 0.1)
  check(
    'ordnance: diagonal column corner reflects both horizontal axes symmetrically',
    b.x < 10.5 and near(b.x, b.z) and b.vx < 0 and near(b.vx, b.vz)
  )
  g, b = charge(nil, { x = 10, y = 0.02501, z = 10, vx = 3, vy = 0, vz = 0, grounded = true })
  X.update(g, 0.5)
  check(
    'ordnance: grounded resistance is analytic and cannot add kinetic energy',
    near(b.x, 10 + 3 * (1 - math.exp(-3)) / 6)
      and near(b.vx, 3 * math.exp(-3))
      and near(b.y, 0.02501)
  )
  g, b = charge(nil, { y = -0.02, vy = -1 })
  X.update(g, 0.05)
  check('ordnance: a slightly submerged charge is recovered above the floor', b.y >= 0.025)
  w = world()
  w.map[10][10] = 2
  g, b = charge(w, { y = 4.80001, vx = 0, vy = 0, vz = 0, grounded = true })
  X.update(g, 0.5)
  check(
    'ordnance: a resting charge remains supported on a column top',
    b.grounded and near(b.y, 4.80001) and b.vy == 0
  )
  g, b = charge(w, { y = 4.80001, vx = 6, vy = 0, vz = 0, grounded = true })
  X.update(g, 0.5)
  fine, fb = charge(w, { y = 4.80001, vx = 6, vy = 0, vz = 0, grounded = true })
  evolve(fine, 0.5, 120)
  check(
    'ordnance: rolling over a ledge restores gravity at the edge instant',
    not b.grounded
      and b.y < 4.8
      and b.x > 10.5
      and near(b.y, fb.y)
      and near(b.x, fb.x)
      and near(b.vy, fb.vy)
  )
  local leaveAt = -math.log(1 - 6 * 0.46 / 6) / 6
  local fallFor = 0.5 - leaveAt
  check(
    'ordnance: circular support ends at radius 0.46, not at the square cell edge',
    near(b.y, 4.80001 - 0.5 * G * fallFor * fallFor) and near(b.vy, -G * fallFor)
  )
  local explode = X.explode
  local count, position = 0, nil
  X.explode = function(_, item)
    count = count + 1
    position = { x = item.x, y = item.y, z = item.z }
  end
  local ok, err = pcall(function()
    g, b = charge(nil, { fuse = 0.2 })
    X.update(g, 1)
    X.update(g, 1)
    check(
      'ordnance: fuse expiry stops motion exactly at detonation and occurs once',
      #g.charges == 0
        and count == 1
        and near(position.x, 10.6)
        and near(position.y, 2 + 2 * 0.2 - 0.5 * G * 0.04)
    )
  end)
  X.explode = explode
  if not ok then
    error(err)
  end
  for _, dt in ipairs({ 0, -1, math.huge, 0 / 0 }) do
    g, b = charge()
    X.update(g, dt)
    check(
      'ordnance: invalid dt ' .. tostring(dt) .. ' cannot mutate a charge',
      b.x == 10 and b.fuse == 3 and b.vy == 2
    )
  end
  local function projectile(z, y, speed, life, big)
    return {
      x = 10,
      y = y or 1,
      z = z or 7,
      vx = 0,
      vy = 0,
      vz = speed or 4,
      life = life or 2,
      big = big,
    }
  end
  local function projectileGame()
    local game = {
      world = world(),
      player = { x = 10, z = 10, jump = 0, crouch = 0, hp = 100 },
      bullets = {},
      state = 'playing',
      impacts = {},
    }
    function game:damagePlayer(damage)
      if not self.hit then
        self.player.hp = self.player.hp - damage
        self.hit = true
      end
    end
    -- 0.24: where a projectile ends is announced (ProjectileBurst).
    game.bus = require('src.session.event_catalog').newBus()
    game.bus:on('present', 'ProjectileBurst', function(e)
      local b = e.bullet
      game.impacts[#game.impacts + 1] = { x = b.x, y = b.y, z = b.z }
    end)
    return game
  end
  g = projectileGame()
  g.player.crouch = 0.65
  g.bullets = { projectile(7, 1.7, 4) }
  P.update(g, 1, { x = 10, z = 10, jump = 0, crouch = 0 })
  check(
    'projectiles: ducking before the contact instant clears the actual lowered head',
    g.player.hp == 100 and #g.bullets == 1
  )
  g = projectileGame()
  g.bullets = { projectile(9.3, 1.8, 4) }
  P.update(g, 1, { x = 10, z = 10, jump = 0, crouch = 0.65 })
  check(
    'projectiles: standing up cannot retroactively be hit at the final standing height',
    g.player.hp == 100
  )
  g = projectileGame()
  g.bullets = { projectile(7, 1.7, 4) }
  P.update(g, 1, { x = 10, z = 10, jump = 0, crouch = 0.65 })
  check('projectiles: standing into a late projectile correctly produces a hit', g.player.hp == 86)
  g = projectileGame()
  g.player.crouch = 0.65
  g.bullets = { projectile(9, 1.8, 5, 0.2) }
  P.update(g, 1, { x = 10, z = 10, jump = 0, crouch = 0 })
  check(
    'projectiles: short lifetime interpolates only the corresponding fraction of crouch motion',
    g.player.hp == 86
  )
  g = projectileGame()
  g.bullets = { projectile(10, 1, 4) }
  P.update(g, 0.1)
  check(
    'projectiles: initial overlap reports exact time zero instead of a fictitious forward step',
    g.player.hp == 86 and near(g.impacts[1].z, 10)
  )
  for _, reverse in ipairs({ false, true }) do
    g = projectileGame()
    local early = projectile(9, 1, 4)
    local late = projectile(7, 1, 4, 2, true)
    g.bullets = reverse and { late, early } or { early, late }
    P.update(g, 1)
    check(
      'projectiles: first real impact wins damage grace independently of array order '
        .. tostring(reverse),
      g.player.hp == 86 and #g.bullets == 0 and #g.impacts == 2 and g.impacts[1].z > g.impacts[2].z
    )
  end
  for _, dt in ipairs({ 0, -1, math.huge, 0 / 0 }) do
    g = projectileGame()
    local bullet = projectile()
    g.bullets = { bullet }
    P.update(g, dt)
    check(
      'projectiles: invalid dt ' .. tostring(dt) .. ' leaves finite projectile state unchanged',
      bullet.z == 7 and bullet.life == 2 and #g.bullets == 1
    )
  end
  g = projectileGame()
  g.bullets = { projectile() }
  g.bullets[1].vx = 0 / 0
  P.update(g, 0.1)
  check(
    'projectiles: malformed velocity is removed without poisoning player or effects',
    #g.bullets == 0 and g.player.hp == 100 and #g.impacts == 0
  )
  g = projectileGame()
  g.world.map[7][10] = 1
  g.bullets = { projectile(7, 1, 0) }
  P.update(g, 0.1)
  check(
    'projectiles: stationary projectile inside a solid tile terminates at its origin',
    #g.bullets == 0 and #g.impacts == 1 and near(g.impacts[1].z, 7) and g.player.hp == 100
  )
end
return Tests
