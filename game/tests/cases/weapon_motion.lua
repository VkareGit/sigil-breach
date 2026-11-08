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
  -- Carry weight is the weapon's own profile (PLAN E6, Exorcist plan point 2):
  -- the two-handed shotgun (slot 1) against the revolver (slot 2) through the
  -- same body motion. Heavier is not a bigger swing in every axis.
  local dt = 1 / 120
  local function series(slot, steps, key, ...)
    local v = fresh(slot)
    M.update(v, dt, 0, 0, 0)
    local out = {}
    for _, phase in ipairs({ ... }) do
      for _ = 1, phase.steps do
        v:update(dt, phase.input)
      end
    end
    for i = 1, steps do
      v:update(dt, {})
      out[i] = v.view[key]
    end
    return out
  end
  local function shape(values)
    local peak, at = 0, 0
    for i, value in ipairs(values) do
      if math.abs(value) > math.abs(peak) then
        peak, at = value, i
      end
    end
    local back = 0
    for i = at, #values do
      if values[i] * peak < 0 then
        back = math.max(back, math.abs(values[i]))
      end
    end
    return math.abs(peak), at, back / math.max(math.abs(peak), 1e-9)
  end
  local function started(slot)
    local v = fresh(slot)
    M.update(v, dt, 0, 0, 0)
    local out = {}
    for i = 1, 60 do
      v:update(dt, { forward = 1 })
      out[i] = v.view.weaponLagY
    end
    return out
  end
  local shotgunPeak, shotgunAt, shotgunBack = shape(started(1))
  local revolverPeak, revolverAt = shape(started(2))
  check(
    "the shotgun's heavy barrels trail a start further and later than the revolver",
    shotgunPeak > revolverPeak * 1.1 and shotgunAt > revolverAt and shotgunBack < 0.01
  )
  local running = { steps = 120, input = { forward = 1 } }
  local stopShotgun = { shape(series(1, 120, 'weaponLagY', running)) }
  local stopRevolver = { shape(series(2, 120, 'weaponLagY', running)) }
  check(
    'the shotgun settles a stop without swinging back past rest',
    stopShotgun[1] > stopRevolver[1] and stopShotgun[3] < stopRevolver[3]
  )
  local function reversed(slot)
    local v = fresh(slot)
    M.update(v, dt, 0, 0, 0)
    for _ = 1, 120 do
      v:update(dt, { strafe = 1 })
    end
    local most = 0
    for _ = 1, 120 do
      v:update(dt, { strafe = -1 })
      most = math.max(most, math.abs(v.view.weaponLean))
    end
    return most
  end
  check(
    'two hands on the stock keep the shotgun more level than the revolver in a sidestep',
    reversed(1) < reversed(2) * 0.8
  )
  local function walked(slot)
    local v = fresh(slot)
    local run = require('src.content.characters').of(v.player).movement.moveSpeed
    v.player.vz = run
    local roll, low, stepRoll = 0, 0, 0
    for i = 1, 240 do
      M.update(v, dt, run * dt, 0, run)
      if i > 60 then
        local _, y, r = M.pose(v)
        roll, low = math.max(roll, math.abs(r)), math.max(low, y)
        stepRoll = math.max(stepRoll, math.abs(v.view.weaponStepRoll))
      end
    end
    return roll, low, stepRoll
  end
  local shotgunRoll, shotgunLoad, shotgunStep = walked(1)
  local revolverRoll, revolverLoad, revolverStep = walked(2)
  check(
    'the walking shotgun bears down more than the revolver but rolls less',
    shotgunLoad > revolverLoad and shotgunRoll < revolverRoll and shotgunStep < revolverStep
  )
  local function landed(slot)
    local v = fresh(slot)
    local out = {}
    M.update(v, dt, 0, 0, 0, -8)
    out[1] = v.view.weaponDip
    for i = 2, 120 do
      M.update(v, dt, 0, 0, 0)
      out[i] = v.view.weaponDip
    end
    return shape(out)
  end
  local shotgunDip, _, shotgunRebound = landed(1)
  local revolverDip, _, revolverRebound = landed(2)
  check(
    'the shotgun lands deeper than the revolver and settles without a rebound',
    shotgunDip > revolverDip and shotgunRebound < 0.01 and shotgunRebound < revolverRebound
  )
  local function rest(slot)
    local v = fresh(slot)
    for _ = 1, 120 do
      M.update(v, dt, 0, 0, 0)
    end
    local lowX, highX, lowY, highY = math.huge, -math.huge, math.huge, -math.huge
    for _ = 1, 1440 do
      M.update(v, dt, 0, 0, 0)
      local x, y = M.pose(v)
      lowX, highX = math.min(lowX, x), math.max(highX, x)
      lowY, highY = math.min(lowY, y), math.max(highY, y)
    end
    v.player.dashTimer = 0.4
    for _ = 1, 24 do
      M.update(v, dt, 0, 0, 0)
    end
    local before = M.pose(v)
    for _ = 1, 12 do
      M.update(v, dt, 0, 0, 0)
    end
    return highX - lowX, highY - lowY, math.abs(M.pose(v) - before)
  end
  local shotgunX, shotgunY, shotgunDodge = rest(1)
  local revolverX, revolverY, revolverDodge = rest(2)
  check(
    'the resting shotgun is held more sparingly than the revolver',
    shotgunX < revolverX and shotgunY < revolverY and shotgunX > 0.1 and shotgunY > 0.1
  )
  check(
    "a dodge stills the shotgun's grip corrections and leaves the revolver's breath",
    shotgunDodge < 1e-3 and revolverDodge > 0.01
  )
  -- A gesture of the body carries the gun in three phases (Exorcist plan
  -- point 3): the weight is taken against the travel, the gun is held, the
  -- grip is retaken as the gesture ends. Driven like the body: its timer runs
  -- out on the hands' own steps here.
  local Knight = require('src.content.characters').of(fresh().player).movement
  local function gesture(slot, kind, side, after)
    local v = fresh(slot)
    M.update(v, dt, 0, 0, 0)
    local p = v.player
    local rx, rz = math.cos(p.yaw) * side, -math.sin(p.yaw) * side
    local timer = kind == 'dash' and 'dashTimer' or 'slideTimer'
    p[kind .. 'X'], p[kind .. 'Z'] = rx, rz
    p[timer] = kind == 'dash' and Knight.dashTime or Knight.slideTime
    local out = {}
    for i = 1, math.floor((p[timer] + after) / dt + 0.5) do
      M.update(v, dt, 0, 0, 0)
      p[timer] = math.max(0, p[timer] - dt)
      out[i] = {
        x = v.view.weaponGestureX,
        y = v.view.weaponGestureY,
        roll = v.view.weaponGestureRoll,
        vy = v.view.weaponGestureVY,
      }
    end
    return out, v
  end
  local function at(trace, seconds)
    return trace[math.max(1, math.floor(seconds / dt + 0.5))]
  end
  local right = gesture(1, 'dash', 1, 0.6)
  local left = gesture(1, 'dash', -1, 0.6)
  local early, held, out = at(right, 0.04), at(right, Knight.dashTime), right[#right]
  local exit = at(right, Knight.dashTime + 2 * dt)
  check(
    "a dodge takes the shotgun's weight against its travel and holds it close",
    early.x < -0.3 and early.roll < 0 and early.y > 0.3 and held.y > 0.5 and held.roll < 0
  )
  check(
    'a dodge to the left mirrors the right',
    near(at(left, 0.04).x, -early.x, 1e-9) and near(at(left, 0.1).roll, -at(right, 0.1).roll, 1e-9)
  )
  check(
    "the shotgun's grip is retaken as the dodge ends and nothing of it stays",
    exit.vy < 0 and math.abs(out.x) < 0.01 and math.abs(out.y) < 0.01 and math.abs(out.roll) < 1e-4
  )
  local revolver = gesture(2, 'dash', 1, 0.2)
  local still = true
  for _, s in ipairs(revolver) do
    still = still and s.x == 0 and s.y == 0 and s.roll == 0
  end
  check('the revolver keeps its dodge as it was', still)
  local slide = gesture(1, 'slide', 1, 0.6)
  local middle, late = at(slide, 0.25), at(slide, 0.45)
  check(
    'a slide holds the shotgun lower than a dodge with steady barrels',
    middle.y > held.y
      and math.abs(middle.roll - late.roll) < 0.002
      and math.abs(middle.y - late.y) < 0.2
  )
  local slideExit = at(slide, Knight.slideTime + 2 * dt)
  check(
    'the shotgun leaves a slide with a readable regrip and settles',
    slideExit.vy < -20 and math.abs(slide[#slide].y) < 0.01
  )
  local function jumped(slot)
    local v = fresh(slot)
    M.update(v, dt, 0, 0, 0)
    v:update(dt, { jump = true })
    local peak, peakAt, dip = 0, 0, 0
    for i = 1, 90 do
      v:update(dt, {})
      dip = math.max(dip, v.view.weaponDip)
      if v.view.weaponAirY > peak then
        peak, peakAt = v.view.weaponAirY, i
      end
    end
    return peak, peakAt, dip
  end
  local shotgunAir, shotgunAirAt, shotgunTakeoff = jumped(1)
  local revolverAir, revolverAirAt, revolverTakeoff = jumped(2)
  check(
    "the shotgun's hands sink deeper on a takeoff and trail the rise later",
    shotgunTakeoff > revolverTakeoff
      and shotgunAirAt > revolverAirAt
      and shotgunAir ~= 0
      and revolverAir ~= 0
  )
  -- The draw: the shotgun rises fast and seats into the shoulder, in its
  -- firing place at the moment it may fire; the revolver's draw is unchanged.
  local drawn = fresh(1)
  local function draw(v, age)
    v.view.swapAge = age
    return M.draw(v)
  end
  local half = draw(drawn, 0.06)
  local seatDrop, seatY, seatRoll = draw(drawn, 0.17)
  local endDrop, endY, endRoll = draw(drawn, 0.20)
  check(
    'the shotgun rises into the shoulder and is in place when it may fire',
    half < 0.35 * (1 - 0.06 / 0.2) - 0.02
      and seatY > 0.5
      and seatRoll ~= 0
      and seatDrop < 0.02
      and endDrop == 0
      and endY == 0
      and endRoll == 0
  )
  local judge = fresh(2)
  local same = true
  for _, age in ipairs({ 0, 0.03, 0.1, 0.15, 0.2, 0.5 }) do
    local d, y, r = draw(judge, age)
    same = same and near(d, (1 - math.min(1, age / 0.20)) * 0.35, 1e-12) and y == 0 and r == 0
  end
  check('the revolver is drawn as before', same)
  drawn.player.reload = 0.5
  drawn.player.reloadDuration = 0.94
  drawn.player.reloadOffset = 0
  local _, resumedY, resumedRoll = draw(drawn, 0.17)
  check(
    'a draw that resumes a reload leaves the hands to the reload',
    resumedY == 0 and resumedRoll == 0
  )
  local _, swapped = gesture(1, 'dash', 1, -Knight.dashTime + 0.05)
  swapped.player.weapon = 2
  M.update(swapped, dt, 0, 0, 0)
  check(
    "a weapon drawn in a dodge carries none of the holstered gun's gesture",
    swapped.view.weaponGestureX == 0
      and swapped.view.weaponGestureY == 0
      and swapped.view.weaponGestureRoll == 0
  )
  local _, off = gesture(1, 'slide', 1, -Knight.slideTime + 0.1)
  off.view.motion = false
  M.update(off, dt, 0, 0, 0)
  check(
    'motion off removes a gesture in progress',
    off.view.weaponGestureY == 0 and off.view.weaponGestureVY == 0
  )
end
return Tests
