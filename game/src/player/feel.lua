local Weapons = require('src.content.weapons')
local Arena = require('src.world.arena')
local Attributes = require('src.combat.attributes')
local MathX = require('src.core.mathx')
local Presentation = require('src.session.presentation')
local Tuning = require('src.content.tuning')
local Reload = require('src.combat.reload')
local Kinematics = require('src.physics.kinematics')
local Physics = require('src.physics.body_physics')
local Rules = require('src.combat.rules')
local Intent = require('src.player.intent')
local Context = require('src.session.context')
local F = {}
local M = Tuning.motion
local approach = MathX.approach
local ViewState = require('src.session.view_state')
function F.init(g)
  local p = g.player
  p.vx, p.vz = 0, 0
  Weapons.rest(g)
  p.slideTimer, p.slideCooldown, p.slideAge, p.crouch = 0, 0, 0, 0
  g.impactSlow = 0
  g.playerDamageReport = nil
  p.reloadOffset, p.shotSequence, g.shotSerial = 0, 0, 0
  p.reloadStage, p.reloadDuration = 0, 0
  ViewState.start(g)
  Intent.init(g)
end
-- actor: the knight that moves. The step publishes what happened to the body
-- at the moment it happens (session/presentation.lua hooks 'motion.*'): a
-- watched actor's camera, hands and sounds answer in feedback/motion.lua, and
-- the step itself writes no view field and chooses no sound (PLAN E3).
-- One step of one body, in the order it happens. The table is kept between steps: a body
-- steps at 120 Hz and never inside another's step.
local m = {}
-- Publish a fact of this step to the watched actor's presentation.
local function publish(name, ...)
  if m.presented then
    return Presentation.call(m.shown, name, ...)
  end
end
-- The turn, and where the keys point: m.dx, m.dz, m.len.
local function steer(input, dt)
  local p = m.p
  p.yaw = p.yaw + (input.turn or 0) * dt * M.turn
  local forward, strafe = input.forward or 0, input.strafe or 0
  local dx, dz =
    math.sin(p.yaw) * forward + math.cos(p.yaw) * strafe,
    math.cos(p.yaw) * forward - math.sin(p.yaw) * strafe
  local len = math.sqrt(dx * dx + dz * dz)
  if len > 1 then
    dx, dz = dx / len, dz / len
  end
  m.dx, m.dz, m.len = dx, dz, len
end
local function beginSlide(input, g, velocity)
  local p, Move = m.p, m.Move
  if
    input.slide
    and m.onGround
    and p.slideCooldown == 0
    and velocity > M.slideFrom
    and p.dashTimer == 0
  then
    p.slideX, p.slideZ = p.vx / velocity, p.vz / velocity
    p.slideTimer = Move.slideTime
    p.slideAge = 0
    p.slideCooldown = Move.slideCooldown
    publish('motion.slide')
  end
end
-- How fast the body wants to go this step.
local function wantedSpeed(g, velocity, dt)
  local p, Move, onGround = m.p, m.Move, m.onGround
  -- Conditions from the shared rules (stagger, wound) slow the body, not the aim.
  local condition = Rules.speedScale(p) * Arena.footing(g.world, p.x, p.z)
  -- Momentum above the air cap (a slide-jump) is not cut in one tick: the
  -- excess decays with air drag (half-life ~.43 s) toward the cap.
  if onGround then
    p.airCap = nil
  elseif p.airCap then
    p.airCap = Move.airMomentumCap + (p.airCap - Move.airMomentumCap) * math.exp(-M.airDecay * dt)
  end
  local airCap = math.max(Move.airMomentumCap, p.airCap or 0)
  local target = (
    onGround and Move.moveSpeed or math.max(Move.airSpeed, math.min(airCap, velocity))
  ) * condition
  -- A fight is not won by backing out of it: a knight steps aside a little slower
  -- and walks backwards slowly. A rule of his body, the same in every mode (E1).
  if onGround and m.len > M.input then
    local body = Rules.playerBody(p)
    -- The share of the step along the facing. Keys longer than one were already
    -- normalized (steer), so only a shorter (partial) input is divided by its length.
    local along = (m.dx * math.sin(p.yaw) + m.dz * math.cos(p.yaw)) / math.min(m.len, 1)
    target = target
      * (
        along < 0 and body.sideStep + (body.sideStep - body.backStep) * along
        or 1 - (1 - body.sideStep) * (1 - along)
      )
  end
  return target
end
-- Vector acceleration preserves equal cardinal / diagonal speed and avoids icy stops.
local function accelerate(target, dt)
  local p, Move, onGround = m.p, m.Move, m.onGround
  local accel = onGround and (m.len > M.input and Move.groundAccel or Move.groundBrake)
    or Move.airAccel
  m.moveX, m.moveZ = p.vx * dt, p.vz * dt
  if m.len > M.input or onGround then
    local ax, az = m.dx * target - p.vx, m.dz * target - p.vz
    local al = math.sqrt(ax * ax + az * az)
    if al > 0 then
      local active = math.min(dt, al / accel)
      local amount = accel * active
      local oldVX, oldVZ = p.vx, p.vz
      p.vx = p.vx + ax / al * amount
      p.vz = p.vz + az / al * amount
      m.moveX = (oldVX + p.vx) * 0.5 * active + p.vx * (dt - active)
      m.moveZ = (oldVZ + p.vz) * 0.5 * active + p.vz * (dt - active)
    end
  end
end
local function keepSliding(dt)
  local p, Move = m.p, m.Move
  if p.slideTimer > 0 then
    p.slideAge = p.slideAge + dt
    p.slideTimer = math.max(0, p.slideTimer - dt)
    local speed = math.max(Move.moveSpeed, Move.slideSpeed - p.slideAge * M.slideDecel)
    p.vx, p.vz = p.slideX * speed, p.slideZ * speed
    m.moveX, m.moveZ = p.vx * dt, p.vz * dt
    if m.len > M.input then
      local a = math.min(1, dt * M.slideSteer)
      local sx, sz = p.slideX * (1 - a) + m.dx * a, p.slideZ * (1 - a) + m.dz * a
      local sl = math.sqrt(sx * sx + sz * sz)
      if sl > M.input then
        p.slideX, p.slideZ = sx / sl, sz / sl
      end
    end
  end
end
-- The dash in progress; m.dashEnded when this step ended it.
local function keepDashing(dt)
  local p, Move = m.p, m.Move
  m.dashEnded = false
  if p.dashTimer > 0 then
    local active = math.min(dt, p.dashTimer)
    local exitSpeed = m.onGround and Move.moveSpeed * M.exitShare or Move.airMomentumCap
    p.vx, p.vz = p.dashX * Move.dashSpeed, p.dashZ * Move.dashSpeed
    m.moveX = p.dashX * (Move.dashSpeed * active + exitSpeed * (dt - active))
    m.moveZ = p.dashZ * (Move.dashSpeed * active + exitSpeed * (dt - active))
    p.dashTimer = math.max(0, p.dashTimer - dt)
    m.dashEnded = p.dashTimer == 0
  end
end
-- A blow shoves the body (rules: impact / mass); it decays on its own and
-- never replaces the player's own velocity or steering.
-- Feet on the ground brake a shove (drag 9/s); in the air it carries (3.5/s).
local function carryShove(dt)
  local p = m.p
  m.pushSpeed = 0
  if p.pushX and math.abs(p.pushX) + math.abs(p.pushZ or 0) > M.minPush then
    local body = Rules.playerBody(p)
    local drag = m.onGround and body.drag or body.airDrag
    -- Directional influence: steering against the shove brakes it (up to x1.8).
    local pushLength = math.sqrt(p.pushX * p.pushX + (p.pushZ or 0) ^ 2)
    if m.len > M.input and pushLength > 1e-6 then
      local against = -(m.dx * p.pushX + m.dz * (p.pushZ or 0)) / (pushLength * math.max(1, m.len))
      drag = drag * (1 + M.against * math.max(0, against))
    end
    -- The same shove under drag as every other body (physics/body_physics.lua).
    local decay, travel = Physics.drag(drag, dt)
    m.pushSpeed = math.sqrt(p.pushX * p.pushX + (p.pushZ or 0) ^ 2)
    m.moveX = m.moveX + p.pushX * travel
    m.moveZ = m.moveZ + (p.pushZ or 0) * travel
    p.pushX = p.pushX * decay
    p.pushZ = (p.pushZ or 0) * decay
  end
end
-- Shoved into a wall: the same slam rule as the demons (src/combat/rules.lua).
-- The wall removes the normal part of the requested step; that is the
-- speed the body loses against stone.
local function slam(g, slidX, slidZ, dt)
  local p = m.p
  local blockedX, blockedZ = m.moveX - (slidX or 0), m.moveZ - (slidZ or 0)
  local lost = math.sqrt(blockedX * blockedX + blockedZ * blockedZ) / dt
  local over, recorded =
    Rules.slamPlayer(g, math.min(m.pushSpeed, lost), p.x + blockedX, p.z + blockedZ, p)
  if over > 0 then
    p.pushX, p.pushZ = 0, 0
    -- recorded: a damaging contact, already heard through the damage receipt.
    publish('motion.slam', recorded)
  end
end
-- The step against the world. m.travelled and m.supportDrop say how it went.
local function travel(g, previousVX, previousVZ, dt)
  local p, Move, onGround = m.p, m.Move, m.onGround
  p.slamLock = math.max(0, (p.slamLock or 0) - dt)
  local oldx, oldz = p.x, p.z
  local contactVX, contactVZ = p.vx, p.vz
  local slidX, slidZ, collided, supportLift, supportDrop =
    Arena.move(g.world, p, m.moveX, m.moveZ, Rules.playerBody(p).radius, p, Rules.tall(g, p))
  m.supportDrop = supportDrop
  if g.world.elevations and g.frame then
    if m.controlled then
      g.frame.supportLift = supportLift or 0
    else
      g.frame.supportLifts = g.frame.supportLifts or {}
      g.frame.supportLifts[p.id] = supportLift or 0
    end
  end
  if collided and m.pushSpeed > 0 then
    slam(g, slidX, slidZ, dt)
  end
  -- Measure only the collision solver's velocity projection. In particular,
  -- a dash's normal exit-speed cap below must not masquerade as a wall hit.
  publish(
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
  if m.dashEnded then
    local speed = onGround and Move.moveSpeed * M.exitShare or Move.airMomentumCap
    local v = math.sqrt(p.vx * p.vx + p.vz * p.vz)
    if v > speed then
      p.vx, p.vz = p.vx / v * speed, p.vz / v * speed
    end
  end
  m.travelled = math.sqrt((p.x - oldx) ^ 2 + (p.z - oldz) ^ 2)
end
-- A slide too slow to carry on ends; then the resolved travel is published.
local function followTravel(dt)
  local p = m.p
  if p.slideTimer > 0 and math.sqrt(p.vx * p.vx + p.vz * p.vz) < 2 then
    p.slideTimer = 0
  end
  publish('motion.travel', dt, m.travelled, m.onGround)
end
local function jump(g, input, actor, dt)
  local p = m.p
  local jumped =
    Intent.jump(g, dt, input.jump and not Attributes.forbids(p, 'jump'), m.onGround, actor)
  if jumped then
    p.jumpV = m.Move.jumpSpeed
    publish('motion.takeoff', p.jumpV)
    if p.slideTimer > 0 then
      p.slideTimer = 0
      -- Keep the slide's speed; the air cap absorbs the excess over time.
      p.airCap = math.sqrt(p.vx * p.vx + p.vz * p.vz)
    end
  end
  return jumped
end
-- The vertical step and the landing.
local function fall(g, jumped, dt)
  local p = m.p
  local wasAir = p.jump > 0
  local impact
  local verticalTime = dt
  if m.supportDrop and m.onGround and not jumped then
    -- Motion during the fixed step is the resolved horizontal segment. Feet
    -- start falling when that path leaves support, not at the tick's start.
    verticalTime = dt * (1 - m.supportDrop)
  end
  p.jump, p.jumpV, impact = Kinematics.vertical(p.jump, p.jumpV, Tuning.gravity, verticalTime)
  if g.world.decks then
    -- A deck overhead stops the rise (plan v10 V3).
    p.jump, p.jumpV = Rules.ceiling(g, p, p.jump, p.jumpV)
  end
  if p.jump == 0 then
    if wasAir then
      publish('motion.landing', impact)
    end
    p.jumpV = 0
  end
end
function F.update(g, dt, input, actor)
  if type(dt) ~= 'number' or dt <= 0 or dt ~= dt or dt == math.huge then
    return
  end
  local p = actor or g.player
  local personal = Context.view(g, p)
  m.p, m.Move, m.controlled = p, Rules.movement(p), p == g.player
  m.presented = personal ~= nil
  m.shown = m.presented and Context.of(g, p) or nil
  publish('motion.settle', dt)
  steer(input, dt)
  m.onGround = p.jump <= 0
  local previousVX, previousVZ = p.vx, p.vz
  p.slideCooldown = math.max(0, p.slideCooldown - dt)
  local velocity = math.sqrt(p.vx * p.vx + p.vz * p.vz)
  beginSlide(input, g, velocity)
  accelerate(wantedSpeed(g, velocity, dt), dt)
  local planted = m.onGround and p.slideTimer == 0
  keepSliding(dt)
  Intent.dash(g, dt, input.dash, m.dx, m.dz, actor)
  planted = planted and p.dashTimer == 0
  keepDashing(dt)
  carryShove(dt)
  travel(g, previousVX, previousVZ, dt)
  followTravel(dt)
  local jumped = jump(g, input, actor, dt)
  p.crouch = approach(
    p.crouch,
    p.slideTimer > 0 and M.crouch or 0,
    dt * (p.slideTimer > 0 and M.crouchDown or M.crouchUp)
  )
  fall(g, jumped, dt)
  -- The step as a whole: how far the body went, and whether its feet were planted.
  publish('motion.step', dt, m.travelled, previousVX, previousVZ, planted)
end
function F.reloadUpdate(g, dt, actor)
  Reload.update(g, dt, actor)
end
return F
