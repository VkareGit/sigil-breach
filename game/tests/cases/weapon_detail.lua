-- Behavioural contracts for the small, physical carry and discharge gestures.
-- Pure presentation may respond to a shot/contact, never become a second rule.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(G, check)
  local M = require('src.feedback.weapon_motion')
  local W = require('src.feedback.weight')
  local Defs = require('src.content.weapons')
  local V = require('src.render.weapon')
  local B = require('src.combat.ballistics')
  local Gait = require('src.feedback.gait')
  local T = require('src.content.tuning')
  local near = Fixtures.within(1e-7)
  local function fresh(slot)
    local g = G.new()
    g.ephemeral = true
    g.state = 'playing'
    g.enemies = {}
    g.pickups = {}
    g.player.weapon = slot or 1
    g.player.yaw = 0
    return g
  end
  local function shot(slot, power, rate, seconds)
    local g = fresh(slot)
    W.shot(g, Defs.profile(slot), power or 1)
    local peak = 0
    for _ = 1, math.floor((seconds or 0.5) * rate + 0.5) do
      W.update(g, 1 / rate)
      peak = math.max(peak, math.abs(g.view.weaponShotRoll))
    end
    return g, peak
  end
  local sg, sgPeak = shot(1, 1, 120, 0.5)
  local rv, rvPeak = shot(2, 1, 120, 0.5)
  check(
    'Judge has a visible wrist catch while the supported Exorcist stays axial',
    rvPeak > 0.05 and rvPeak < 0.075 and sgPeak < 0.015 and rvPeak > sgPeak * 4
  )
  local half, halfPeak = shot(1, 0.5, 120, 0.5)
  check('a single shotgun shell halves the cosmetic wrist impulse', near(halfPeak, sgPeak * 0.5))
  check(
    'wrist catch returns close to rest without a continuing spin',
    math.abs(rv.view.weaponShotRoll) < 0.002 and math.abs(sg.view.weaponShotRoll) < 0.0001
  )
  for slot = 1, 2 do
    local reference = shot(slot, 1, 120, 0.5)
    for _, rate in ipairs({ 30, 60 }) do
      local g = shot(slot, 1, rate, 0.5)
      check(
        'weapon ' .. slot .. ' wrist spring preserves elapsed time at ' .. rate .. ' Hz',
        near(g.view.weaponShotRoll, reference.view.weaponShotRoll)
          and near(g.view.weaponShotRollV, reference.view.weaponShotRollV)
      )
    end
  end
  local g = fresh(2)
  local ox, oy, oz = B.origin(g)
  local yaw, pitch = g.player.yaw, g.player.pitch
  local mag, reserve = g.player.arsenal.judge.mag, g.player.arsenal.judge.reserve
  local reload, ready, elapsed = g.player.reload, g.player.arsenal.judge.readyAt, g.elapsed
  local gripX, gripY = V.transform(g, 800, 450)
  W.shot(g, Defs.profile(2), 1)
  W.update(g, 0.08)
  local x, y, r = V.transform(g, 800, 450)
  local ax, ay, az = B.origin(g)
  check(
    'the Judge rotates about its registered hand grip, without drifting horizontally',
    near(x, gripX) and r < -0.05 and r > -0.10 and y - gripY < 9
  )
  check(
    'wrist presentation never redirects the firing ray',
    near(ax, ox)
      and near(ay, oy)
      and near(az, oz)
      and g.player.yaw == yaw
      and g.player.pitch == pitch
  )
  check(
    'wrist update preserves ammunition reload and ready clocks',
    g.player.arsenal.judge.mag == mag
      and g.player.arsenal.judge.reserve == reserve
      and g.player.reload == reload
      and g.player.arsenal.judge.readyAt == ready
      and g.elapsed == elapsed
  )
  local wr, wv = g.view.weaponShotRoll, g.view.weaponShotRollV
  for _ = 1, 100 do
    V.transform(g, 800, 450)
    M.pose(g)
  end
  check(
    'sampling the drawn weapon never integrates another recoil step',
    g.view.weaponShotRoll == wr and g.view.weaponShotRollV == wv
  )
  for _ = 1, 100 do
    W.shot(g, Defs.profile(2), 1)
    W.update(g, 1 / 120)
  end
  check(
    'even impossible repeated shot impulses cannot turn the wrist beyond its stop',
    math.abs(g.view.weaponShotRoll) <= Defs.profile(2).weight.wristLimit
      and math.abs(g.view.weaponShotRollV) <= 3
  )
  g.view.motion = false
  W.update(g, 1 / 120)
  g.view.motion = true
  W.update(g, 1 / 120)
  check(
    'disabling motion discards the wrist impulse instead of hiding it',
    g.view.weaponShotRoll == 0 and g.view.weaponShotRollV == 0
  )

  -- Walk at a fixed speed, independently of rendering, across contact boundaries.
  local function walk(rate, slot)
    local q = fresh(slot)
    q.player.vz = require('src.content.characters').standard().movement.moveSpeed
    for _ = 1, rate * 2 do
      M.update(
        q,
        1 / rate,
        require('src.content.characters').standard().movement.moveSpeed / rate,
        0,
        require('src.content.characters').standard().movement.moveSpeed
      )
    end
    return q
  end
  for slot = 1, 2 do
    local reference = walk(120, slot)
    for _, rate in ipairs({ 30, 60 }) do
      local q = walk(rate, slot)
      check(
        'weapon ' .. slot .. ' planted contact spring agrees at ' .. rate .. ' and 120 Hz',
        near(q.view.weaponStepY, reference.view.weaponStepY)
          and near(q.view.weaponStepVY, reference.view.weaponStepVY)
          and near(q.view.weaponStepRoll, reference.view.weaponStepRoll)
          and q.view.gaitSteps == reference.view.gaitSteps
      )
    end
  end
  g = fresh()
  g.player.vz = require('src.content.characters').standard().movement.moveSpeed
  local distance = Gait.stepDistance
  M.update(
    g,
    (distance - 0.01) / require('src.content.characters').standard().movement.moveSpeed,
    distance - 0.01,
    0,
    require('src.content.characters').standard().movement.moveSpeed
  )
  check(
    'carry does not invent a foot impact before the actual distance crossing',
    g.view.weaponStepY == 0 and g.view.weaponStepVY == 0 and g.view.gaitSteps == 0
  )
  M.update(
    g,
    0.02 / require('src.content.characters').standard().movement.moveSpeed,
    0.02,
    0,
    require('src.content.characters').standard().movement.moveSpeed
  )
  check(
    'a foot contact gives a small, already-advancing hand impulse in its own frame',
    g.view.weaponStepY > 0
      and g.view.weaponStepY < 1
      and g.view.weaponStepVY > 0
      and g.view.weaponStepRoll > 0
      and g.view.gaitSteps == 1
  )
  -- A second foot has the opposite load transfer; sample at the same contact age.
  local first = g.view.weaponStepRoll
  M.init(g)
  g.view.gaitPhase = math.pi
  M.update(
    g,
    (distance + 0.01) / require('src.content.characters').standard().movement.moveSpeed,
    distance + 0.01,
    0,
    require('src.content.characters').standard().movement.moveSpeed
  )
  check(
    'left and right foot plants alternate the slight grip roll',
    g.view.weaponStepRoll < 0 and near(math.abs(g.view.weaponStepRoll), first)
  )
  for _, state in ipairs({ 'wall', 'air', 'dash', 'slide' }) do
    g = fresh()
    g.player.vz = require('src.content.characters').standard().movement.moveSpeed
    if state == 'air' then
      g.player.jump = 1
    elseif state == 'dash' then
      g.player.dashTimer = 0.5
    elseif state == 'slide' then
      g.player.slideTimer = 0.5
    end
    for _ = 1, 120 do
      M.update(
        g,
        1 / 120,
        state == 'wall' and 0
          or require('src.content.characters').standard().movement.moveSpeed / 120,
        0,
        require('src.content.characters').standard().movement.moveSpeed
      )
    end
    check(
      state .. ' cannot create decorative planted foot impulses',
      g.view.weaponStepY == 0
        and g.view.weaponStepVY == 0
        and g.view.weaponStepRoll == 0
        and g.view.gaitSteps == 0
    )
  end
  g = walk(120, 1)
  g.player.vz = 0
  for _ = 1, 240 do
    M.update(g, 1 / 120, 0, 0, 0)
  end
  check(
    'foot contact settles after the player stops without walking in place',
    math.abs(g.view.weaponStepY) < 1e-7
      and math.abs(g.view.weaponStepRoll) < 1e-7
      and g.view.weaponCarry < 1e-7
  )
  g = fresh()
  g.player.jump = 1
  g.player.jumpV = 5
  for _ = 1, 60 do
    M.update(g, 1 / 120, 0.03, 0, 0)
  end
  check(
    'rising hands trail the actual vertical velocity without a ground stride',
    g.view.weaponAirY > 1 and g.view.weaponAirY <= 2.2 and g.view.gaitSteps == 0
  )
  g.player.jumpV = -5
  for _ = 1, 60 do
    M.update(g, 1 / 120, 0.03, 0, 0)
  end
  check(
    'falling hands change direction as vertical velocity changes',
    g.view.weaponAirY < -1 and g.view.weaponAirY >= -2.2 and g.view.gaitSteps == 0
  )
  g.player.jump = 0
  g.player.jumpV = 0
  for _ = 1, 180 do
    M.update(g, 1 / 120, 0, 0, 0)
  end
  check('airborne carry settles when the body is grounded', math.abs(g.view.weaponAirY) < 0.00001)
  g = walk(120, 2)
  g.view.weaponAirY = 2
  g.view.weaponAirVY = 5
  g.view.motion = false
  M.update(g, 1 / 120, 0.1, 0, 0)
  local px, py, pr = M.pose(g)
  check(
    'reduced motion clears contact and airborne carry and their hidden velocities',
    px == 0
      and py == 0
      and pr == 0
      and g.view.weaponStepY == 0
      and g.view.weaponStepVY == 0
      and g.view.weaponStepRoll == 0
      and g.view.weaponStepVRoll == 0
      and g.view.weaponAirY == 0
      and g.view.weaponAirVY == 0
  )
end
return Tests
