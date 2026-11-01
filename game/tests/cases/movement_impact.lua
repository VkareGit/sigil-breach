local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, check)
  local I = require('src.feedback.movement_impact')
  local M = require('src.feedback.weapon_motion')
  local C = require('src.physics.collision')
  local T = require('src.content.tuning')
  local near = Fixtures.within(1e-7)
  local function world()
    local w = { size = 21, map = {} }
    for z = 1, 21 do
      w.map[z] = {}
      for x = 1, 21 do
        w.map[z][x] = (x == 1 or z == 1 or x == 21 or z == 21 or x == 12) and 1 or 0
      end
    end
    return w
  end
  local function fresh()
    local g = G.new()
    g.testing = true
    g.state = 'playing'
    g.enemies = {}
    g.pickups = {}
    g.world.map = world().map
    g.world.size = 21
    g.player.x, g.player.z, g.player.yaw, g.player.pitch = 8, 10, math.pi / 2, 0
    return g
  end
  local slow = I.measure(3, 0, 0, 0, 0, 0, 1, 0.1)
  local fast = I.measure(6, 0, 0, 0, 0, 0, 1, 0.1)
  check(
    'contact impulse doubles while dissipated energy quadruples with speed',
    near(fast.impulse / slow.impulse, 2) and near(fast.energyLost / slow.energyLost, 4)
  )
  local mass = I.measure(3, 0, 0, 0, 0, 0, 2, 0.1)
  check(
    'reference mass scales impulse, energy and average force linearly',
    near(mass.impulse, slow.impulse * 2)
      and near(mass.energyLost, slow.energyLost * 2)
      and near(mass.meanForce, slow.meanForce * 2)
  )
  local cushioned = I.measure(3, 0, 0, 0, 0, 0, 1, 0.2)
  check(
    'longer cushioning changes mean force without changing impulse or energy',
    near(cushioned.meanForce, slow.meanForce * 0.5)
      and cushioned.impulse == slow.impulse
      and cushioned.energyLost == slow.energyLost
  )
  local graze = I.measure(1, 0, 6, 0, 0, 6, 1, 0.1)
  check(
    'a wall graze loses only the blocked component, retaining tangent energy',
    near(graze.impulse, 1) and near(graze.energyLost, 0.5) and near(graze.energyAfter, 18)
  )
  local turn = I.measure(6, 0, 0, 0, 0, 6, 1, 0.1)
  check(
    'changing direction can transfer momentum without inventing energy dissipation',
    turn.impulse > 8 and turn.energyLost == 0 and turn.energyGained == 0
  )
  check(
    'invalid contact samples are rejected',
    not I.measure(nil, 0, 0, 0, 0, 0)
      and not I.measure(0 / 0, 0, 0, 0, 0, 0)
      and not I.measure(1, 0, 0, 0, 0, 0, 1, 0)
  )
  local p = { x = 11, z = 8, vx = 6, vz = 4 }
  local bx, bz = p.vx, p.vz
  C.move(world(), p, 1, 1, 0.22, p)
  local measured = I.measure(bx, 0, bz, p.vx, 0, p.vz, 1, 0.09)
  check(
    'measured real collision keeps tangent momentum and removes normal momentum',
    near(p.vx, 0) and near(p.vz, 4) and near(measured.impulse, 6) and near(measured.energyLost, 18)
  )
  local function wallRun(rate, motion)
    local g = fresh()
    g.view.motion = motion ~= false
    for _ = 1, rate do
      g:update(1 / rate, { forward = 1 })
    end
    return g
  end
  local g = wallRun(120)
  local event = g.view.lastWallImpact
  check(
    'ordinary running into a wall records one actual velocity projection',
    event and event.energyLost > 10 and g.view.movementImpactSerial == 1 and near(g.player.vx, 0)
  )
  local serial = g.view.movementImpactSerial
  for _ = 1, 240 do
    g:update(1 / 120, { forward = 1, dash = true })
  end
  check(
    'holding movement and repeatedly requesting dash against the same wall cannot spam impacts',
    g.view.movementImpactSerial == serial
  )
  for _ = 1, 60 do
    g:update(1 / 120, {})
  end
  for _ = 1, 60 do
    g:update(1 / 120, { forward = 1 })
  end
  check(
    'releasing and pressing the movement key without leaving contact stays latched',
    g.view.movementImpactSerial == serial
  )
  for _ = 1, 45 do
    g:update(1 / 120, { forward = -1 })
  end
  for _ = 1, 120 do
    g:update(1 / 120, { forward = 1 })
  end
  check(
    'a genuine retreat and new approach rearms wall contact',
    g.view.movementImpactSerial == serial + 1
  )
  local stationary = fresh()
  stationary.player.x = 11.28
  for _ = 1, 60 do
    stationary:update(1 / 120, { forward = 1, dash = true })
  end
  check(
    'a dash requested while already touching a wall does not fake acquired momentum',
    stationary.view.movementImpactSerial == 0
  )
  local noContact = fresh()
  noContact:update(0.2, { forward = 1, dash = true })
  check(
    'normal dash exit-speed cap is not counted as a collision impulse',
    noContact.view.movementImpactSerial == 0
  )
  local baseline = wallRun(120)
  for _, rate in ipairs({ 30, 60 }) do
    local v = wallRun(rate)
    check(
      'wall momentum, energy, response and position match at ' .. rate .. ' and 120 Hz',
      near(v.view.lastWallImpact.impulse, baseline.view.lastWallImpact.impulse)
        and near(v.view.lastWallImpact.energyLost, baseline.view.lastWallImpact.energyLost)
        and near(v.view.weaponImpactX, baseline.view.weaponImpactX)
        and near(v.view.weaponImpactY, baseline.view.weaponImpactY)
        and near(v.player.x, baseline.player.x)
    )
  end
  local quiet = wallRun(120, false)
  check(
    'motion off preserves collision physics and measurement but removes contact decoration',
    near(quiet.player.x, baseline.player.x)
      and near(quiet.view.lastWallImpact.impulse, baseline.view.lastWallImpact.impulse)
      and quiet.view.weaponImpactX == 0
      and quiet.view.weaponImpactY == 0
      and quiet.view.weaponImpactRoll == 0
  )
  local function landing(rate, height, velocity, motion)
    local v = fresh()
    v.view.motion = motion ~= false
    v.player.yaw = 0
    if height then
      v.player.jump = height
      v.player.jumpV = velocity or 0
    else
      v:update(1 / rate, { jump = true })
    end
    for _ = 1, rate * 2 do
      v:update(1 / rate, {})
      if v.view.lastLandingImpact then
        return v
      end
    end
    error('Landing fixture never touched the floor')
  end
  local jump = landing(120)
  check(
    'normal jump dissipates exactly the launch energy on landing',
    near(
      jump.view.lastLandingImpact.energyLost,
      0.5
        * require('src.content.characters').standard().movement.jumpSpeed
        * require('src.content.characters').standard().movement.jumpSpeed
    )
      and near(
        jump.view.lastLandingImpact.impulse,
        require('src.content.characters').standard().movement.jumpSpeed
      )
  )
  check(
    'takeoff and landing are separate one-off contacts',
    jump.view.movementImpactSerial == 2 and jump.view.lastLandingImpact.kind == 'landing'
  )
  check(
    'the normal jump does not raise a decorative dust cloud',
    jump.view.lastLandingImpact.dust == 0
  )
  local drop = landing(120, 2, 0)
  check(
    'a higher fall carries the expected gravitational energy into contact',
    near(drop.view.lastLandingImpact.energyLost, T.gravity * 2)
      and drop.view.lastLandingImpact.kick > jump.view.lastLandingImpact.kick
  )
  check(
    'a harder landing emits at most two short painted dust puffs',
    drop.view.lastLandingImpact.dust == 2
      and #drop.view.effects == 2
      and drop.view.effects[1].kind == 'stone'
      and drop.view.effects[1].duration == 0.28
  )
  for _, rate in ipairs({ 30, 60 }) do
    local v = landing(rate, 2, 0)
    check(
      'contact energy and mean force are independent of render steps at ' .. rate .. ' Hz',
      near(v.view.lastLandingImpact.impulse, drop.view.lastLandingImpact.impulse)
        and near(v.view.lastLandingImpact.energyLost, drop.view.lastLandingImpact.energyLost)
        and near(v.view.lastLandingImpact.meanForce, drop.view.lastLandingImpact.meanForce)
    )
  end
  local off = landing(120, 2, 0, false)
  check(
    'motion off suppresses landing hands and dust while retaining the real energy report',
    off.view.weaponDip == 0
      and off.view.lastLandingImpact.dust == 0
      and #off.view.effects == 0
      and near(off.view.lastLandingImpact.energyLost, drop.view.lastLandingImpact.energyLost)
  )
  serial = drop.view.movementImpactSerial
  for _ = 1, 240 do
    drop:update(1 / 120, {})
  end
  check(
    'standing after a landing cannot keep producing contacts or dust',
    drop.view.movementImpactSerial == serial and #drop.view.effects == 0
  )
  local edge = fresh()
  edge.player.x = 11.28
  edge.player.jump = 0.05
  edge.player.jumpV = -10
  for _ = 1, 30 do
    edge:update(1 / 120, {})
    if edge.view.lastLandingImpact then
      break
    end
  end
  check(
    'dust is not spawned inside a wall beside the player',
    edge.view.lastLandingImpact and edge.view.lastLandingImpact.dust == 0
  )
  local high = I.landingMetrics(100)
  check(
    'extreme test-field falls remain bounded without clipping the physical energy report',
    high.energyLost == 5000 and high.kick < 210 and high.kick > 200
  )
  local normalPeak, dropPeak = 0, 0
  for _, v in ipairs({ jump, off }) do
    M.init(v)
    v.view.motion = true
  end
  M.update(
    jump,
    1 / 120,
    0,
    0,
    0,
    I.landingMetrics(require('src.content.characters').standard().movement.jumpSpeed)
  )
  M.update(off, 1 / 120, 0, 0, 0, I.landingMetrics(math.sqrt(T.gravity * 4)))
  for _ = 1, 90 do
    M.update(jump, 1 / 120, 0, 0, 0)
    M.update(off, 1 / 120, 0, 0, 0)
    normalPeak = math.max(normalPeak, jump.view.weaponDip)
    dropPeak = math.max(dropPeak, off.view.weaponDip)
  end
  check(
    'actual spring response is stronger for the drop and remains readable',
    dropPeak > normalPeak * 1.2 and normalPeak > 2 and dropPeak < 8
  )
  g = fresh()
  g.state = 'paused'
  g.player.jump = 2
  g.player.jumpV = -10
  for _ = 1, 30 do
    g:update(1 / 30, { forward = 1 })
  end
  check(
    'paused simulation neither generates nor advances movement contacts',
    g.view.movementImpactSerial == 0 and not g.view.lastLandingImpact and g.player.jump == 2
  )
  g = fresh()
  g.player.yaw = 0.3
  g.player.pitch = 0.2
  local health, ammo, yaw, pitch =
    g.player.hp, g.player.arsenal.exorcist.mag, g.player.yaw, g.player.pitch
  g.player.x = 11.28
  I.wall(g, true, 6, 0, 0, 0, 11.20, 10, 6, 0)
  I.landing(g, 10)
  check(
    'impact presentation cannot alter aim, health, ammunition or velocities',
    g.player.hp == health
      and g.player.arsenal.exorcist.mag == ammo
      and g.player.yaw == yaw
      and g.player.pitch == pitch
      and g.player.vx == 0
      and g.player.vz == 0
  )
  I.init(g)
  M.init(g)
  check(
    'reset clears contact latches, reports and weapon impulses',
    not g.view.movementContact.blocked
      and not g.view.lastMovementImpact
      and not g.view.lastWallImpact
      and not g.view.lastLandingImpact
      and g.view.movementImpactSerial == 0
      and g.view.weaponImpactX == 0
  )
  local direct = fresh()
  direct.player.x = 11.28
  direct.player.yaw = math.pi / 2
  I.wall(direct, true, 6, 0, 0, 0, 11.20, 10, 6, 0)
  local side = fresh()
  side.player.x = 11.28
  side.player.yaw = 0
  I.wall(side, true, 6, 0, 0, 0, 11.20, 10, 6, 0)
  check(
    'head-on and side contacts push different presentation axes',
    math.abs(direct.view.weaponImpactVX) < 1e-6
      and direct.view.weaponImpactVY > 0
      and side.view.weaponImpactVX > 0
      and side.view.weaponImpactVRoll > 0
  )
  local parallel = fresh()
  parallel.player.x, parallel.player.z = 11.28, 10
  I.wall(parallel, true, 6, 6, 0, 6, 11.28, 9.8, 0, 6)
  check(
    'tangent travel alone cannot qualify a new normal collision impulse',
    parallel.view.movementImpactSerial == 0
  )
  direct.player.x, direct.player.z = 11.28, 10.4
  I.wall(direct, false, 0, 6, 0, 6, 11.28, 10, 0, 6)
  direct.player.z = 10.5
  I.wall(direct, true, 0, 6, 0, 0, 11.28, 10.4, 0, 6)
  check(
    'a real collision with a second corner plane can respond while the first remains latched',
    direct.view.movementImpactSerial == 2 and direct.view.lastWallImpact.normalZ < -0.99
  )
  local relocated = fresh()
  relocated.player.x = 11.28
  I.wall(relocated, true, 6, 0, 0, 0, 11.2, 10, 6, 0)
  relocated.view.weaponImpactX = 3
  relocated.player.x, relocated.player.z = 5, 5
  I.wall(relocated, false, 0, 0, 0, 0, 5, 5, 0, 0)
  check(
    'test-field relocation clears the old contact plane and decorative impulse',
    not relocated.view.movementContact.blocked
      and relocated.view.weaponImpactX == 0
      and relocated.view.weaponImpactVX == 0
  )
end
return Tests
