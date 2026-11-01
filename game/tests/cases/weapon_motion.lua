local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, check)
  local M = require('src.feedback.weapon_motion')
  local V = require('src.render.weapon')
  local B = require('src.combat.ballistics')
  local near = Fixtures.within(1e-7)
  local function fresh(slot)
    local g = G.new()
    g.ephemeral = true
    g.state = 'playing'
    g.enemies = {}
    g.pickups = {}
    g.player.weapon = slot or 1
    return g
  end
  local g = fresh()
  check(
    'carry starts neutral on a fresh game',
    g.view.weaponCarry == 0
      and g.view.weaponStride == 0
      and g.view.weaponDip == 0
      and g.view.weaponAimX == 0
  )
  local initial = g.view.weaponStride
  for _ = 1, 120 do
    M.update(g, 1 / 120, 0, 0, 0)
  end
  local x, y, roll = M.pose(g)
  check(
    'idle breath is subtle and has no walking-in-place phase',
    g.view.weaponStride == initial
      and math.abs(x) < 0.31
      and math.abs(y) < 0.73
      and math.abs(y) > 0.1
  )
  g.player.vx = 6
  for _ = 1, 120 do
    M.update(g, 1 / 120, 0, 6, 0)
  end
  check(
    'a held movement key against a wall cannot create a stride',
    g.view.weaponStride == initial and g.view.weaponCarry < 0.0001
  )
  g = fresh()
  g.player.jump = 1
  g.player.vz = 6
  for _ = 1, 60 do
    M.update(g, 1 / 120, 0.05, 0, 6)
  end
  check(
    'horizontal air travel does not generate planted footsteps',
    g.view.weaponStride == 0 and g.view.weaponCarry == 0
  )
  g = fresh()
  g.player.dashTimer = 0.1
  M.update(g, 1 / 120, 0.2, 0, 0)
  check(
    'a dash lowers the carried weapon without a running gait',
    g.view.weaponStride == 0 and g.view.weaponCarry == 0 and g.view.weaponLower > 0
  )
  g.player.dashTimer = 0
  g.player.slideTimer = 0.2
  M.update(g, 1 / 120, 0.2, 0, 0)
  check(
    'sliding keeps the hands braced without planted footsteps',
    g.view.weaponStride == 0 and g.view.weaponLower > 0
  )
  g = fresh()
  g.player.vz = -6
  for _ = 1, 120 do
    M.update(g, 1 / 120, 0.05, 0, -6)
  end
  check(
    'ground stride follows actual travelled metres',
    near(g.view.weaponStride, 15) and g.view.weaponCarry > 0.95
  )
  local moving = g.view.weaponCarry
  g.player.vz = 0
  M.update(g, 1 / 120, 0, 0, -6)
  check(
    'stopping eases the gait and produces a separate braking response',
    g.view.weaponCarry < moving and g.view.weaponCarry > 0 and g.view.weaponLagY < 0
  )
  for _ = 1, 180 do
    M.update(g, 1 / 120, 0, 0, 0)
  end
  check(
    'movement inertia settles after stopping',
    math.abs(g.view.weaponLagY) < 0.001 and g.view.weaponCarry < 0.0001
  )
  g = fresh()
  local peak = 0
  M.update(g, 1 / 120, 0, 0, 0, -8)
  for _ = 1, 90 do
    M.update(g, 1 / 120, 0, 0, 0)
    peak = math.max(peak, g.view.weaponDip)
  end
  check(
    'landing gives a bounded downward deflection then recovers',
    peak > 2 and peak < 8 and math.abs(g.view.weaponDip) < 0.03
  )
  g = fresh()
  M.update(g, 1 / 120, 0, 0, 0)
  local ox, oy, oz = B.origin(g)
  local yaw, pitch = g.player.yaw, g.player.pitch
  g.player.yaw = yaw + 0.4
  g.player.pitch = 0.12
  M.update(g, 1 / 120, 0, 0, 0)
  check(
    'aim inertia trails horizontal and vertical turn',
    g.view.weaponAimX < 0 and g.view.weaponAimY > 0
  )
  local afterX, afterY, afterZ = B.origin(g)
  check(
    'presentation cannot alter ballistic origin or player aim',
    ox == afterX
      and oy == afterY
      and oz == afterZ
      and g.player.yaw == yaw + 0.4
      and g.player.pitch == 0.12
  )
  for _ = 1, 180 do
    M.update(g, 1 / 120, 0, 0, 0)
  end
  check(
    'aim inertia settles without drift',
    math.abs(g.view.weaponAimX) < 0.001 and math.abs(g.view.weaponAimY) < 0.001
  )
  g = fresh()
  g.player.yaw = math.pi - 0.001
  M.init(g)
  M.update(g, 1 / 120, 0, 0, 0)
  g.player.yaw = -math.pi + 0.001
  M.update(g, 1 / 120, 0, 0, 0)
  check('the angular seam cannot produce a full-turn sway', math.abs(g.view.weaponAimX) < 0.02)
  g = fresh()
  local finite = true
  local bounded = true
  for i = 1, 360 do
    g.player.yaw = g.player.yaw + math.sin(i) * 2
    g.player.pitch = math.sin(i) * 0.9
    g.player.vx = math.sin(i) * 22
    g.player.vz = math.cos(i) * 22
    M.update(g, 1 / 120, 0.25, -g.player.vx, -g.player.vz, i % 30 == 0 and -50 or nil)
    local px, py, roll = M.pose(g)
    finite = finite and px == px and py == py and roll == roll
    bounded = bounded and math.abs(px) <= 13 and py >= -8 and py <= 14 and math.abs(roll) <= 0.04
  end
  check('extreme turns and repeated impacts remain finite and bounded', finite and bounded)
  g.view.motion = false
  M.update(g, 1 / 120, 0.1, 0, 0, -50)
  x, y, roll = M.pose(g)
  check(
    'motion off removes all decorative carry, breath and landing motion',
    x == 0
      and y == 0
      and roll == 0
      and g.view.weaponCarry == 0
      and g.view.weaponDip == 0
      and g.view.weaponAimX == 0
  )
  g.view.motion = true
  M.update(g, 1 / 120, 0, g.player.vx, g.player.vz)
  check(
    'reenabling motion cannot replay stale aim or impact impulses',
    g.view.weaponAimX == 0 and g.view.weaponDip == 0
  )
  g = fresh()
  g:update(0.2, { forward = 1 })
  g.state = 'paused'
  local clock, stride, carry = g.view.weaponClock, g.view.weaponStride, g.view.weaponCarry
  for _ = 1, 60 do
    g:update(1 / 30, { forward = 1, turn = 1 })
  end
  check(
    'paused simulation freezes carry clocks and gait',
    g.view.weaponClock == clock and g.view.weaponStride == stride and g.view.weaponCarry == carry
  )
  g.state = 'playing'
  g.map = true
  g:update(0.2, { forward = 1 })
  check(
    'the map overlay freezes carry clocks',
    g.view.weaponClock == clock and g.view.weaponStride == stride
  )
  local function sequence(rate, slot)
    local v = fresh(slot)
    for i = 1, rate * 2 do
      local t = (i - 1) / rate
      v:update(1 / rate, {
        forward = t < 0.5 and 1 or 0,
        strafe = t >= 0.5 and t < 1 and 1 or 0,
        turn = t >= 1 and t < 1.5 and 1 or 0,
        jump = i == 1,
      })
    end
    return v
  end
  for slot = 1, 2 do
    local reference = sequence(120, slot)
    for _, rate in ipairs({ 30, 60 }) do
      local a = sequence(rate, slot)
      local same = true
      for _, key in ipairs({
        'weaponClock',
        'weaponStride',
        'weaponCarry',
        'weaponAimX',
        'weaponAimY',
        'weaponLean',
        'weaponDip',
        'weaponLower',
        'weaponLagX',
        'weaponLagY',
      }) do
        same = same and near(a.view[key], reference.view[key], 1e-6)
      end
      check(
        'weapon ' .. slot .. ' carry and landing are identical at ' .. rate .. ' and 120 Hz',
        same and near(a.player.x, reference.player.x) and near(a.player.z, reference.player.z)
      )
    end
  end
  local function mouseSequence(rate)
    local v = fresh()
    M.update(v, 1 / 120, 0, 0, 0)
    for i = 1, rate * 2 do
      v.player.yaw = v.player.yaw + 0.7 / rate
      v.player.pitch = v.player.pitch + 0.1 / rate
      v:update(1 / rate, {})
    end
    return v
  end
  local reference = mouseSequence(120)
  for _, rate in ipairs({ 30, 60 }) do
    local v = mouseSequence(rate)
    check(
      'batched mouse packets remain close at ' .. rate .. ' and 120 Hz',
      near(v.view.weaponAimX, reference.view.weaponAimX, 0.21)
        and near(v.view.weaponAimY, reference.view.weaponAimY, 0.04)
    )
  end
  g = sequence(120, 1)
  g.view.weaponAimX = 6
  g.view.weaponDip = 4
  local bx, by, br = V.transform(g, 800, 450)
  for _, viewport in ipairs({ { 640, 450 }, { 1050, 450 }, { 1280, 720 }, { 1920, 1080 } }) do
    local w, h = viewport[1], viewport[2]
    local tx, ty, tr = V.transform(g, w, h)
    check(
      'carry keeps its apparent size at ' .. w .. 'x' .. h,
      near((tx - w * 0.5) / h, (bx - 400) / 450)
        and near((ty - h) / h, (by - 450) / 450)
        and near(br, tr)
    )
  end
  g = fresh()
  g.view.motion = false
  local idleX, idleY, idleRoll = V.transform(g, 800, 450)
  g.player.reload = 0.45
  g.player.reloadDuration = 0.94
  g.player.reloadOffset = 0
  local rx, ry, rr = V.pose(g)
  x, y, roll = V.transform(g, 800, 450)
  check(
    'motion off preserves the mechanical reload action',
    near(x - idleX, rx) and near(y - idleY, ry) and near(roll - idleRoll, rr)
  )
  g = fresh()
  local before = g.view.weaponClock
  for _, dt in ipairs({ 0, -1, math.huge, 0 / 0 }) do
    M.update(g, dt, 1, 0, 0, -5)
  end
  check(
    'invalid time cannot poison carry state',
    g.view.weaponClock == before and g.view.weaponDip == 0
  )
  g = fresh()
  g.view.weaponDip = 4
  g.view.weaponStride = 20
  g.view.weaponAimX = 5
  M.init(g)
  check(
    'reset clears every carry transient',
    g.view.weaponDip == 0
      and g.view.weaponStride == 0
      and g.view.weaponAimX == 0
      and g.view.weaponClock == 0
  )
  g.player.yaw = g.player.yaw + 2
  g.player.pitch = 0.6
  M.update(g, 1 / 120, 0, 0, 0)
  check(
    'relocation after reset is not misread as a mouse turn',
    g.view.weaponAimX == 0 and g.view.weaponAimY == 0
  )
end
return Tests
