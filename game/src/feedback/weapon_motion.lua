local Characters = require('src.content.characters')
local Context = require('src.session.context')
-- Presentation only: this module never changes the camera, aim, collision,
-- weapon clocks or ammunition. Units are pixels at the 450 px scene height.
local MathX = require('src.core.mathx')
local Kinematics = require('src.physics.kinematics')
local MovementImpact = require('src.feedback.movement_impact')
local Impulses = require('src.feedback.impulses')
local Weight = require('src.feedback.weight')
local Gait = require('src.player.movement_gait')
local Reload = require('src.combat.reload')
local Fields = require('src.session.fields')
local HandMotion = require('src.content.hand_motion')
local M = {}
local sin, cos, pi = math.sin, math.cos, math.pi
local clamp = MathX.clamp
local angle = MathX.wrapAngle
local function ease(v, target, rate, dt)
  return target + (v - target) * math.exp(-rate * dt)
end
local function smooth(v)
  return MathX.smoothstep(0, 1, v)
end
function M.grip(g)
  local left = Reload.left(g, Context.actor(g))
  if left <= 0 then
    return 1
  end
  -- Blend the hand brace on elapsed presentation time, including a resumed
  -- reload. The physical action still uses its unchanged absolute timeline.
  local elapsed = math.max(0, Reload.duration(g, Context.actor(g)) - left)
  local brace =
    math.min(smooth(elapsed / HandMotion.brace.rise), smooth(left / HandMotion.brace.fall))
  return 1 - HandMotion.brace.share * brace
end
local keys = {
  'weaponClock',
  'weaponStride',
  'weaponCarry',
  'weaponAimX',
  'weaponAimY',
  'weaponAimVX',
  'weaponAimVY',
  'weaponLean',
  'weaponDip',
  'weaponDipV',
  'weaponLower',
  'weaponLagX',
  'weaponLagY',
  'weaponLagVX',
  'weaponLagVY',
  'weaponStepY',
  'weaponStepVY',
  'weaponStepRoll',
  'weaponStepVRoll',
  'weaponAirY',
  'weaponAirVY',
  'weaponImpactX',
  'weaponImpactY',
  'weaponImpactRoll',
  'weaponImpactVX',
  'weaponImpactVY',
  'weaponImpactVRoll',
}
function M.init(g, preserveGait)
  for _, key in ipairs(keys) do
    g.view[key] = Fields.viewStarts[key]
  end
  if not preserveGait then
    Gait.init(g)
  end
  -- A reset may relocate the player after Feel.init (the test field does).
  -- Prime on the first simulated frame so that relocation is not a mouse turn.
  g.view.weaponLastYaw = nil
  g.view.weaponLastPitch = nil
end
-- Foot plants are impulses at distance crossings, not a timer or a second
-- sine wave. Evaluate their remaining fraction of this step analytically so
-- a foot landing near a frame boundary does not get a whole frame of delay.
local function contactSpring(g, dt, before, after, steps, load)
  local S = HandMotion.step
  local k, d, rk, rd = S.spring[1], S.spring[2], S.rollSpring[1], S.rollSpring[2]
  local y, vy = Kinematics.spring(g.view.weaponStepY, g.view.weaponStepVY, 0, k, d, dt)
  local roll, vr = Kinematics.spring(g.view.weaponStepRoll, g.view.weaponStepVRoll, 0, rk, rd, dt)
  if steps > 0 and after > before then
    local last = math.floor(after / pi + 1e-9)
    local mass = Weight.carryFactor(g)
    -- A simulation hitch may cross several feet; at most the last four can
    -- contribute visible motion. The shared gait still counts every contact.
    for step = math.max(last - steps + 1, last - 3), last do
      local age = clamp(dt * (after - step * pi) / (after - before), 0, dt)
      local dy, dv = Kinematics.spring(0, (S.lift + S.liftLoad * load) * load * mass, 0, k, d, age)
      local dr, dvr =
        Kinematics.spring(0, (step % 2 == 0 and -1 or 1) * S.roll * load * mass, 0, rk, rd, age)
      y, vy, roll, vr = y + dy, vy + dv, roll + dr, vr + dvr
    end
  end
  g.view.weaponStepY = clamp(y, -S.limitY, S.limitY)
  g.view.weaponStepVY = clamp(vy, -S.limitVY, S.limitVY)
  g.view.weaponStepRoll = clamp(roll, -S.limitRoll, S.limitRoll)
  g.view.weaponStepVRoll = clamp(vr, -S.limitVRoll, S.limitVRoll)
end
function M.update(g, dt, travelled, previousVX, previousVZ, landingImpact, plantedTravel)
  if type(dt) ~= 'number' or dt <= 0 or dt ~= dt or dt == math.huge then
    return
  end
  local p = Context.actor(g)
  local running = Characters.of(p).movement.moveSpeed
  local planted = Gait.planted(p) and plantedTravel ~= false
  local before = g.view.gaitPhase
  local footsteps = Gait.advance(g, travelled, planted)
  -- Accessibility affects decoration, not the physical footfall clock.
  if g.view.motion == false then
    M.init(g, true)
    return footsteps
  end
  local yaw, pitch = p.yaw, p.pitch or 0
  -- Integrate angular displacement, not one mouse-event magnitude or a noisy
  -- angular velocity. Packet frequency cannot accumulate a different target.
  local A = HandMotion.aim
  local yawDelta = clamp(angle(yaw - (g.view.weaponLastYaw or yaw)), -A.turn, A.turn)
  local pitchDelta = clamp(pitch - (g.view.weaponLastPitch or pitch), -A.tilt, A.tilt)
  g.view.weaponLastYaw, g.view.weaponLastPitch = yaw, pitch
  -- Weapon mass (weapon_defs weight.aim): a heavier gun trails the turn
  -- further and settles on a softer spring. 1 = the light revolver.
  local aim = Weight.aimFactor(g)
  g.view.weaponAimVX = clamp(g.view.weaponAimVX - yawDelta * A.yawGain / aim, -A.speedX, A.speedX)
  g.view.weaponAimVY =
    clamp(g.view.weaponAimVY + pitchDelta * A.pitchGain / aim, -A.speedY, A.speedY)
  local aimK, aimD = A.spring[1] * aim, A.spring[2] * math.sqrt(aim)
  g.view.weaponAimX, g.view.weaponAimVX =
    Kinematics.spring(g.view.weaponAimX, g.view.weaponAimVX, 0, aimK, aimD, dt)
  g.view.weaponAimY, g.view.weaponAimVY =
    Kinematics.spring(g.view.weaponAimY, g.view.weaponAimVY, 0, aimK, aimD, dt)
  g.view.weaponAimX = clamp(g.view.weaponAimX, -A.reachX, A.reachX)
  g.view.weaponAimY = clamp(g.view.weaponAimY, -A.reachY, A.reachY)
  local speed = math.max(0, travelled or 0) / dt
  local weight = planted and clamp(speed / running, 0, HandMotion.carry.overrun) or 0
  contactSpring(g, dt, before, g.view.gaitPhase, footsteps, weight)
  g.view.weaponCarry = ease(g.view.weaponCarry, weight, HandMotion.carry.rate, dt)
  -- No walking-in-place against a wall, in the air, or through a dash.
  g.view.weaponStride = g.view.gaitPhase
  g.view.weaponClock = g.view.weaponClock + dt
  local ax, az = ((p.vx or 0) - (previousVX or 0)) / dt, ((p.vz or 0) - (previousVZ or 0)) / dt
  local side = ax * cos(yaw) - az * sin(yaw)
  local ahead = ax * sin(yaw) + az * cos(yaw)
  g.view.weaponLagX, g.view.weaponLagVX = Kinematics.spring(
    g.view.weaponLagX,
    g.view.weaponLagVX,
    clamp(-side * HandMotion.lag.side, -HandMotion.lag.sideLimit, HandMotion.lag.sideLimit),
    HandMotion.lag.spring[1],
    HandMotion.lag.spring[2],
    dt
  )
  g.view.weaponLagY, g.view.weaponLagVY = Kinematics.spring(
    g.view.weaponLagY,
    g.view.weaponLagVY,
    clamp(ahead * HandMotion.lag.ahead, -HandMotion.lag.aheadLimit, HandMotion.lag.aheadLimit),
    HandMotion.lag.spring[1],
    HandMotion.lag.spring[2],
    dt
  )
  local sideVelocity = ((p.vx or 0) * cos(yaw) - (p.vz or 0) * sin(yaw)) / running
  g.view.weaponLean = ease(
    g.view.weaponLean,
    clamp(-sideVelocity * HandMotion.lean.side, -HandMotion.lean.limit, HandMotion.lean.limit),
    HandMotion.lean.rate,
    dt
  )
  if landingImpact then
    local contact = type(landingImpact) == 'table' and landingImpact
      or MovementImpact.landingMetrics(landingImpact)
    if contact then
      Impulses.react(g.view, 'landingHands', contact.kick)
    end
  end
  g.view.weaponDip, g.view.weaponDipV = Kinematics.spring(
    g.view.weaponDip,
    g.view.weaponDipV,
    0,
    HandMotion.dip.spring[1],
    HandMotion.dip.spring[2],
    dt
  )
  -- On ascent the hands trail below the body, on descent they float above it.
  -- Vertical speed determines the offset; no fake walking in mid-air. The
  -- existing landing impulse remains authoritative when the feet touch down.
  local air = p.jump > 0
      and clamp((p.jumpV or 0) * HandMotion.air.rise, -HandMotion.air.limit, HandMotion.air.limit) * Weight.carryFactor(
        g
      )
    or 0
  g.view.weaponAirY, g.view.weaponAirVY = Kinematics.spring(
    g.view.weaponAirY,
    g.view.weaponAirVY,
    air,
    HandMotion.air.spring[1],
    HandMotion.air.spring[2],
    dt
  )
  local knock, twist = HandMotion.impact.spring, HandMotion.impact.rollSpring
  g.view.weaponImpactX, g.view.weaponImpactVX =
    Kinematics.spring(g.view.weaponImpactX, g.view.weaponImpactVX, 0, knock[1], knock[2], dt)
  g.view.weaponImpactY, g.view.weaponImpactVY =
    Kinematics.spring(g.view.weaponImpactY, g.view.weaponImpactVY, 0, knock[1], knock[2], dt)
  g.view.weaponImpactRoll, g.view.weaponImpactVRoll =
    Kinematics.spring(g.view.weaponImpactRoll, g.view.weaponImpactVRoll, 0, twist[1], twist[2], dt)
  -- A broken guard (condition 'staggered') drops the gun out of the aim for
  -- the stagger itself: the helpless moment is unmistakable in the hands.
  local conditions = p.conditions or {}
  local L = HandMotion.lower
  local staggered = ((conditions.staggered or 0) > 0 or (conditions.shaken or 0) > 0)
      and L.staggered
    or 0
  local lowered = (p.dashTimer > 0 and L.dash or 0)
    + (p.slideTimer > 0 and L.slide or 0)
    + staggered
  g.view.weaponLower = ease(g.view.weaponLower, lowered, L.rate, dt)
  return footsteps
end
function M.pose(g)
  if g.view.motion == false then
    return 0, 0, 0
  end
  local weight = g.view.weaponCarry
  local phase = g.view.weaponStride
  local mass = Weight.carryFactor(g)
  -- Alternating load transfer and the half-frequency foot plant describe a
  -- supported weight. Breathing recedes during travel, a shot and reloading.
  local grip = M.grip(g)
  local P = HandMotion.pose
  local quiet = (1 - clamp(weight, 0, 1)) * (1 - P.quietGrip * (1 - grip) / HandMotion.brace.share)
  quiet = quiet * clamp((g.view.shotAge - P.quietAfter) / P.quietRise, 0, 1)
  local breath = sin(g.view.weaponClock * P.breathRate) * quiet
  local gaitX = sin(phase) * P.gaitX * weight * mass
  local gaitY = (1 - cos(phase * 2)) * P.gaitY * weight * mass
  local x = gaitX
    + g.view.weaponAimX
    + g.view.weaponLagX
    + g.view.weaponImpactX
    + breath * P.breathX
  local y = gaitY
    + g.view.weaponAimY
    + g.view.weaponLagY
    + g.view.weaponDip
    + g.view.weaponLower
    + g.view.weaponImpactY
    + breath * P.breathY
  y = y + g.view.weaponStepY + g.view.weaponAirY
  local roll = g.view.weaponLean
    + sin(phase) * P.gaitRoll * weight * mass
    + g.view.weaponAimX * P.aimRoll
    + g.view.weaponImpactRoll
    + g.view.weaponStepRoll
  roll = roll - (Context.actor(g).crouch or 0) * P.crouchRoll
  -- Reload actions retain their clear silhouette while the hands keep weight.
  return clamp(x * grip, -P.reachX, P.reachX),
    clamp(y * grip, P.low, P.high),
    clamp(roll * grip, -P.reachRoll, P.reachRoll)
end
return M
