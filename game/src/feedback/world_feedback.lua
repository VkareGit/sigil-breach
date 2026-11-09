-- How the fight sounds and shows ('present' listeners): telegraphs, releases,
-- landings, rushes into stone, sidesteps, alerts, slams, collisions, portals,
-- arrivals, the knight's stagger, powder charges, near misses, projectile
-- bursts, reloads and supplies. Pure presentation; no simulation state.
local Impulses = require('src.feedback.impulses')
local Archetypes = require('src.content.enemies')
local Audio = require('src.audio.audio')
local FX = require('src.feedback.effects')
local Weight = require('src.feedback.weight')
local Rules = require('src.combat.rules')
local Reload = require('src.combat.reload')
local Weapons = require('src.content.weapons')
local K = require('src.content.tuning').world
local Cue = require('src.content.world_voices')
local Context = require('src.session.context')
local Recipient = require('src.feedback.recipient')
local Bodies = require('src.combat.bodies')
local RiteFeedback = require('src.feedback.rite_feedback')
local Rites = require('src.content.art.rites')
local World = {}
local BodyVoices = require('src.audio.body_voices')
local Profiles = require('src.audio.creature_profiles')
local warnings = setmetatable({}, { __mode = 'k' })
local function stopWarning(enemy)
  for _, voice in ipairs(warnings[enemy] or {}) do
    Audio.stopVoice(voice.source, voice.ticket, Cue.warningFade)
  end
  warnings[enemy] = nil
end
local function sounds(e)
  return Rules.archetype(e).sounds or {}
end
local function warningLayer(g, e, name, gain, priority)
  if not name then
    return
  end
  local source, ticket =
    Audio.playAt(name, e.x, e.z, Context.viewer(g), gain, priority, g.world, nil, e)
  if source then
    local list = warnings[e] or {}
    warnings[e] = list
    list[#list + 1] = { source = source, ticket = ticket }
  end
end
-- event kind -> function(g, event)
World.handlers = {
  EnemyPhaseChanged = function(g, ev)
    local e = ev.enemy
    Audio.playAt(
      sounds(e).alert or 'growl',
      e.x,
      e.z,
      Context.viewer(g),
      Cue.phase.gain,
      Cue.phase.priority,
      g.world,
      nil,
      e
    )
  end,
  AttackTelegraphed = function(g, ev)
    local e = ev.enemy
    BodyVoices.interrupt(Audio, g, e)
    stopWarning(e)
    local warns = ev.attack.warning ~= false
    local material = Profiles.action(
      e,
      ev.attack,
      'prepare',
      ev.attack.windupSound or (warns and Profiles.body(e, 'windup', 'growl'))
    )
    local T = Cue.telegraph
    warningLayer(g, e, material, T.material, warns and T.materialPriority or 0)
    warningLayer(g, e, ev.attack.windupVoice, T.voice, warns and T.voicePriority or 0)
  end,
  AttackCancelled = function(_, ev)
    stopWarning(ev.enemy)
  end,
  EnemyKilled = function(g, ev)
    stopWarning(ev.enemy)
    BodyVoices.interrupt(Audio, g, ev.enemy)
  end,
  BodyHit = function(g, ev)
    if ev.health > 0 then
      BodyVoices.hurt(Audio, g, ev.enemy)
    end
  end,
  GroundStruck = function(g, ev)
    RiteFeedback.struck(g, ev)
    require('src.audio.field_voices').struck(Audio, g, ev.hazard)
  end,
  AttackReleased = function(g, ev)
    local e = ev.enemy
    RiteFeedback.released(g, ev)
    stopWarning(e)
    -- A successful blink sounds at the two recorded endpoints. A failed
    -- destination search has no arrival, and must not fake one here.
    if ev.attack.kind == 'blink' then
      return
    end
    Audio.playAt(
      Profiles.action(
        e,
        ev.attack,
        'release',
        ev.attack.sound or Profiles.body(e, 'strike', 'cast')
      ),
      e.x,
      e.z,
      Context.viewer(g),
      Cue.release.gain,
      ev.attack.warning == false and 0 or Cue.release.priority,
      g.world,
      nil,
      e
    )
    warningLayer(
      g,
      e,
      ev.attack.releaseVoice,
      Cue.release.voice,
      ev.attack.warning == false and 0 or Cue.release.priority
    )
  end,
  ChargeBlocked = function(g, ev)
    Audio.playAt(
      Profiles.body(ev.enemy, 'impact', 'thud'),
      ev.enemy.x,
      ev.enemy.z,
      Context.viewer(g),
      Cue.chargeBlocked.gain,
      Cue.chargeBlocked.priority,
      g.world
    )
  end,
  -- A body meets the floor: low dust, a thud, a tremor felt only near it.
  HazardEnded = function(g, ev)
    RiteFeedback.ended(g, ev)
    require('src.audio.field_voices').ended(Audio, g, ev.hazard)
  end,
  Landed = function(g, ev)
    RiteFeedback.landed(g, ev)
    local e, p = ev.enemy, Context.viewer(g)
    local L = Cue.landing
    FX.emit(g, 'stone', e.x, K.dustHeight, e.z, ev.heavy and L.heavyDust or L.dust)
    local voice = e.attackSpec and e.attackSpec.landingSound
    if voice then
      Audio.playAt(voice, e.x, e.z, p, ev.heavy and L.heavyGain or L.gain, 1, g.world)
    else
      Audio.playAt(
        Profiles.body(e, 'impact', 'thud'),
        e.x,
        e.z,
        p,
        ev.heavy and L.heavyGain or L.gain,
        1,
        g.world
      )
    end
    Recipient.each(g, function(personal, actor)
      local d = math.sqrt((actor.x - e.x) ^ 2 + (actor.z - e.z) ^ 2)
      Impulses.react(personal.view, 'tremor', 0, 0, 0, d)
    end)
  end,
  Evaded = function(g, ev)
    Audio.playAt(
      Profiles.body(ev.enemy, 'evade', 'whoosh'),
      ev.enemy.x,
      ev.enemy.z,
      Context.viewer(g),
      Cue.evaded.gain,
      1,
      g.world,
      nil,
      ev.enemy
    )
  end,
  Alerted = function(g, ev)
    local e = ev.enemy
    Audio.playAt(
      sounds(e).alert or 'snarl',
      e.x,
      e.z,
      Context.viewer(g),
      Cue.alerted.gain,
      Cue.alerted.priority,
      g.world,
      nil,
      e
    )
  end,
  -- A body driven into stone lands in the frame too.
  WallSlam = function(g, ev)
    if ev.player or Bodies.isKnight(g, ev.body) then
      local personal = Recipient.context(g, ev.body)
      if personal then
        Impulses.react(personal.view, 'knightSlam')
      end
      return
    end
    local e = ev.body
    Recipient.each(g, function(personal)
      Impulses.react(personal.view, 'bodySlam')
    end)
    Audio.playAt(
      Profiles.body(e, 'impact', 'thud'),
      e.x,
      e.z,
      Context.viewer(g),
      Cue.wallSlam.gain + Cue.wallSlam.lostGain * (ev.lost or 0),
      1,
      g.world
    )
    local W = Cue.wallSlam
    g:burst(e.x, W.bloodHeight, e.z, Rules.body(e).blood, W.drops, W.speed)
  end,
  BodiesCollided = function(g, ev)
    Audio.playAt(
      Profiles.body(ev.other, 'impact', 'hit'),
      ev.other.x,
      ev.other.z,
      Context.viewer(g),
      Cue.collided.gain,
      1,
      g.world
    )
  end,
  PortalOpened = function(g, ev)
    local def = Archetypes.get(ev.gate.kind)
    local voice = def and def.sounds and def.sounds.summon or 'cast'
    Audio.playAt(
      voice,
      ev.gate.x,
      ev.gate.z,
      Context.viewer(g),
      Cue.portal.gain,
      Cue.portal.priority,
      g.world
    )
  end,
  -- Arrival: smoke, a burst in the portal's colour, a deep pulse.
  EnemyArrived = function(g, ev)
    local e, s = ev.enemy, ev.gate
    local color = Archetypes.look(e).portal
    local A = Cue.arrival
    FX.emit(g, 'smoke', s.x, A.smokeHeight, s.z, A.smoke)
    g:burst(s.x, A.burstHeight, s.z, color, A.specks, A.speed)
    Audio.playAt(
      sounds(e).arrival or 'pulse',
      s.x,
      s.z,
      Context.viewer(g),
      Cue.arrivalVoice.gain,
      Cue.arrivalVoice.priority,
      g.world
    )
  end,
  -- Folding wings at departure; the stronger cast marks its actual arrival.
  Blinked = function(g, ev)
    RiteFeedback.blinked(g, ev)
    local voices = sounds(ev.enemy)
    Audio.playAt(
      Profiles.body(ev.enemy, 'departure', voices.step or 'wing_fold'),
      ev.fromX,
      ev.fromZ,
      Context.viewer(g),
      Cue.blink.departure,
      Cue.blink.priority,
      g.world
    )
    Audio.playAt(
      ev.attack.sound or voices.strike or 'cast',
      ev.toX,
      ev.toZ,
      Context.viewer(g),
      Cue.blink.arrival,
      Cue.blink.priority,
      g.world
    )
  end,
  -- The grip closes: felt in the view, heard in the bones.
  Seized = function(g, ev)
    Audio.playAt('thud', ev.enemy.x, ev.enemy.z, Context.viewer(g), Cue.seized.gain)
    Recipient.each(g, function(personal)
      Impulses.react(personal.view, 'seized')
    end)
  end,
  PlayerStaggered = function(g, ev)
    g = Recipient.context(g, ev.actor)
    if not g then
      return
    end
    g.view.staggerFlash = K.staggerFlash
    Impulses.react(g.view, 'stagger')
  end,
  -- The swing and the fuse catching; its embers: feedback/movement_marks.lua.
  ChargeThrown = function()
    Audio.play('throw', K.throwSound)
    Audio.play('fuse', K.fuseSound)
  end,
  ChargeExploded = function(g, ev)
    local b = ev.charge
    Recipient.each(g, function(personal, actor)
      local d = math.sqrt((actor.x - b.x) ^ 2 + (actor.z - b.z) ^ 2)
      Impulses.react(personal.view, 'blast', 0, 0, 0, d)
    end)
    local C = Cue.charge
    FX.emit(g, 'powder', b.x, b.y + C.smokeRise, b.z, C.smoke)
    FX.emit(g, 'stone', b.x, b.y + C.stoneRise, b.z, C.stone)
    Audio.playAt('blast', b.x, b.z, Context.viewer(g), C.gain)
  end,
  NearMiss = function(g, ev)
    local personal = Recipient.context(g, ev.actor)
    if personal then
      Weight.nearMiss(personal, ev.bullet, ev.distance)
    end
  end,
  ProjectileBurst = function(g, ev)
    local b = ev.bullet
    Audio.stopEmitter(b, Cue.projectileBurst.fade)
    local style = Rites.projectiles.styles[b.packet and b.packet.damageType]
      or Rites.projectiles.default
    FX.emit(g, style.impact, b.x, b.y, b.z, Cue.projectileBurst.size)
    Audio.playAt(
      Profiles.projectile(g, b, 'impact'),
      b.x,
      b.z,
      Context.viewer(g),
      Cue.projectileBurst.gain,
      1,
      g.world
    )
  end,
  -- A reload stage sounds as the weapon's own voice for it where its bank
  -- names one (content/defs/weapon.lua: reload.voices, reload.sounds), else as
  -- its mechanism's (the breech's lever and shells, the cylinder's crane).
  ReloadStage = function(g, ev)
    local actor = Recipient.actor(g, ev.actor)
    if not actor then
      return
    end
    local mechanism = Reload.mechanisms[ev.mechanism]
    local own = Weapons.has(ev.weapon) and Weapons.get(ev.weapon).reload or {}
    local voice = (own.voices or mechanism.voices)[ev.stage] or mechanism.voices[ev.stage]
    local volume = (own.sounds or mechanism.sounds)[ev.stage] or mechanism.sounds[ev.stage]
    if Context.isControlled(g, actor) then
      Audio.play(voice, volume)
    else
      Audio.playAt(voice, actor.x, actor.z, Context.viewer(g), volume)
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
        x = side * Cue.shells.x,
        y = 0,
        vx = side * Cue.shells.vx,
        vy = Cue.shells.vy + (i - 1) * Cue.shells.vyStep,
        life = Cue.shells.life,
        angle = i * Cue.shells.turn,
        bounced = false,
      }
    end
  end,
  PickupTaken = function(g, ev)
    g:notify(ev.text, 1)
    Audio.play('pickup', Cue.pickup)
  end,
}
function World.restored(g)
  Bodies.eachCreature(g, function(e)
    if e.hp > 0 and e.ai == 'windup' and e.attackSpec then
      World.handlers.AttackTelegraphed(g, { enemy = e, attack = e.attackSpec })
      for _, voice in ipairs(warnings[e] or {}) do
        Audio.seekVoice(
          voice.source,
          voice.ticket,
          math.max(0, (e.windupDuration or 0) - (e.windup or 0))
        )
      end
    end
  end)
end
function World.attach(g)
  for kind, handler in pairs(World.handlers) do
    g.bus:on('present', kind, function(event)
      handler(g, event)
    end)
  end
end
return World
