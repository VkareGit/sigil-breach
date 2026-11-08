local Impulses = require('src.feedback.impulses')
local Tuning = require('src.content.tuning')
local Characters = require('src.content.characters')
local DamageTypes = require('src.content.damage_types')
local Context = require('src.session.context')
-- WEIGHT: the rules of the world made felt. Presentation only: nothing here
-- moves the firing ray, ammunition, clocks or damage. Every magnitude comes
-- from the numbers the rules already used (impact, mass, damage, guard), so
-- a heavier blow always LOOKS, SOUNDS and SHAKES heavier, for the player and
-- for the demons alike. Written description: SYSTEM-SWIATA-0.14.txt §12.
local MathX = require('src.core.mathx')
local Kinematics = require('src.physics.kinematics')
local Audio = require('src.audio.audio')
local Weapons = require('src.content.weapons')
local Text = require('src.content.text')
local Lessons = require('src.feedback.lessons')
local Rate = require('src.core.rate')
local Fields = require('src.session.fields')
local W = {}
local sin, cos, atan2, sqrt, min, max, abs, pi =
  math.sin, math.cos, math.atan2, math.sqrt, math.min, math.max, math.abs, math.pi
local clamp = MathX.clamp
local angle = MathX.wrapAngle
local K = Tuning.weight
local guardColor = K.marks.guard
local camera = Tuning.camera
local hands = camera.hands
-- The view kick is critically damped at its weapon's rate: its peak is
-- viewKick at 1/rate s.
local function aimSpring(rate)
  return { rate * rate, 2 * rate }
end
local function addMark(g, mark)
  local marks = g.view.hurtMarks or {}
  g.view.hurtMarks = marks
  if #marks >= K.marks.most then
    table.remove(marks, 1)
  end
  marks[#marks + 1] = mark
end
-- Cosmetic state has one lifecycle. Disabling motion must discard impulses,
-- not merely hide them until the player turns the setting on again.
local motionKeys = {
  'rollPunch',
  'rollPunchV',
  'viewPunch',
  'viewPunchV',
  'kickBack',
  'kickBackV',
  'kickFlip',
  'weaponShotRoll',
  'weaponShotRollV',
  'aimKick',
  'aimKickV',
}
function W.clearMotion(g)
  for _, key in ipairs(motionKeys) do
    g.view[key] = Fields.viewStarts[key]
  end
end
function W.init(g)
  W.clearMotion(g)
  for _, key in ipairs({ 'rollSide', 'breakConfirm', 'heartTimer', 'heartbeats' }) do
    g.view[key] = Fields.viewStarts[key]
  end
  g.view.hurtMarks = {}
end
-- One colour per damage type (content/damage_types.lua), shared by projectiles,
-- pools, the player's hit markers and incoming-hit arcs.
function W.typeColor(kind)
  local def = DamageTypes.entries[kind or DamageTypes.fallback]
  return (def or DamageTypes.entries[DamageTypes.fallback]).color
end
-- Direction of a world point seen from the player: 0 ahead, +pi/2 right.
function W.relative(p, x, z)
  return angle(atan2(x - p.x, z - p.z) - (p.yaw or 0))
end
-- The spring that catches the shove along the barrels: the weapon's own
-- (weight.backK, weight.backD), else the shared one.
function W.backSpring(w)
  local shared = hands.kickBack
  return { w.backK or shared[1], w.backD or shared[2], limits = shared.limits }
end
-- The shot: recoil impulse = discharge momentum * power / weapon mass.
function W.shot(g, profile, power)
  local w = profile.weight
  power = power or 1
  local kick = w.momentum * power / w.mass
  -- Every impulse of the shot is given at the start of its step, so the
  -- camera and the hands move in the frame its flash shows (PLAN E5).
  local age = Rate.step
  Impulses.kick(g.view, 'recoil', kick, camera.recoilSpring, age)
  g.view.shotAge = age
  g.view.interruptedClose = nil
  g.view.fovKick = w.fov * power
  g.view.rollSide = -g.view.rollSide
  if g.view.motion ~= false then
    Impulses.kick(g.view, 'rollPunch', g.view.rollSide * w.roll * kick, hands.rollPunch, age)
    -- The hands rise and move back, then settle past rest once.
    -- Body punch moves the hands without changing the authoritative shot.
    Impulses.kick(g.view, 'viewPunch', (w.punch or 0) * kick, hands.viewPunch, age)
    Impulses.kick(g.view, 'kickBack', (w.back or 0) * kick, W.backSpring(w), age)
    g.view.kickFlip = w.flip or 0
    -- A single, damped wrist catch, with a consistent firing-hand direction.
    -- It is driven by the same momentum as the axial shove, never by RNG.
    Impulses.kick(g.view, 'weaponShotRoll', -(w.wrist or 0) * kick, { w.wristK, w.wristD }, age)
    g.view.weaponShotRollV = clamp(g.view.weaponShotRollV, -3, 3)
    -- The view climbs (0.26 G6). A fast weapon swap can fire while it
    -- settles; render/camera.lua projects the unchanged firing ray into the HUD.
    g.view.aimKickRate = w.viewKickRate
    Impulses.kick(
      g.view,
      'aimKick',
      w.viewKick * power * w.viewKickRate * math.exp(1),
      aimSpring(w.viewKickRate),
      age
    )
  end
  -- A recorded shot carries its own hall and thump (0.43, D02: audio/audio.lua baked).
  local baked = Audio.baked and Audio.baked(profile.fire.sound)
  if w.tail and not baked then
    Audio.play('hall', w.tail * (K.shotSound.base + K.shotSound.gain * power))
  end
  -- The gut of the report: a low thump under it.
  if (w.thump or 0) > 0 and not baked then
    Audio.play('thud', w.thump * (K.shotSound.base + K.shotSound.gain * power))
  end
  return kick
end
-- Aim inertia of the carried weapon (1 = light revolver, lower = heavier).
function W.aimFactor(g)
  local profile = (
    Weapons.inHand(g, nil, Context.actor(g)) or Weapons.profile(1, g, Context.actor(g))
  )
  return profile and profile.weight and profile.weight.aim or 1
end
function W.carryFactor(g)
  local profile = (
    Weapons.inHand(g, nil, Context.actor(g)) or Weapons.profile(1, g, Context.actor(g))
  )
  return profile and profile.weight and profile.weight.carry or 1
end
-- Severity of a blow against the player: 1 = it breaks a fresh guard.
function W.severity(impact, actor)
  return clamp((impact or 0) / Characters.of(actor).body.poise, 0, K.severityMax)
end
-- The player is struck. info: amount, lost, absorbed, impact, damageType,
-- x/z (source), staggered, wounded.
function W.playerHit(g, info)
  local p = Context.actor(g)
  local severity = W.severity(info.impact, p)
  local harm = clamp((info.amount or 0) / K.harmAt, 0, 1)
  local rel = info.x and W.relative(p, info.x, info.z) or 0
  -- The hands take the blow first, the frame shakes by the shove, not by the
  -- damage (content/view_reactions.lua: blow).
  Impulses.react(g.view, 'blow', severity, sin(rel), cos(rel))
  local shield = (info.absorbed or 0) > (info.lost or 0)
  addMark(g, {
    angle = atan2(info.x and info.x - p.x or sin(p.yaw), info.z and info.z - p.z or cos(p.yaw)),
    harm = harm,
    severity = min(1, severity),
    color = shield and guardColor or W.typeColor(info.damageType),
    age = 0,
    life = K.marks.life + K.marks.lifeHarm * harm,
    staggered = info.staggered,
  })
  Audio.play('hurt', K.hurt.base + K.hurt.gain * harm)
  if severity >= K.thudFrom or info.source == 'wall' then
    Audio.play('thud', K.thud.base + K.thud.gain * min(1, severity))
  end
  if (info.absorbed or 0) > 0 then
    Audio.play('shell', K.shell.base + K.shell.gain * clamp(info.absorbed / K.shell.at, 0, 1))
  end
  -- A broken guard: the world's hit-stop is simulation (session/listeners.lua);
  -- here only its sound.
  if info.staggered then
    -- The player's own guard breaking sounds like a demon's, lower and heavier.
    local s = Audio.play('break', K.guardBreak.volume)
    if s then
      s:setPitch(K.guardBreak.pitch)
    end
  end
end
-- A projectile passed close without touching: the player hears and sees it.
function W.nearMiss(g, b, distance)
  local p = Context.actor(g)
  if type(p.yaw) ~= 'number' then
    return
  end
  local packet = b.packet or {}
  local severity = W.severity(packet.impact or (b.big and K.missImpactBig or K.missImpact), p)
  if Audio.playAt then
    local whoosh = K.whoosh
    local fade = 1 - distance / whoosh.reach
    Audio.playAt('whoosh', b.x, b.z, p, whoosh.base + whoosh.gain * min(1, severity) * fade)
  end
  addMark(g, {
    angle = atan2(b.x - p.x, b.z - p.z),
    harm = 0,
    severity = K.marks.missSeverity,
    color = W.typeColor(packet.damageType),
    age = 0,
    life = K.marks.missLife,
    miss = true,
  })
end
-- A hit landed on a demon: what the shooter needs to know, in one beat.
-- result: the table returned by Rules.react (staggered, wounded, slam).
function W.confirm(g, report, results, hit, hitVolume)
  local broke, wounded, counter, crippled, falter, tripped =
    false, false, false, false, false, false
  local heavy, stopped = false, false
  for _, r in ipairs(results or {}) do
    broke = broke or r.staggered
    wounded = wounded or r.wounded
    counter = counter or r.counter
    crippled = crippled or r.crippled
    falter = falter or r.falter
    tripped = tripped or r.tripped
    heavy = heavy or (r.staggered and r.heavy)
    stopped = stopped or r.stopped
  end
  -- One voice to a volley, the most important that holds: a pile of sounds says less than one.
  -- A kill speaks for itself (feedback/listeners.lua). The hit is the least of them.
  local voice, volume, rank = hit, hitVolume, 1
  local function say(importance, name, level)
    if importance > rank then
      voice, volume, rank = name, level, importance
    end
  end
  -- Name the rule that just fired, once, unless a kill already speaks.
  local killed = report and (report.kills or 0) > 0
  if falter then
    g.view.feedback, g.view.feedbackTimer = Text.get('feedback_falter'), K.falter.caption
    say(4, 'break', K.falter.volume)
    Impulses.react(g.view, 'falter')
  elseif not killed and stopped then
    -- 0.24: the blow reversed a rush; the body goes down.
    g.view.feedback, g.view.feedbackTimer = Text.get('feedback_knocked'), K.knocked.caption
    say(3, 'thud', K.knocked.volume)
    Impulses.react(g.view, 'knocked')
  elseif not killed and tripped then
    g.view.feedback, g.view.feedbackTimer = Text.get('feedback_tripped'), K.tripped.caption
    say(3, 'thud', K.tripped.volume)
    Impulses.react(g.view, 'tripped')
  elseif not killed and counter then
    g.view.feedback, g.view.feedbackTimer = Text.get('feedback_counter'), K.counter.caption
    say(3, 'crit', K.counter.volume)
  elseif not killed and crippled then
    g.view.feedback, g.view.feedbackTimer = Text.get('feedback_crippled'), K.crippled.caption
  end
  g.view.breakConfirm = broke and K.breakConfirm or g.view.breakConfirm
  if broke then
    Lessons.note(g.view, 'guard')
    say(4, 'break', K.broke.base + K.broke.gain * g.view.hitWeight)
  end
  -- A heavy stagger lands with weight: a body blow and a short frame punch;
  -- a light falter keeps only the crack of the broken guard.
  if heavy and not killed then
    say(3, 'thud', K.heavyVolume)
    Impulses.react(g.view, 'heavyStagger')
  end
  if wounded or (counter and broke) then
    -- The player caused the decisive blow: a short frame punch (post shader
    -- 'kill' pulse) and a small view rise, presentation only.
    say(3, 'heavyhit', K.decisiveVolume)
    Impulses.react(g.view, 'decisive')
  end
  if crippled then
    say(3, 'thud', K.crippled.volume)
  end
  if
    report
    and report.headHits > 0
    and (not report.strong or report.headHits * 4 >= report.pelletsHit)
  then
    say(2, 'hit_head', K.headVolume)
  end
  if voice and not killed then
    Audio.play(voice, volume)
  end
end
function W.update(g, dt)
  if type(dt) ~= 'number' or dt <= 0 or dt >= math.huge or dt ~= dt then
    return
  end
  if g.view.motion == false then
    W.clearMotion(g)
  else
    local w = (Weapons.inHand(g, nil, Context.actor(g)) or Weapons.profile(1, g, Context.actor(g))).weight
    for key, spring in pairs(hands) do
      spring = key == 'kickBack' and W.backSpring(w) or spring
      local rate = key .. 'V'
      g.view[key], g.view[rate] =
        Kinematics.spring(g.view[key], g.view[rate], 0, spring[1], spring[2], dt)
      g.view[key] = clamp(g.view[key], spring.limits[1], spring.limits[2])
    end
    local kick = aimSpring(g.view.aimKickRate)
    g.view.aimKick, g.view.aimKickV =
      Kinematics.spring(g.view.aimKick, g.view.aimKickV, 0, kick[1], kick[2], dt)
    g.view.weaponShotRoll, g.view.weaponShotRollV =
      Kinematics.spring(g.view.weaponShotRoll, g.view.weaponShotRollV, 0, w.wristK, w.wristD, dt)
    local limit = w.wristLimit
    if math.abs(g.view.weaponShotRoll) > limit then
      g.view.weaponShotRoll = clamp(g.view.weaponShotRoll, -limit, limit)
      -- Discard only velocity still pushing against the wrist's limit.
      if g.view.weaponShotRoll * g.view.weaponShotRollV > 0 then
        g.view.weaponShotRollV = 0
      end
    end
  end
  W.heart(g, dt)
  g.view.breakConfirm = max(0, g.view.breakConfirm - dt)
  local marks = g.view.hurtMarks
  if marks then
    for i = #marks, 1, -1 do
      local m = marks[i]
      m.age = m.age + dt
      if m.age >= m.life then
        table.remove(marks, i)
      end
    end
  end
end
-- The hero's own body: below 30 HP the heart is heard, faster as it fails.
function W.heart(g, dt)
  local p = Context.actor(g)
  if not p or g.state ~= 'playing' or not Characters.low(p) or (p.hp or 0) <= 0 then
    g.view.heartTimer = 0
    return
  end
  g.view.heartTimer = g.view.heartTimer - dt
  if g.view.heartTimer <= 0 then
    local fear = 1 - Characters.share(p) / Tuning.lowHealth
    local period = K.heart.period - K.heart.faster * fear
    local beats = 1 + math.floor(-g.view.heartTimer / period)
    -- Preserve the remainder like the planted footfall clock. Low frame rates
    -- must not silently lengthen the physical pulse; a hitch plays one cue.
    g.view.heartTimer = g.view.heartTimer + beats * period
    if Context.isControlled(g, p) then
      Audio.play('heart', K.heart.base + K.heart.gain * fear)
    end
    g.view.heartbeats = g.view.heartbeats + beats
  end
end
-- Landing: the view dips with the impact speed (render only).
function W.landing(g, speed)
  Impulses.react(g.view, 'landingHead', abs(speed or 0))
end
-- HUD: arcs around the reticle pointing at each blow, length and width from
-- the blow, colour from its damage type; a near miss is a thin dashed arc.
function W.drawMarks(g, cx, cy, radius)
  local marks = g.view.hurtMarks
  if not marks or #marks == 0 then
    return
  end
  local lg = love.graphics
  local M = K.marks
  local yaw = Context.actor(g).yaw or 0
  lg.setLineStyle('smooth')
  for _, m in ipairs(marks) do
    local a = angle(m.angle - yaw) - pi / 2
    local t = m.age / m.life
    local alpha = min(1, (1 - t) * M.fade)
    local half = M.half + M.halfSeverity * m.severity + M.halfHarm * m.harm
    local width = m.miss and 2 or (3 + 5 * m.harm + 3 * m.severity)
    local r = radius + (m.miss and M.missOffset or 0) + t * M.spread
    lg.setLineWidth(width + 3)
    lg.setColor(M.shadow[1], M.shadow[2], M.shadow[3], alpha * M.shadow[4])
    lg.arc('line', 'open', cx, cy, r, a - half, a + half, M.segments)
    lg.setLineWidth(width)
    lg.setColor(m.color[1], m.color[2], m.color[3], alpha)
    lg.arc('line', 'open', cx, cy, r, a - half, a + half, M.segments)
  end
  lg.setLineStyle('rough')
  lg.setLineWidth(2)
end
return W
