-- Presentation only: this module never changes the camera, aim, collision,
-- weapon clocks or ammunition. Units are pixels at the 450 px scene height.
local MathX = require('src.core.mathx')
local K = require('src.physics.kinematics')
local T = require('src.content.tuning')
local Impact = require('src.feedback.movement_impact')
local Weight = require('src.feedback.weight')
local Gait = require('src.player.movement_gait')
local Reload = require('src.combat.reload')
local M = {}
local sin, cos, pi = math.sin, math.cos, math.pi
local clamp = MathX.clamp
local angle = MathX.wrapAngle
local function ease(v, target, rate, dt)
  return target + (v - target) * math.exp(-rate * dt)
end
local function smooth(v)
  v = clamp(v, 0, 1)
  return v * v * (3 - 2 * v)
end
function M.grip(g)
  local left = Reload.left(g)
  if left <= 0 then
    return 1
  end
  -- Blend the hand brace on elapsed presentation time, including a resumed
  -- reload. The physical action still uses its unchanged absolute timeline.
  local elapsed = math.max(0, Reload.duration(g) - left)
  local brace = math.min(smooth(elapsed / 0.10), smooth(left / 0.12))
  return 1 - 0.52 * brace
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
    g.view[key] = 0
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
  local y, vy = K.spring(g.view.weaponStepY or 0, g.view.weaponStepVY or 0, 0, 520, 30, dt)
  local roll, vr = K.spring(g.view.weaponStepRoll or 0, g.view.weaponStepVRoll or 0, 0, 620, 38, dt)
  if steps > 0 and after > before then
    local last = math.floor(after / pi + 1e-9)
    local mass = Weight.carryFactor(g)
    -- A simulation hitch may cross several feet; at most the last four can
    -- contribute visible motion. The shared gait still counts every contact.
    for step = math.max(last - steps + 1, last - 3), last do
      local age = clamp(dt * (after - step * pi) / (after - before), 0, dt)
      local dy, dv = K.spring(0, (20 + 12 * load) * load * mass, 0, 520, 30, age)
      local dr, dvr = K.spring(0, (step % 2 == 0 and -1 or 1) * 0.13 * load * mass, 0, 620, 38, age)
      y, vy, roll, vr = y + dy, vy + dv, roll + dr, vr + dvr
    end
  end
  g.view.weaponStepY, g.view.weaponStepVY = clamp(y, -1.8, 1.8), clamp(vy, -55, 55)
  g.view.weaponStepRoll, g.view.weaponStepVRoll = clamp(roll, -0.008, 0.008), clamp(vr, -0.22, 0.22)
end
function M.update(g, dt, travelled, previousVX, previousVZ, landingImpact, plantedTravel)
  if type(dt) ~= 'number' or dt <= 0 or dt ~= dt or dt == math.huge then
    return
  end
  local p = g.player
  local planted = Gait.planted(p) and plantedTravel ~= false
  local before = g.view.gaitPhase or 0
  local footsteps = Gait.advance(g, travelled, planted)
  -- Accessibility affects decoration, not the physical footfall clock.
  if g.view.motion == false then
    M.init(g, true)
    return footsteps
  end
  local yaw, pitch = p.yaw, p.pitch or 0
  -- Integrate angular displacement, not one mouse-event magnitude or a noisy
  -- angular velocity. Packet frequency cannot accumulate a different target.
  local yawDelta = clamp(angle(yaw - (g.view.weaponLastYaw or yaw)), -0.25, 0.25)
  local pitchDelta = clamp(pitch - (g.view.weaponLastPitch or pitch), -0.20, 0.20)
  g.view.weaponLastYaw, g.view.weaponLastPitch = yaw, pitch
  -- Weapon mass (weapon_defs weight.aim): a heavier gun trails the turn
  -- further and settles on a softer spring. 1 = the light revolver.
  local aim = Weight.aimFactor(g)
  g.view.weaponAimVX = clamp((g.view.weaponAimVX or 0) - yawDelta * 480 / aim, -100, 100)
  g.view.weaponAimVY = clamp((g.view.weaponAimVY or 0) + pitchDelta * 390 / aim, -80, 80)
  g.view.weaponAimX, g.view.weaponAimVX =
    K.spring(g.view.weaponAimX or 0, g.view.weaponAimVX, 0, 196 * aim, 28 * math.sqrt(aim), dt)
  g.view.weaponAimY, g.view.weaponAimVY =
    K.spring(g.view.weaponAimY or 0, g.view.weaponAimVY, 0, 196 * aim, 28 * math.sqrt(aim), dt)
  g.view.weaponAimX = clamp(g.view.weaponAimX, -7, 7)
  g.view.weaponAimY = clamp(g.view.weaponAimY, -5, 5)
  local speed = math.max(0, travelled or 0) / dt
  local weight = planted and clamp(speed / T.moveSpeed, 0, 1.12) or 0
  contactSpring(g, dt, before, g.view.gaitPhase or before, footsteps, weight)
  g.view.weaponCarry = ease(g.view.weaponCarry or 0, weight, 12, dt)
  -- No walking-in-place against a wall, in the air, or through a dash.
  g.view.weaponStride = g.view.gaitPhase or 0
  g.view.weaponClock = (g.view.weaponClock or 0) + dt
  local ax, az = ((p.vx or 0) - (previousVX or 0)) / dt, ((p.vz or 0) - (previousVZ or 0)) / dt
  local side = ax * cos(yaw) - az * sin(yaw)
  local ahead = ax * sin(yaw) + az * cos(yaw)
  g.view.weaponLagX, g.view.weaponLagVX = K.spring(
    g.view.weaponLagX or 0,
    g.view.weaponLagVX or 0,
    clamp(-side * 0.075, -3.6, 3.6),
    110,
    17,
    dt
  )
  g.view.weaponLagY, g.view.weaponLagVY = K.spring(
    g.view.weaponLagY or 0,
    g.view.weaponLagVY or 0,
    clamp(ahead * 0.045, -2.5, 2.5),
    110,
    17,
    dt
  )
  local sideVelocity = ((p.vx or 0) * cos(yaw) - (p.vz or 0) * sin(yaw)) / T.moveSpeed
  g.view.weaponLean =
    ease(g.view.weaponLean or 0, clamp(-sideVelocity * 0.018, -0.022, 0.022), 10, dt)
  if landingImpact then
    local contact = type(landingImpact) == 'table' and landingImpact
      or Impact.landingMetrics(landingImpact)
    if contact then
      g.view.weaponDipV = (g.view.weaponDipV or 0) + contact.kick
    end
  end
  g.view.weaponDip, g.view.weaponDipV =
    K.spring(g.view.weaponDip or 0, g.view.weaponDipV or 0, 0, 196, 20, dt)
  -- On ascent the hands trail below the body, on descent they float above it.
  -- Vertical speed determines the offset; no fake walking in mid-air. The
  -- existing landing impulse remains authoritative when the feet touch down.
  local air = p.jump > 0 and clamp((p.jumpV or 0) * 0.30, -2.2, 2.2) * Weight.carryFactor(g) or 0
  g.view.weaponAirY, g.view.weaponAirVY =
    K.spring(g.view.weaponAirY or 0, g.view.weaponAirVY or 0, air, 120, 22, dt)
  g.view.weaponImpactX, g.view.weaponImpactVX =
    K.spring(g.view.weaponImpactX or 0, g.view.weaponImpactVX or 0, 0, 220, 23, dt)
  g.view.weaponImpactY, g.view.weaponImpactVY =
    K.spring(g.view.weaponImpactY or 0, g.view.weaponImpactVY or 0, 0, 220, 23, dt)
  g.view.weaponImpactRoll, g.view.weaponImpactVRoll =
    K.spring(g.view.weaponImpactRoll or 0, g.view.weaponImpactVRoll or 0, 0, 210, 24, dt)
  -- A broken guard (condition 'staggered') drops the gun out of the aim for
  -- the stagger itself: the helpless moment is unmistakable in the hands.
  local staggered = p.conditions and (p.conditions.staggered or 0) > 0 and 9 or 0
  local lowered = (p.dashTimer > 0 and 4 or 0) + (p.slideTimer > 0 and 5 or 0) + staggered
  g.view.weaponLower = ease(g.view.weaponLower or 0, lowered, 15, dt)
  return footsteps
end
function M.pose(g)
  if g.view.motion == false then
    return 0, 0, 0
  end
  local weight = g.view.weaponCarry or 0
  local phase = g.view.weaponStride or 0
  local mass = Weight.carryFactor(g)
  -- Alternating load transfer and the half-frequency foot plant describe a
  -- supported weight. Breathing recedes during travel, a shot and reloading.
  local grip = M.grip(g)
  local quiet = (1 - clamp(weight, 0, 1)) * (1 - 0.82 * (1 - grip) / 0.52)
  quiet = quiet * clamp(((g.view.shotAge or 10) - 0.16) / 0.35, 0, 1)
  local breath = sin((g.view.weaponClock or 0) * 1.48) * quiet
  local gaitX = sin(phase) * 4.8 * weight * mass
  local gaitY = (1 - cos(phase * 2)) * 1.55 * weight * mass
  local x = gaitX
    + (g.view.weaponAimX or 0)
    + (g.view.weaponLagX or 0)
    + (g.view.weaponImpactX or 0)
    + breath * 0.30
  local y = gaitY
    + (g.view.weaponAimY or 0)
    + (g.view.weaponLagY or 0)
    + (g.view.weaponDip or 0)
    + (g.view.weaponLower or 0)
    + (g.view.weaponImpactY or 0)
    + breath * 0.72
  y = y + (g.view.weaponStepY or 0) + (g.view.weaponAirY or 0)
  local roll = (g.view.weaponLean or 0)
    + sin(phase) * 0.0065 * weight * mass
    + (g.view.weaponAimX or 0) * 0.0012
    + (g.view.weaponImpactRoll or 0)
    + (g.view.weaponStepRoll or 0)
  roll = roll - (g.player.crouch or 0) * 0.045
  -- Reload actions retain their clear silhouette while the hands keep weight.
  return clamp(x * grip, -13, 13), clamp(y * grip, -8, 14), clamp(roll * grip, -0.04, 0.04)
end
return M
