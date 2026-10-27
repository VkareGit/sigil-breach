local MathX = require('src.core.mathx')
local W = require('src.world.arena')
local Presentation = require('src.session.presentation')
local T = require('src.content.tuning')
local Reload = require('src.combat.reload')
local K = require('src.physics.kinematics')
local Rules = require('src.combat.rules')
local Intent = require('src.player.intent')
local Context = require('src.session.context')
local F = {}
local M, C = T.motion, T.camera
local approach = MathX.approach
local spring = K.spring
local ViewState = require('src.session.view_state')
local clearCamera = ViewState.clearCamera
-- A setting change may happen twice while paused, with no simulation between.
-- Discard decoration now; never reset firing/reload clocks, jump, contact
-- latches, input intentions, physical gait or combat confirmation.
function F.clearMotion(g)
  clearCamera(g)
  Presentation.call(g, 'motion.clear')
  g.view.presentationPrevious = nil
  for id in pairs(Context.watched(g)) do
    local actor = require('src.session.world').get(g, id)
    if actor then
      local shown = Context.of(g, actor)
      clearCamera(shown)
      Presentation.call(shown, 'motion.clear')
      shown.view.presentationPrevious = nil
    end
  end
  for _, observer in ipairs(Context.observers(g)) do
    observer.state.presentationPrevious = nil
  end
end
-- Minimal springs for unobserved actors; watched actors use Context.view.
local bodyViews = setmetatable({}, { __mode = 'k' })
local function bodyView(p)
  local v = bodyViews[p]
  if not v then
    v = {
      recoil = 0,
      recoilV = 0,
      land = 0,
      landV = 0,
      swayX = 0,
      swayY = 0,
      shotAge = math.huge,
      swapAge = 1,
      fovKick = 0,
      bobWeight = 0,
      bank = 0,
      stepSound = 0,
    }
    bodyViews[p] = v
  end
  return v
end
F.initView = ViewState.init
function F.init(g)
  local p = g.player
  p.vx, p.vz = 0, 0
  require('src.content.weapons').rest(g)
  p.slideTimer, p.slideCooldown, p.slideAge, p.crouch = 0, 0, 0, 0
  g.impactSlow = 0
  g.playerDamageReport = nil
  p.reloadOffset, p.shotSequence, g.shotSerial = 0, 0, 0
  p.reloadStage, p.reloadDuration = 0, 0
  g.view.traces, g.view.surfaceMarks, g.view.corpses = {}, {}, {}
  g.view.effects, g.view.decals = {}, {}
  g.view.actors, g.view.observers = nil, nil
  g.view.motion = true
  F.initView(g)
  Intent.init(g)
end
-- actor: the knight that moves. Watched actors keep separate hands/camera
-- state; only the controlled actor produces local movement audio.
function F.update(g, dt, input, actor)
  if type(dt) ~= 'number' or dt <= 0 or dt ~= dt or dt == math.huge then
    return
  end
  local p = actor or g.player
  local controlled = p == g.player
  local personal = Context.view(g, p)
  local presented = personal ~= nil
  local shown = presented and Context.of(g, p) or nil
  local view = personal or bodyView(p)
  view.recoil, view.recoilV =
    spring(view.recoil, view.recoilV, 0, C.recoilSpring[1], C.recoilSpring[2], dt)
  view.land, view.landV = spring(view.land, view.landV, 0, C.landSpring[1], C.landSpring[2], dt)
  view.swayX = view.swayX * math.exp(-dt * C.swayDecay)
  view.swayY = view.swayY * math.exp(-dt * C.swayDecay)
  view.shotAge = view.shotAge + dt
  view.swapAge = math.min(1, view.swapAge + dt)
  if presented then
    Presentation.call(shown, 'motion.weight', dt)
  end
  view.fovKick = approach(view.fovKick, p.dashTimer > 0 and C.dashFov or 0, dt * C.dashFovRate)
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
    if controlled then
      Presentation.cue(g, 'slide', C.sounds.slide)
    end
    if presented then
      Presentation.call(shown, 'motion.slide')
    end
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
    g:dash(dx, dz, p)
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
  local slidX, slidZ, collided, supportLift, supportDrop =
    W.move(g.world, p, moveX, moveZ, Rules.playerBody().radius, p, Rules.tall(g, p))
  if g.world.elevations and g.frame then
    if controlled then
      g.frame.supportLift = supportLift or 0
    else
      g.frame.supportLifts = g.frame.supportLifts or {}
      g.frame.supportLifts[p.id] = supportLift or 0
    end
  end
  -- Shoved into a wall: the same slam rule as the demons (src/combat/rules.lua).
  -- The wall removes the normal part of the requested step; that is the
  -- speed the body loses against stone.
  if collided and pushSpeed > 0 then
    local blockedX, blockedZ = moveX - (slidX or 0), moveZ - (slidZ or 0)
    local lost = math.sqrt(blockedX * blockedX + blockedZ * blockedZ) / dt
    local over, recorded =
      Rules.slamPlayer(g, math.min(pushSpeed, lost), p.x + blockedX, p.z + blockedZ, p)
    if over > 0 then
      p.pushX, p.pushZ = 0, 0
      -- A damaging contact already sounds through the shared damage receipt.
      if controlled and not recorded then
        Presentation.cue(g, 'thud', C.sounds.thud)
      end
    end
  end
  -- Measure only the collision solver's velocity projection. In particular,
  -- a dash's normal exit-speed cap below must not masquerade as a wall hit.
  if presented then
    Presentation.call(
      shown,
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
  end
  if dashEnded then
    local speed = onGround and T.moveSpeed * M.exitShare or T.airMomentumCap
    local v = math.sqrt(p.vx * p.vx + p.vz * p.vz)
    if v > speed then
      p.vx, p.vz = p.vx / v * speed, p.vz / v * speed
    end
  end
  local travelled = math.sqrt((p.x - oldx) ^ 2 + (p.z - oldz) ^ 2)
  view.moving = travelled > M.moving
  if presented then
    shown.step = shown.step + travelled * C.steps
  end
  if p.slideTimer > 0 and math.sqrt(p.vx * p.vx + p.vz * p.vz) < 2 then
    p.slideTimer = 0
  end
  view.bobWeight = approach(
    view.bobWeight,
    view.moving and onGround and p.slideTimer == 0 and 1 or 0,
    dt * C.bobRate
  )
  -- Lean follows resolved travel, including collision response. A pressed
  -- strafe key against stone must not tilt an otherwise stationary view.
  local lateral = (p.vx * math.cos(p.yaw) - p.vz * math.sin(p.yaw)) / T.moveSpeed
  view.bank = approach(view.bank, -math.max(-1, math.min(1, lateral)) * C.bank, dt * C.bankRate)
  local jumped = Intent.jump(g, dt, input.jump, onGround, actor)
  if jumped then
    p.jumpV = T.jumpSpeed
    if presented then
      Presentation.call(shown, 'motion.takeoff', p.jumpV)
    end
    if p.slideTimer > 0 then
      p.slideTimer = 0
      -- Keep the slide's speed; the air cap absorbs the excess over time.
      p.airCap = math.sqrt(p.vx * p.vx + p.vz * p.vz)
    end
    if controlled then
      Presentation.cue(g, 'jump', C.sounds.jump)
    end
  end
  p.crouch = approach(
    p.crouch,
    p.slideTimer > 0 and M.crouch or 0,
    dt * (p.slideTimer > 0 and M.crouchDown or M.crouchUp)
  )
  local wasAir = p.jump > 0
  local impact
  local verticalTime = dt
  if supportDrop and onGround and not jumped then
    -- Motion during the fixed step is the resolved horizontal segment. Feet
    -- start falling when that path leaves support, not at the tick's start.
    verticalTime = dt * (1 - supportDrop)
  end
  p.jump, p.jumpV, impact = K.vertical(p.jump, p.jumpV, T.gravity, verticalTime)
  if g.world.decks then
    -- A deck overhead stops the rise (plan v10 V3).
    p.jump, p.jumpV = Rules.ceiling(g, p, p.jump, p.jumpV)
  end
  local landingImpact
  if p.jump == 0 then
    if wasAir then
      view.landV = math.max(-C.landDipMax, -math.abs(impact or 0) * C.landDip)
      if presented then
        landingImpact = Presentation.call(shown, 'motion.landing', impact)
        if controlled then
          Presentation.cue(
            g,
            'land',
            C.sounds.land + math.min(C.sounds.landMax, math.abs(impact or 0) * C.sounds.landGain)
          )
        end
      end
    end
    p.jumpV = 0
  end
  view.stepSound = math.max(0, (view.stepSound or 0) - dt)
  local footfalls = presented
    and Presentation.call(
      shown,
      'motion.weapon',
      dt,
      travelled,
      previousVX,
      previousVZ,
      landingImpact,
      plantedTravel
    )
  if controlled and footfalls and footfalls > 0 and view.stepSound == 0 then
    view.stepSound = C.stepEvery
    Presentation.cue(g, 'step', C.sounds.step)
  end
  -- The trails of the step's movement (feedback/movement_marks.lua).
  if presented then
    Presentation.call(shown, 'motion.marks', dt)
  end
end
function F.reloadUpdate(g, dt, actor)
  Reload.update(g, dt, actor)
end
return F
