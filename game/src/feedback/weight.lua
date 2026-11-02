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
local K = require('src.physics.kinematics')
local A = require('src.audio.audio')
local Weapons = require('src.content.weapons')
local Text = require('src.content.text')
local W = {}
local sin, cos, atan2, sqrt, min, max, abs, pi =
  math.sin, math.cos, math.atan2, math.sqrt, math.min, math.max, math.abs, math.pi
local clamp = MathX.clamp
local angle = MathX.wrapAngle
local guardColor = { 0.50, 0.70, 1 }
local function addMark(g, mark)
  local marks = g.view.hurtMarks or {}
  g.view.hurtMarks = marks
  if #marks >= 6 then
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
    g.view[key] = 0
  end
end
function W.init(g)
  W.clearMotion(g)
  g.view.rollSide = 1
  g.view.hurtMarks = {}
  g.view.breakConfirm = 0
  g.view.heartTimer = 0
  g.view.heartbeats = 0
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
-- The shot: recoil impulse = discharge momentum * power / weapon mass.
function W.shot(g, profile, power)
  local w = profile.weight
  power = power or 1
  local kick = w.momentum * power / w.mass
  g.view.recoilV = (g.view.recoilV or 0) + kick
  g.view.shotAge = 0
  g.view.interruptedClose = nil
  g.view.fovKick = w.fov
  g.view.rollSide = -(g.view.rollSide or 1)
  if g.view.motion ~= false then
    g.view.rollPunchV = (g.view.rollPunchV or 0) + g.view.rollSide * w.roll * kick
    -- The hands rise and move back, then settle past rest once.
    -- Body punch moves the hands without changing the authoritative shot.
    g.view.viewPunchV = (g.view.viewPunchV or 0) + (w.punch or 0) * kick
    g.view.kickBackV = (g.view.kickBackV or 0) + (w.back or 0) * kick
    g.view.kickFlip = w.flip or 0
    -- A single, damped wrist catch, with a consistent firing-hand direction.
    -- It is driven by the same momentum as the axial shove, never by RNG.
    g.view.weaponShotRollV = clamp((g.view.weaponShotRollV or 0) - (w.wrist or 0) * kick, -3, 3)
    -- The view climbs (0.26 G6): a critically damped kick whose peak is
    -- viewKick at 1/rate s. A fast weapon swap can fire while it settles;
    -- render/camera.lua projects the unchanged firing ray into the HUD.
    g.view.aimKickRate = w.viewKickRate
    g.view.aimKickV = (g.view.aimKickV or 0) + w.viewKick * power * w.viewKickRate * math.exp(1)
  end
  if w.tail then
    A.play('hall', w.tail * (0.6 + 0.4 * power))
  end
  -- The gut of the report: a low thump under it.
  if (w.thump or 0) > 0 then
    A.play('thud', w.thump * (0.6 + 0.4 * power))
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
  return clamp((impact or 0) / Characters.of(actor).body.poise, 0, 1.6)
end
-- The player is struck. info: amount, lost, absorbed, impact, damageType,
-- x/z (source), staggered, wounded.
function W.playerHit(g, info)
  local p = Context.actor(g)
  local severity = W.severity(info.impact, p)
  local harm = clamp((info.amount or 0) / 30, 0, 1)
  local rel = info.x and W.relative(p, info.x, info.z) or 0
  local side, ahead = sin(rel), cos(rel)
  if g.view.motion ~= false then
    -- The hands take the blow first: the weapon is knocked away from its source,
    -- the head twists away, the frame shakes by the shove, not by the damage.
    g.view.weaponImpactVX =
      clamp((g.view.weaponImpactVX or 0) - side * (25 + 85 * severity), -150, 150)
    g.view.weaponImpactVY = clamp(
      (g.view.weaponImpactVY or 0) + (18 + 60 * severity) * (0.45 + 0.55 * max(0, ahead)),
      -120,
      120
    )
    g.view.weaponImpactVRoll =
      clamp((g.view.weaponImpactVRoll or 0) - side * (0.05 + 0.22 * severity), -0.36, 0.36)
    g.view.rollPunchV = (g.view.rollPunchV or 0) - side * (0.06 + 0.30 * severity)
    -- A blow from the front snaps the head back (view rises), from behind it
    -- throws it forward (view drops).
    g.view.viewPunchV = (g.view.viewPunchV or 0) + ahead * (0.10 + 0.45 * severity)
  end
  g.view.shake = max(g.view.shake or 0, 0.05 + 0.08 * min(1, severity))
  local shield = (info.absorbed or 0) > (info.lost or 0)
  addMark(g, {
    angle = atan2(info.x and info.x - p.x or sin(p.yaw), info.z and info.z - p.z or cos(p.yaw)),
    harm = harm,
    severity = min(1, severity),
    color = shield and guardColor or W.typeColor(info.damageType),
    age = 0,
    life = 0.75 + 0.6 * harm,
    staggered = info.staggered,
  })
  A.play('hurt', 0.30 + 0.40 * harm)
  if severity >= 0.55 or info.source == 'wall' then
    A.play('thud', 0.25 + 0.45 * min(1, severity))
  end
  if (info.absorbed or 0) > 0 then
    A.play('shell', 0.12 + 0.20 * clamp(info.absorbed / 20, 0, 1))
  end
  -- A broken guard: the world's hit-stop is simulation (session/listeners.lua);
  -- here only its sound.
  if info.staggered then
    -- The player's own guard breaking sounds like a demon's, lower and heavier.
    local s = A.play('break', 0.7)
    if s then
      s:setPitch(0.72)
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
  local severity = W.severity(packet.impact or (b.big and 60 or 40), p)
  if A.playAt then
    A.playAt('whoosh', b.x, b.z, p, 0.25 + 0.30 * min(1, severity) * (1 - distance / 1.25))
  end
  addMark(g, {
    angle = atan2(b.x - p.x, b.z - p.z),
    harm = 0,
    severity = 0.25,
    color = W.typeColor(packet.damageType),
    age = 0,
    life = 0.45,
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
    g.view.feedback, g.view.feedbackTimer = Text.get('feedback_falter'), 1.6
    say(4, 'break', 0.75)
    g.view.killPunch = math.max(g.view.killPunch or 0, 0.12)
  elseif not killed and stopped then
    -- 0.24: the blow reversed a rush; the body goes down.
    g.view.feedback, g.view.feedbackTimer = Text.get('feedback_knocked'), 1.0
    say(3, 'thud', 0.55)
    g.view.killPunch = math.max(g.view.killPunch or 0, 0.10)
  elseif not killed and tripped then
    g.view.feedback, g.view.feedbackTimer = Text.get('feedback_tripped'), 1.0
    say(3, 'thud', 0.5)
    g.view.killPunch = math.max(g.view.killPunch or 0, 0.08)
  elseif not killed and counter then
    g.view.feedback, g.view.feedbackTimer = Text.get('feedback_counter'), 0.9
    say(3, 'crit', 0.32)
  elseif not killed and crippled then
    g.view.feedback, g.view.feedbackTimer = Text.get('feedback_crippled'), 0.9
  end
  g.view.breakConfirm = broke and 0.22 or (g.view.breakConfirm or 0)
  if broke then
    say(4, 'break', 0.30 + 0.25 * (g.view.hitWeight or 0))
  end
  -- A heavy stagger lands with weight: a body blow and a short frame punch;
  -- a light falter keeps only the crack of the broken guard.
  if heavy and not killed then
    say(3, 'thud', 0.38)
    g.view.killPunch = math.max(g.view.killPunch or 0, 0.06)
  end
  if wounded or (counter and broke) then
    -- The player caused the decisive blow: a short frame punch (post shader
    -- 'kill' pulse) and a small view rise, presentation only.
    say(3, 'heavyhit', 0.45)
    g.view.killPunch = math.max(g.view.killPunch or 0, 0.08)
    if g.view.motion ~= false then
      g.view.viewPunchV = (g.view.viewPunchV or 0) + 0.12
    end
  end
  if crippled then
    say(3, 'thud', 0.28)
  end
  if
    report
    and report.headHits > 0
    and (not report.strong or report.headHits * 4 >= report.pelletsHit)
  then
    say(2, 'hit_head', 0.8)
  end
  if voice and not killed then
    A.play(voice, volume)
  end
end
function W.update(g, dt)
  if type(dt) ~= 'number' or dt <= 0 or dt >= math.huge or dt ~= dt then
    return
  end
  if g.view.motion == false then
    W.clearMotion(g)
  else
    g.view.rollPunch, g.view.rollPunchV =
      K.spring(g.view.rollPunch or 0, g.view.rollPunchV or 0, 0, 230, 21, dt)
    g.view.rollPunch = clamp(g.view.rollPunch, -0.06, 0.06)
    g.view.viewPunch, g.view.viewPunchV =
      K.spring(g.view.viewPunch or 0, g.view.viewPunchV or 0, 0, 300, 24, dt)
    g.view.viewPunch = clamp(g.view.viewPunch, -0.05, 0.05)
    g.view.kickBack, g.view.kickBackV =
      K.spring(g.view.kickBack or 0, g.view.kickBackV or 0, 0, 900, 30, dt)
    g.view.kickBack = clamp(g.view.kickBack, -1.5, 2.5)
    local rate = g.view.aimKickRate or 30
    g.view.aimKick, g.view.aimKickV =
      K.spring(g.view.aimKick or 0, g.view.aimKickV or 0, 0, rate * rate, 2 * rate, dt)
    local w = (Weapons.inHand(g, nil, Context.actor(g)) or Weapons.profile(1, g, Context.actor(g))).weight
    g.view.weaponShotRoll, g.view.weaponShotRollV =
      K.spring(g.view.weaponShotRoll or 0, g.view.weaponShotRollV or 0, 0, w.wristK, w.wristD, dt)
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
  g.view.breakConfirm = max(0, (g.view.breakConfirm or 0) - dt)
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
  g.view.heartTimer = (g.view.heartTimer or 0) - dt
  if g.view.heartTimer <= 0 then
    local fear = 1 - Characters.share(p) / Tuning.lowHealth
    local period = 0.95 - 0.45 * fear
    local beats = 1 + math.floor(-g.view.heartTimer / period)
    -- Preserve the remainder like the planted footfall clock. Low frame rates
    -- must not silently lengthen the physical pulse; a hitch plays one cue.
    g.view.heartTimer = g.view.heartTimer + beats * period
    if Context.isControlled(g, p) then
      A.play('heart', 0.18 + 0.30 * fear)
    end
    g.view.heartbeats = (g.view.heartbeats or 0) + beats
  end
end
-- Landing: the view dips with the impact speed (render only).
function W.landing(g, speed)
  if g.view.motion == false then
    return
  end
  g.view.viewPunchV = (g.view.viewPunchV or 0) - min(0.55, abs(speed or 0) * 0.045)
end
-- HUD: arcs around the reticle pointing at each blow, length and width from
-- the blow, colour from its damage type; a near miss is a thin dashed arc.
function W.drawMarks(g, cx, cy, radius)
  local marks = g.view.hurtMarks
  if not marks or #marks == 0 then
    return
  end
  local lg = love.graphics
  local yaw = Context.actor(g).yaw or 0
  lg.setLineStyle('smooth')
  for _, m in ipairs(marks) do
    local a = angle(m.angle - yaw) - pi / 2
    local t = m.age / m.life
    local alpha = min(1, (1 - t) * 2.2)
    local half = 0.16 + 0.22 * m.severity + 0.10 * m.harm
    local width = m.miss and 2 or (3 + 5 * m.harm + 3 * m.severity)
    local r = radius + (m.miss and 10 or 0) + t * 8
    lg.setLineWidth(width + 3)
    lg.setColor(0.01, 0.01, 0.02, alpha * 0.85)
    lg.arc('line', 'open', cx, cy, r, a - half, a + half, 18)
    lg.setLineWidth(width)
    lg.setColor(m.color[1], m.color[2], m.color[3], alpha)
    lg.arc('line', 'open', cx, cy, r, a - half, a + half, 18)
  end
  lg.setLineStyle('rough')
  lg.setLineWidth(2)
end
return W
