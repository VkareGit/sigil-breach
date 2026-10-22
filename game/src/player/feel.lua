local MathX = require('src.core.mathx')
local W = require('src.world.arena')
local Presentation = require('src.session.presentation')
local T = require('src.content.tuning')
local Reload = require('src.combat.reload')
local K = require('src.physics.kinematics')
local Rules = require('src.combat.rules')
local Intent = require('src.player.intent')
local F = {}
local M, C = T.motion, T.camera
local approach = MathX.approach
local spring = K.spring
local cameraKeys = {
  'recoil',
  'recoilV',
  'swayX',
  'swayY',
  'bank',
  'fovKick',
  'land',
  'landV',
  'bobWeight',
  'shake',
}
local function clearCamera(g)
  for _, key in ipairs(cameraKeys) do
    g.view[key] = 0
  end
end
-- A setting change may happen twice while paused, with no simulation between.
-- Discard decoration now; never reset firing/reload clocks, jump, contact
-- latches, input intentions, physical gait or combat confirmation.
function F.clearMotion(g)
  clearCamera(g)
  Presentation.call(g, 'motion.clear')
  g.view.presentationPrevious = nil
end
function F.init(g)
  local p = g.player
  p.vx, p.vz = 0, 0
  require('src.content.weapons').rest(g)
  p.slideTimer, p.slideCooldown, p.slideAge, p.crouch = 0, 0, 0, 0
  clearCamera(g)
  g.view.shotAge, g.view.swapAge, g.impactSlow, g.view.stepSound = 10, 1, 0, 0
  g.view.shotReport = nil
  g.playerDamageReport = nil
  g.view.precisionHit = false
  g.view.hitWeight = 0
  g.view.shotPower = 1
  g.reloadOffset = 0
  g.shotSerial = 0
  g.reloadStage = 0
  g.reloadDuration = 0
  g.view.lastDamage = 0
  g.view.lastKill = false
  g.view.traces = {}
  g.view.surfaceMarks = {}
  g.view.corpses = {}
  g.view.shells = {}
  g.view.effects = {}
  g.view.decals = {}
  g.view.motion = true
  g.view.flashColor = { 1, 0.45, 0.12 }
  Presentation.call(g, 'motion.init')
  Intent.init(g)
end
function F.update(g, dt, input)
  if type(dt) ~= 'number' or dt <= 0 or dt ~= dt or dt == math.huge then
    return
  end
  local p = g.player
  g.view.recoil, g.view.recoilV =
    spring(g.view.recoil, g.view.recoilV, 0, C.recoilSpring[1], C.recoilSpring[2], dt)
  g.view.land, g.view.landV =
    spring(g.view.land, g.view.landV, 0, C.landSpring[1], C.landSpring[2], dt)
  g.view.swayX = g.view.swayX * math.exp(-dt * C.swayDecay)
  g.view.swayY = g.view.swayY * math.exp(-dt * C.swayDecay)
  g.view.shotAge = g.view.shotAge + dt
  g.view.swapAge = math.min(1, g.view.swapAge + dt)
  Presentation.call(g, 'motion.weight', dt)
  g.view.fovKick = approach(g.view.fovKick, p.dashTimer > 0 and C.dashFov or 0, dt * C.dashFovRate)
  p.yaw = p.yaw + (input.turn or 0) * dt * M.turn
  local forward, strafe = input.forward or 0, input.strafe or 0
  local dx, dz =
    math.sin(p.yaw) * forward + math.cos(p.yaw) * strafe,
    math.cos(p.yaw) * forward - math.sin(p.yaw) * strafe
  local len = math.sqrt(dx * dx + dz * dz)
  if len > 1 then
    dx, dz = dx / len, dz / len
  end
  local onGround = p.jump <= 0
  local previousVX, previousVZ = p.vx, p.vz
  p.slideCooldown = math.max(0, p.slideCooldown - dt)
  local velocity = math.sqrt(p.vx * p.vx + p.vz * p.vz)
  if
    input.slide
    and onGround
    and p.slideCooldown == 0
    and velocity > M.slideFrom
    and p.dashTimer == 0
  then
    p.slideX, p.slideZ = p.vx / velocity, p.vz / velocity
    p.slideTimer = T.slideTime
    p.slideAge = 0
    p.slideCooldown = T.slideCooldown
    Presentation.cue(g, 'slide', C.sounds.slide)
  end
  -- Conditions from the shared rules (stagger, wound) slow the body, not the aim.
  local condition = Rules.speedScale(p)
  -- Momentum above the air cap (a slide-jump) is not cut in one tick: the
  -- excess decays with air drag (half-life ~.43 s) toward the cap.
  if onGround then
    p.airCap = nil
  elseif p.airCap then
    p.airCap = T.airMomentumCap + (p.airCap - T.airMomentumCap) * math.exp(-M.airDecay * dt)
  end
  local airCap = math.max(T.airMomentumCap, p.airCap or 0)
  local targetSpeed = (onGround and T.moveSpeed or math.max(T.airSpeed, math.min(airCap, velocity)))
    * condition
  local accel = onGround and (len > M.input and T.groundAccel or T.groundBrake) or T.airAccel
  local moveX, moveZ = p.vx * dt, p.vz * dt
  -- Vector acceleration preserves equal cardinal / diagonal speed and avoids icy stops.
  if len > M.input or onGround then
    local ax, az = dx * targetSpeed - p.vx, dz * targetSpeed - p.vz
    local al = math.sqrt(ax * ax + az * az)
    if al > 0 then
      local active = math.min(dt, al / accel)
      local amount = accel * active
      local oldVX, oldVZ = p.vx, p.vz
      p.vx = p.vx + ax / al * amount
      p.vz = p.vz + az / al * amount
      moveX = (oldVX + p.vx) * 0.5 * active + p.vx * (dt - active)
      moveZ = (oldVZ + p.vz) * 0.5 * active + p.vz * (dt - active)
    end
  end
  local plantedTravel = onGround and p.slideTimer == 0
  if p.slideTimer > 0 then
    p.slideAge = p.slideAge + dt
    p.slideTimer = math.max(0, p.slideTimer - dt)
    local speed = math.max(T.moveSpeed, T.slideSpeed - p.slideAge * M.slideDecel)
    p.vx, p.vz = p.slideX * speed, p.slideZ * speed
    moveX, moveZ = p.vx * dt, p.vz * dt
    if len > M.input then
      local a = math.min(1, dt * M.slideSteer)
      local sx, sz = p.slideX * (1 - a) + dx * a, p.slideZ * (1 - a) + dz * a
      local sl = math.sqrt(sx * sx + sz * sz)
      if sl > M.input then
        p.slideX, p.slideZ = sx / sl, sz / sl
      end
    end
  end
  if input.dash then
    g:dash(dx, dz)
  end
  plantedTravel = plantedTravel and p.dashTimer == 0
  local dashEnded = false
  if p.dashTimer > 0 then
    local active = math.min(dt, p.dashTimer)
    local exitSpeed = onGround and T.moveSpeed * M.exitShare or T.airMomentumCap
    p.vx, p.vz = p.dashX * T.dashSpeed, p.dashZ * T.dashSpeed
    moveX = p.dashX * (T.dashSpeed * active + exitSpeed * (dt - active))
    moveZ = p.dashZ * (T.dashSpeed * active + exitSpeed * (dt - active))
    p.dashTimer = math.max(0, p.dashTimer - dt)
    dashEnded = p.dashTimer == 0
  end
  -- A blow shoves the body (rules: impact / mass); it decays on its own and
  -- never replaces the player's own velocity or steering.
  -- Feet on the ground brake a shove (drag 9/s); in the air it carries (3.5/s).
  local pushSpeed = 0
  if p.pushX and math.abs(p.pushX) + math.abs(p.pushZ or 0) > M.minPush then
    local body = Rules.playerBody()
    local drag = onGround and body.drag or body.airDrag
    -- Directional influence: steering against the shove brakes it (up to x1.8).
    local pushLength = math.sqrt(p.pushX * p.pushX + (p.pushZ or 0) ^ 2)
    if len > M.input and pushLength > 1e-6 then
      local against = -(dx * p.pushX + dz * (p.pushZ or 0)) / (pushLength * math.max(1, len))
      drag = drag * (1 + M.against * math.max(0, against))
    end
    local decay = math.exp(-drag * dt)
    local travel = (1 - decay) / drag
    pushSpeed = math.sqrt(p.pushX * p.pushX + (p.pushZ or 0) ^ 2)
    moveX = moveX + p.pushX * travel
    moveZ = moveZ + (p.pushZ or 0) * travel
    p.pushX = p.pushX * decay
    p.pushZ = (p.pushZ or 0) * decay
  end
  p.slamLock = math.max(0, (p.slamLock or 0) - dt)
  local oldx, oldz = p.x, p.z
  local contactVX, contactVZ = p.vx, p.vz
  local slidX, slidZ, collided = W.move(g.world, p, moveX, moveZ, Rules.playerBody().radius, p)
  -- Shoved into a wall: the same slam rule as the demons (src/combat/rules.lua).
  -- The wall removes the normal part of the requested step; that is the
  -- speed the body loses against stone.
  if collided and pushSpeed > 0 then
    local blockedX, blockedZ = moveX - (slidX or 0), moveZ - (slidZ or 0)
    local lost = math.sqrt(blockedX * blockedX + blockedZ * blockedZ) / dt
    local over, recorded =
      Rules.slamPlayer(g, math.min(pushSpeed, lost), p.x + blockedX, p.z + blockedZ)
    if over > 0 then
      p.pushX, p.pushZ = 0, 0
      -- A damaging contact already sounds through the shared damage receipt.
      if not recorded then
        Presentation.cue(g, 'thud', C.sounds.thud)
      end
    end
  end
  -- Measure only the collision solver's velocity projection. In particular,
  -- a dash's normal exit-speed cap below must not masquerade as a wall hit.
  Presentation.call(
    g,
    'motion.wall',
    collided,
    contactVX,
    contactVZ,
    p.vx,
    p.vz,
    oldx,
    oldz,
    previousVX,
    previousVZ
  )
  if dashEnded then
    local speed = onGround and T.moveSpeed * M.exitShare or T.airMomentumCap
    local v = math.sqrt(p.vx * p.vx + p.vz * p.vz)
    if v > speed then
      p.vx, p.vz = p.vx / v * speed, p.vz / v * speed
    end
  end
  local travelled = math.sqrt((p.x - oldx) ^ 2 + (p.z - oldz) ^ 2)
  g.view.moving = travelled > M.moving
  g.step = g.step + travelled * C.steps
  if p.slideTimer > 0 and math.sqrt(p.vx * p.vx + p.vz * p.vz) < 2 then
    p.slideTimer = 0
  end
  g.view.bobWeight = approach(
    g.view.bobWeight,
    g.view.moving and onGround and p.slideTimer == 0 and 1 or 0,
    dt * C.bobRate
  )
  -- Lean follows resolved travel, including collision response. A pressed
  -- strafe key against stone must not tilt an otherwise stationary view.
  local lateral = (p.vx * math.cos(p.yaw) - p.vz * math.sin(p.yaw)) / T.moveSpeed
  g.view.bank = approach(g.view.bank, -math.max(-1, math.min(1, lateral)) * C.bank, dt * C.bankRate)
  if Intent.jump(g, dt, input.jump, onGround) then
    p.jumpV = T.jumpSpeed
    Presentation.call(g, 'motion.takeoff', p.jumpV)
    if p.slideTimer > 0 then
      p.slideTimer = 0
      -- Keep the slide's speed; the air cap absorbs the excess over time.
      p.airCap = math.sqrt(p.vx * p.vx + p.vz * p.vz)
    end
    Presentation.cue(g, 'jump', C.sounds.jump)
  end
  p.crouch = approach(
    p.crouch,
    p.slideTimer > 0 and M.crouch or 0,
    dt * (p.slideTimer > 0 and M.crouchDown or M.crouchUp)
  )
  local wasAir = p.jump > 0
  local impact
  p.jump, p.jumpV, impact = K.vertical(p.jump, p.jumpV, T.gravity, dt)
  local landingImpact
  if p.jump == 0 then
    if wasAir then
      g.view.landV = math.max(-C.landDipMax, -math.abs(impact or 0) * C.landDip)
      landingImpact = Presentation.call(g, 'motion.landing', impact)
      Presentation.cue(
        g,
        'land',
        C.sounds.land + math.min(C.sounds.landMax, math.abs(impact or 0) * C.sounds.landGain)
      )
    end
    p.jumpV = 0
  end
  g.view.stepSound = math.max(0, (g.view.stepSound or 0) - dt)
  local footfalls = Presentation.call(
    g,
    'motion.weapon',
    dt,
    travelled,
    previousVX,
    previousVZ,
    landingImpact,
    plantedTravel
  )
  if footfalls and footfalls > 0 and g.view.stepSound == 0 then
    g.view.stepSound = C.stepEvery
    Presentation.cue(g, 'step', C.sounds.step)
  end
end
function F.reloadUpdate(g, dt)
  Reload.update(g, dt)
end
return F
