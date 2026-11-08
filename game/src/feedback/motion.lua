-- The knight's movement as felt: the camera, weight, weapon motion, movement
-- impacts and movement sounds answer the facts player/feel.lua publishes at
-- fixed points of its step (session/presentation.lua). Pure presentation; the
-- movement is simulation.
local Presentation = require('src.session.presentation')
local WeaponMotion = require('src.feedback.weapon_motion')
local MovementImpact = require('src.feedback.movement_impact')
local Weight = require('src.feedback.weight')
local MovementMarks = require('src.feedback.movement_marks')
local Context = require('src.session.context')
local Pools = require('src.session.world')
local ViewState = require('src.session.view_state')
local Rules = require('src.combat.rules')
local Tuning = require('src.content.tuning')
local MathX = require('src.core.mathx')
local Kinematics = require('src.physics.kinematics')
local C = Tuning.camera
local approach, spring = MathX.approach, Kinematics.spring
local Motion = {}
function Motion.init(g)
  g.view.abilityCast, g.view.abilityVoice = nil, nil
  WeaponMotion.init(g)
  MovementImpact.init(g)
  Weight.init(g)
end
function Motion.clear(g)
  g.view.abilityCast, g.view.abilityVoice = nil, nil
  Weight.clearMotion(g)
  WeaponMotion.init(g, true)
end
-- What one step of the knight's body did, as the camera, the hands and the
-- sounds answer it (PLAN E3). The step publishes the facts at the moment they
-- happen (player/feel.lua); every reaction is computed here. Sounds are the
-- controlled knight's own; a watched knight is seen, not heard.
local function own(g)
  return Context.isControlled(g)
end
-- A landing measured in the hands, handed to the weapon motion of the same step.
local landed = setmetatable({}, { __mode = 'k' })
-- The start of a step: the camera's springs, and what fades on its own.
function Motion.settle(g, dt)
  local view, p = g.view, Context.actor(g)
  view.recoil, view.recoilV =
    spring(view.recoil, view.recoilV, 0, C.recoilSpring[1], C.recoilSpring[2], dt)
  view.land, view.landV = spring(view.land, view.landV, 0, C.landSpring[1], C.landSpring[2], dt)
  view.shotAge = view.shotAge + dt
  view.swapAge = math.min(1, view.swapAge + dt)
  Weight.update(g, dt)
  view.fovKick = approach(view.fovKick, p.dashTimer > 0 and C.dashFov or 0, dt * C.dashFovRate)
end
-- A slide begins.
function Motion.slide(g)
  if own(g) then
    Presentation.cue(g, 'slide', C.sounds.slide)
  end
  MovementMarks.slide(g)
end
-- A shove ended against stone; a damaging one is heard through its receipt.
function Motion.slam(g, recorded)
  if own(g) and not recorded then
    Presentation.cue(g, 'thud', C.sounds.thud)
  end
end
-- The resolved travel of the step: the view leans into it and bobs with it.
function Motion.travel(g, dt, travelled, onGround)
  local view, p = g.view, Context.actor(g)
  view.moving = travelled > Tuning.motion.moving
  g.step = g.step + travelled * C.steps
  view.bobWeight = approach(
    view.bobWeight,
    view.moving and onGround and p.slideTimer == 0 and 1 or 0,
    dt * C.bobRate
  )
  -- Lean follows resolved travel, including collision response. A pressed
  -- strafe key against stone must not tilt an otherwise stationary view.
  local lateral = (p.vx * math.cos(p.yaw) - p.vz * math.sin(p.yaw)) / Rules.movement(p).moveSpeed
  view.bank = approach(view.bank, -math.max(-1, math.min(1, lateral)) * C.bank, dt * C.bankRate)
end
-- A jump: the weapon dips, dust rings the boots.
function Motion.takeoff(g, speed)
  local measured = MovementImpact.takeoff(g, speed)
  MovementMarks.takeoff(g)
  if own(g) then
    Presentation.cue(g, 'jump', C.sounds.jump)
  end
  return measured
end
-- A landing at speed m/s: the view dips, the impact is measured (handed to
-- the weapon motion), its weight and the dust it raises.
function Motion.landing(g, impact)
  local view, speed = g.view, math.abs(impact or 0)
  view.landV = math.max(-C.landDipMax, -speed * C.landDip)
  local measured = MovementImpact.landing(g, impact or 0)
  Weight.landing(g, impact)
  MovementMarks.landing(g, impact)
  if own(g) then
    Presentation.cue(
      g,
      'land',
      C.sounds.land + math.min(C.sounds.landMax, speed * C.sounds.landGain)
    )
  end
  landed[view] = measured
  return measured
end
-- The end of a step: the hands carry the gun through it, a planted foot is
-- heard, the movement leaves its marks.
function Motion.step(g, dt, travelled, previousVX, previousVZ, planted)
  local view = g.view
  local landing = landed[view]
  landed[view] = nil
  view.stepSound = math.max(0, view.stepSound - dt)
  local steps = WeaponMotion.update(g, dt, travelled, previousVX, previousVZ, landing, planted)
  if own(g) and steps and steps > 0 and view.stepSound == 0 then
    view.stepSound = C.stepEvery
    Presentation.cue(g, 'step', C.sounds.step)
  end
  MovementMarks.update(g, dt)
end
-- What the knight cannot do now: said where the eyes are, and heard once a
-- moment however long the key is held. The hands reloading already sound
-- like what they are doing, and a dodge waiting out a shot goes a moment
-- later: neither is a refusal to thud.
function Motion.refused(g, reason)
  local view, Input = g.view, Tuning.input
  if view.refusalTimer <= 0 and reason ~= 'hud_reloading' and reason ~= 'hud_recovering' then
    Presentation.cue(g, 'thud', Input.refusalVolume)
  end
  view.refusal, view.refusalTimer = reason, Input.refusalTime
end
-- MOTION turned off (app/commands.lua): a setting change may happen twice
-- while paused, with no simulation between. Discard decoration now; never
-- reset firing/reload clocks, jump, contact latches, input intentions,
-- physical gait or combat confirmation.
function Motion.clearAll(g)
  ViewState.clearCamera(g)
  Motion.clear(g)
  g.view.presentationPrevious = nil
  for id in pairs(Context.watched(g)) do
    local actor = Pools.get(g, id)
    if actor then
      local shown = Context.of(g, actor)
      ViewState.clearCamera(shown)
      Motion.clear(shown)
      shown.view.presentationPrevious = nil
    end
  end
  for _, observer in ipairs(Context.observers(g)) do
    observer.state.presentationPrevious = nil
  end
end
Presentation.hook('motion.init', Motion.init)
Presentation.hook('motion.clear', Motion.clear)
Presentation.hook('motion.settle', Motion.settle)
Presentation.hook('motion.slide', Motion.slide)
Presentation.hook('motion.slam', Motion.slam)
Presentation.hook('motion.wall', MovementImpact.wall)
Presentation.hook('motion.travel', Motion.travel)
Presentation.hook('motion.takeoff', Motion.takeoff)
Presentation.hook('motion.landing', Motion.landing)
Presentation.hook('motion.step', Motion.step)
Presentation.hook('knight.refused', Motion.refused)
return Motion
