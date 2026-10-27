local Fixtures = require('tests.support.fixtures')
local Cast = require('src.physics.cylinder_cast')
local Projectiles = require('src.combat.projectiles')
local Melee = require('src.combat.melee')
local Spawn = require('src.session.spawn')
local Pools = require('src.session.world')
local Ground = require('src.physics.ground')
local Tests = {}

function Tests.run(Game)
  local lines = {}
  local check = Fixtures.checker(lines, 'cylinder cast: ', 'cylinder cast: ')
  local near = Fixtures.within(2e-7)
  check('side TOI is analytical', near(Cast.sweep(-2, 0, 4, 0, -1, 0, 1, 0, 0.5, 0.2), 0.325))
  check('cap TOI is analytical', near(Cast.sweep(0, 0, 0, 0, -3, 2, -1, 2, 0.5, 0.2), 0.4))
  check('overlap begins at zero', Cast.sweep(0.6, 0, 0, 0, -1, 0, 1, 0, 0.5, 0.2) == 0)
  check(
    'stationary separated sphere misses',
    Cast.sweep(0.8, 0, 0, 0, -1, 0, 1, 0, 0.5, 0.2) == nil
  )
  check(
    'zero-radius ray retains exact cylinder entry',
    near(Cast.sweep(-2, 0, 4, 0, -1, 0, 1, 0, 0.5, 0), 0.375)
  )
  check('point above cap misses', Cast.sweep(-2, 0, 4, 0, -3, 0, -1, 0, 0.5, 0) == nil)
  check(
    'small nonzero motion is not treated as stationary',
    near(Cast.sweep(0.7000002, 0, -0.0000004, 0, -1, 0, 1, 0, 0.5, 0.2), 0.5)
  )
  check(
    'zero-radius body has a well-defined axial contact',
    near(Cast.sweep(0, 0, 0, 0, -3, 2, -1, 2, 0, 0.2), 0.4)
  )
  check(
    'rising cap reaches a stationary sphere',
    near(Cast.sweep(0, 0, 0, 0, -2, 0, -0.5, 0.5, 0.5, 0.2), 0.6)
  )
  local tangentRotations = true
  for i = 1, 100 do
    local angle = i * math.pi * 2 / 100
    local c, s = math.cos(angle), math.sin(angle)
    local t = Cast.sweep(-2 * c - 0.7 * s, -2 * s + 0.7 * c, 4 * c, 4 * s, -1, 0, 1, 0, 0.5, 0.2)
    tangentRotations = tangentRotations and near(t, 0.5, 1e-4)
  end
  check('rotating an exact side tangent preserves contact', tangentRotations)
  local rimRadius = 0.5 + math.sqrt(0.2 ^ 2 - 0.15 ^ 2)
  local expected = (2 - math.sqrt(rimRadius ^ 2 - 0.6 ^ 2)) / 4
  for _, top in ipairs({ true, false }) do
    local bottom, upper = top and -2.15 or 0.15, top and -0.15 or 2.15
    local name = top and 'upper' or 'lower'
    check(
      name .. ' rectangular corner is not contact',
      Cast.sweep(0.65, -2, 0, 4, bottom, 0, upper, 0, 0.5, 0.2) == nil
    )
    check(
      name .. ' rounded rim has the correct first TOI',
      near(Cast.sweep(0.6, -2, 0, 4, bottom, 0, upper, 0, 0.5, 0.2), expected)
    )
    check(
      name .. ' rim tangent is retained',
      near(Cast.sweep(rimRadius, -2, 0, 4, bottom, 0, upper, 0, 0.5, 0.2), 0.5, 1e-4)
    )
    check(
      name .. ' near tangent outside tolerance misses',
      Cast.sweep(rimRadius + 1e-5, -2, 0, 4, bottom, 0, upper, 0, 0.5, 0.2) == nil
    )
  end
  check(
    'contact exactly at the endpoint',
    near(
      Cast.sweep(0.6, -2, 0, 2 - math.sqrt(rimRadius ^ 2 - 0.6 ^ 2), -2.15, 0, -0.15, 0, 0.5, 0.2),
      1
    )
  )
  check(
    'slide already below a crossing does not use standing union',
    Cast.sweep(0, -3, 0, 6, -1.8, 0, 0, -0.43, 0.22, 0.12) == nil
  )
  check(
    'rising into a late projectile can be hit',
    Cast.sweep(0, -5, 0, 6, -1.8, 0, -0.43, 0.43, 0.22, 0.12) ~= nil
  )

  -- Same continuously changing body and sphere, evaluated as one interval
  -- and as many intervals: neither crouch nor translation may be unioned.
  local function segmented(steps, planeSpeed)
    local ox, oz, dx, dz, bottom, db, top, dt = 0.6, -2, 0, 4, -2.15, planeSpeed, -0.15, planeSpeed
    for i = 0, steps - 1 do
      local start = i / steps
      local t = Cast.sweep(
        ox + dx * start,
        oz + dz * start,
        dx / steps,
        dz / steps,
        bottom + db * start,
        db / steps,
        top + dt * start,
        dt / steps,
        0.5,
        0.2
      )
      if t then
        return (i + t) / steps
      end
    end
  end
  local whole = segmented(1, -0.03)
  for _, steps in ipairs({ 2, 12, 120 }) do
    check(
      'moving planes agree across ' .. steps .. ' intervals',
      near(whole, segmented(steps, -0.03))
    )
    check(
      'moving planes stay clear across ' .. steps .. ' intervals',
      segmented(steps, -0.1) == nil
    )
  end
  check(
    'fast narrow rim crossing is not skipped',
    near(
      Cast.sweep(0.6, -200, 0, 400, -2.15, 0, -0.15, 0, 0.5, 0.2),
      (200 - math.sqrt(rimRadius ^ 2 - 0.6 ^ 2)) / 400
    )
  )

  local function projectile(height, offset, steps, radius)
    local g = Fixtures.arena(Game)
    local p = g.player
    p.crouch, p.invuln, p.armor = 0.43, 0, 0
    Spawn.make(g, 'projectile', {
      x = 16 + offset,
      y = Ground.of(g.world, p) + height,
      z = 24,
      vx = 0,
      vy = 0,
      vz = 30,
      life = 3,
      radius = radius or 0.26,
      side = 'demons',
      packet = { base = 22, impact = 0, damageType = 'fire' },
    })
    for _ = 1, steps do
      Projectiles.update(g, 0.1 / steps, p)
    end
    return p.hp, #Pools.of(g, 'projectiles')
  end
  for _, steps in ipairs({ 1, 12 }) do
    local hp, remaining = projectile(1.62, 0.47, steps)
    check(
      'actual projectile clears upper corner at ' .. steps .. ' steps',
      hp == 100 and remaining == 1
    )
    hp, remaining = projectile(1.64, 0, steps)
    check(
      'actual projectile above the entire body misses at ' .. steps .. ' steps',
      hp == 100 and remaining == 1
    )
    hp, remaining = projectile(1.60, 0, steps)
    check(
      'above camera but touching head still hits at ' .. steps .. ' steps',
      hp == 78 and remaining == 0
    )
    hp, remaining = projectile(1.15, 0, steps)
    check('actual body hit remains at ' .. steps .. ' steps', hp == 78 and remaining == 0)
  end
  local g = Fixtures.arena(Game)
  g.player.crouch = 0.43
  check(
    'actual melee clears the rounded upper corner',
    not Melee.contact(g, 16.39, 24, 16.39, 27, 1.54, 0.18, g.player, g.player)
  )
  check(
    'actual melee still hits the body',
    Melee.contact(g, 16, 24, 16, 27, 1.15, 0.18, g.player, g.player)
  )
  return lines
end
return Tests
