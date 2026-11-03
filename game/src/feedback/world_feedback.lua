-- How the fight sounds and shows ('present' listeners): telegraphs, releases,
-- landings, rushes into stone, sidesteps, alerts, slams, collisions, portals,
-- arrivals, the knight's stagger, powder charges, near misses, projectile
-- bursts, reloads and supplies. Pure presentation; no simulation state.
local Enemies = require('src.content.enemies')
local DamageTypes = require('src.content.damage_types')
local A = require('src.audio.audio')
local FX = require('src.feedback.effects')
local Weight = require('src.feedback.weight')
local Rules = require('src.combat.rules')
local Reload = require('src.combat.reload')
local Weapons = require('src.content.weapons')
local K = require('src.content.tuning').world
local Context = require('src.session.context')
local Recipient = require('src.feedback.recipient')
local Bodies = require('src.combat.bodies')
local RiteFeedback = require('src.feedback.rite_feedback')
local World = {}
local warnings = setmetatable({}, { __mode = 'k' })
local function stopWarning(enemy)
  local voice = warnings[enemy]
  if voice then
    A.stopVoice(voice.source, voice.ticket)
    warnings[enemy] = nil
  end
end
local function sounds(e)
  return Rules.archetype(e).sounds or {}
end
-- event kind -> function(g, event)
World.handlers = {
  EnemyPhaseChanged = function(g, ev)
    local e = ev.enemy
    A.playAt(sounds(e).alert or 'growl', e.x, e.z, Context.viewer(g), 0.75)
  end,
  AttackTelegraphed = function(g, ev)
    local e = ev.enemy
    stopWarning(e)
    local source, ticket = A.playAt(
      ev.attack.windupSound or sounds(e).windup or 'growl',
      e.x,
      e.z,
      Context.viewer(g),
      0.7,
      3,
      g.world
    )
    if source then
      warnings[e] = { source = source, ticket = ticket }
    end
  end,
  AttackCancelled = function(_, ev)
    stopWarning(ev.enemy)
  end,
  EnemyKilled = function(_, ev)
    stopWarning(ev.enemy)
  end,
  AttackReleased = function(g, ev)
    local e = ev.enemy
    RiteFeedback.released(g, ev)
    stopWarning(e)
    A.playAt(
      ev.attack.sound or sounds(e).strike or 'cast',
      e.x,
      e.z,
      Context.viewer(g),
      0.65,
      2,
      g.world
    )
  end,
  ChargeBlocked = function(g, ev)
    A.playAt('thud', ev.enemy.x, ev.enemy.z, Context.viewer(g), 0.5)
  end,
  -- A body meets the floor: low dust, a thud, a tremor felt only near it.
  Landed = function(g, ev)
    local e, p = ev.enemy, Context.viewer(g)
    FX.emit(g, 'stone', e.x, K.dustHeight, e.z, ev.heavy and 0.75 or 0.5)
    A.playAt('thud', e.x, e.z, p, ev.heavy and 0.55 or 0.42)
    Recipient.each(g, function(personal, actor)
      local d = math.sqrt((actor.x - e.x) ^ 2 + (actor.z - e.z) ^ 2)
      if d < K.tremorReach then
        personal.view.shake = math.max(personal.view.shake or 0, K.tremor * (1 - d / K.tremorReach))
      end
    end)
  end,
  Evaded = function(g, ev)
    A.playAt('whoosh', ev.enemy.x, ev.enemy.z, Context.viewer(g), 0.45)
  end,
  Alerted = function(g, ev)
    local e = ev.enemy
    A.playAt(sounds(e).alert or 'snarl', e.x, e.z, Context.viewer(g), 0.4)
  end,
  -- A body driven into stone lands in the frame too.
  WallSlam = function(g, ev)
    if ev.player or Bodies.isKnight(g, ev.body) then
      local personal = Recipient.context(g, ev.body)
      if personal then
        personal.view.shake = math.max(personal.view.shake or 0, K.knightSlamShake)
      end
      return
    end
    local e = ev.body
    Recipient.each(g, function(personal)
      personal.view.killPunch = math.max(personal.view.killPunch or 0, K.slamPunch)
    end)
    A.playAt('thud', e.x, e.z, Context.viewer(g), 0.30 + 0.08 * (ev.lost or 0))
    g:burst(e.x, 1.0, e.z, Rules.body(e).blood, 6, 1.4)
  end,
  BodiesCollided = function(g, ev)
    A.playAt('hit', ev.other.x, ev.other.z, Context.viewer(g), 0.35)
  end,
  PortalOpened = function(g, ev)
    local def = Enemies.get(ev.gate.kind)
    local voice = def and def.sounds and def.sounds.summon or 'cast'
    A.playAt(voice, ev.gate.x, ev.gate.z, Context.viewer(g), 0.45, 2, g.world)
  end,
  -- Arrival: smoke, a burst in the portal's colour, a deep pulse.
  EnemyArrived = function(g, ev)
    local e, s = ev.enemy, ev.gate
    local color = Enemies.look(e).portal
    FX.emit(g, 'smoke', s.x, 0.7, s.z, 0.9)
    g:burst(s.x, 1.0, s.z, color, 14, 2.6)
    A.playAt(sounds(e).arrival or 'pulse', s.x, s.z, Context.viewer(g), 0.55, 2, g.world)
  end,
  -- Gone in a breath of its own colour, there and where it stands now.
  Blinked = function(g, ev)
    local e = ev.enemy
    local color = Enemies.look(e).portal
    g:burst(ev.fromX, 1.2, ev.fromZ, color, 12, 2.2)
    g:burst(e.x, 1.2, e.z, color, 12, 2.2)
    FX.emit(g, 'smoke', ev.fromX, 0.7, ev.fromZ, 0.7)
    A.playAt('cast', e.x, e.z, Context.viewer(g), 0.5, 2, g.world)
  end,
  -- The grip closes: felt in the view, heard in the bones.
  Seized = function(g, ev)
    A.playAt('thud', ev.enemy.x, ev.enemy.z, Context.viewer(g), 0.6)
    Recipient.each(g, function(personal)
      personal.view.shake = math.max(personal.view.shake or 0, K.staggerShake)
    end)
  end,
  PlayerStaggered = function(g, ev)
    g = Recipient.context(g, ev.actor)
    if not g then
      return
    end
    g.view.recoilV = (g.view.recoilV or 0) + K.staggerRecoil
    g.view.staggerFlash = K.staggerFlash
    g.view.shake = math.max(g.view.shake or 0, K.staggerShake)
  end,
  -- The swing and the fuse catching; its embers: feedback/movement_marks.lua.
  ChargeThrown = function()
    A.play('throw', K.throwSound)
    A.play('fuse', K.fuseSound)
  end,
  ChargeExploded = function(g, ev)
    local b = ev.charge
    Recipient.each(g, function(personal, actor)
      local d = math.sqrt((actor.x - b.x) ^ 2 + (actor.z - b.z) ^ 2)
      if d < K.blastReach then
        local fade = math.min(1, math.max(0, (d - K.blastNear) / (K.blastReach - K.blastNear)))
        local shake = K.blastShake * (1 - (1 - K.blastFar) * fade)
        personal.view.shake = math.max(personal.view.shake or 0, shake)
      end
    end)
    g:burst(b.x, b.y + 0.15, b.z, K.blastColor, 24, 4.5)
    FX.emit(g, 'smoke', b.x, b.y + 0.25, b.z, 1.2)
    FX.emit(g, 'stone', b.x, b.y + 0.15, b.z, 0.9)
    A.playAt('blast', b.x, b.z, Context.viewer(g), 0.85)
  end,
  NearMiss = function(g, ev)
    local personal = Recipient.context(g, ev.actor)
    if personal then
      Weight.nearMiss(personal, ev.bullet, ev.distance)
    end
  end,
  ProjectileBurst = function(g, ev)
    local b = ev.bullet
    g:burst(b.x, b.y, b.z, b.color or K.boltColor, 6, 1.2)
    A.playAt(
      DamageTypes.cue(b.packet and b.packet.damageType, 'impact'),
      b.x,
      b.z,
      Context.viewer(g),
      0.23,
      1,
      g.world
    )
  end,
  -- A reload stage sounds as its mechanism's voice for it (the breech's
  -- lever and shells, the cylinder's crane and ratchet).
  ReloadStage = function(g, ev)
    local actor = Recipient.actor(g, ev.actor)
    if not actor then
      return
    end
    local mechanism = Reload.mechanisms[ev.mechanism]
    if Context.isControlled(g, actor) then
      A.play(mechanism.voices[ev.stage], mechanism.sounds[ev.stage])
    else
      A.playAt(
        mechanism.voices[ev.stage],
        actor.x,
        actor.z,
        Context.viewer(g),
        mechanism.sounds[ev.stage]
      )
    end
    g = Recipient.context(g, actor)
    if not g then
      return
    end
    if
      ev.interrupted
      and ev.weapon == Weapons.idAt(g, nil, actor)
      and g.elapsed < ev.started + ev.duration
    then
      g.view.interruptedClose = {
        weapon = ev.weapon,
        started = ev.started,
        duration = ev.duration,
        reloadAge = ev.reloadAge,
      }
    end
    -- An opened breech throws out its spent cases, one to each side
    -- (render/weapon.lua draws them; feedback/transients.lua moves them).
    for i = 1, ev.spent or 0 do
      local side = i == 1 and -1 or 1
      g.view.shells[#g.view.shells + 1] = {
        weapon = ev.weapon,
        x = side * 7,
        y = 0,
        vx = side * 83,
        vy = -135 + (i - 1) * 17,
        life = 1.2,
        angle = i * 0.3,
        bounced = false,
      }
    end
  end,
  PickupTaken = function(g, ev)
    g:notify(ev.text, 1)
    A.play('pickup', 0.4)
  end,
}
function World.attach(g)
  for kind, handler in pairs(World.handlers) do
    g.bus:on('present', kind, function(event)
      handler(g, event)
    end)
  end
end
return World
