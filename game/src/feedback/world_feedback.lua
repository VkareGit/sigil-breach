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
    Audio.stopVoice(voice.source, voice.ticket, 0.025)
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
    Audio.playAt(sounds(e).alert or 'growl', e.x, e.z, Context.viewer(g), 0.75, 2, g.world, nil, e)
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
    warningLayer(g, e, material, 0.7, warns and 3 or 0)
    warningLayer(g, e, ev.attack.windupVoice, 0.58, warns and 2 or 0)
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
      0.65,
      ev.attack.warning == false and 0 or 2,
      g.world,
      nil,
      e
    )
    warningLayer(g, e, ev.attack.releaseVoice, 0.58, ev.attack.warning == false and 0 or 2)
  end,
  ChargeBlocked = function(g, ev)
    Audio.playAt(
      Profiles.body(ev.enemy, 'impact', 'thud'),
      ev.enemy.x,
      ev.enemy.z,
      Context.viewer(g),
      0.5,
      2,
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
    FX.emit(g, 'stone', e.x, K.dustHeight, e.z, ev.heavy and 0.75 or 0.5)
    local voice = e.attackSpec and e.attackSpec.landingSound
    if voice then
      Audio.playAt(voice, e.x, e.z, p, ev.heavy and 0.55 or 0.42, 1, g.world)
    else
      Audio.playAt(
        Profiles.body(e, 'impact', 'thud'),
        e.x,
        e.z,
        p,
        ev.heavy and 0.55 or 0.42,
        1,
        g.world
      )
    end
    Recipient.each(g, function(personal, actor)
      local d = math.sqrt((actor.x - e.x) ^ 2 + (actor.z - e.z) ^ 2)
      if d < K.tremorReach then
        Impulses.shake(personal.view, K.tremor * (1 - d / K.tremorReach))
      end
    end)
  end,
  Evaded = function(g, ev)
    Audio.playAt(
      Profiles.body(ev.enemy, 'evade', 'whoosh'),
      ev.enemy.x,
      ev.enemy.z,
      Context.viewer(g),
      0.45,
      1,
      g.world,
      nil,
      ev.enemy
    )
  end,
  Alerted = function(g, ev)
    local e = ev.enemy
    Audio.playAt(sounds(e).alert or 'snarl', e.x, e.z, Context.viewer(g), 0.4, 2, g.world, nil, e)
  end,
  -- A body driven into stone lands in the frame too.
  WallSlam = function(g, ev)
    if ev.player or Bodies.isKnight(g, ev.body) then
      local personal = Recipient.context(g, ev.body)
      if personal then
        Impulses.shake(personal.view, K.knightSlamShake)
      end
      return
    end
    local e = ev.body
    Recipient.each(g, function(personal)
      personal.view.killPunch = math.max(personal.view.killPunch, K.slamPunch)
    end)
    Audio.playAt(
      Profiles.body(e, 'impact', 'thud'),
      e.x,
      e.z,
      Context.viewer(g),
      0.30 + 0.08 * (ev.lost or 0),
      1,
      g.world
    )
    g:burst(e.x, 1.0, e.z, Rules.body(e).blood, 6, 1.4)
  end,
  BodiesCollided = function(g, ev)
    Audio.playAt(
      Profiles.body(ev.other, 'impact', 'hit'),
      ev.other.x,
      ev.other.z,
      Context.viewer(g),
      0.35,
      1,
      g.world
    )
  end,
  PortalOpened = function(g, ev)
    local def = Archetypes.get(ev.gate.kind)
    local voice = def and def.sounds and def.sounds.summon or 'cast'
    Audio.playAt(voice, ev.gate.x, ev.gate.z, Context.viewer(g), 0.45, 2, g.world)
  end,
  -- Arrival: smoke, a burst in the portal's colour, a deep pulse.
  EnemyArrived = function(g, ev)
    local e, s = ev.enemy, ev.gate
    local color = Archetypes.look(e).portal
    FX.emit(g, 'smoke', s.x, 0.7, s.z, 0.9)
    g:burst(s.x, 1.0, s.z, color, 14, 2.6)
    Audio.playAt(sounds(e).arrival or 'pulse', s.x, s.z, Context.viewer(g), 0.55, 2, g.world)
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
      0.35,
      2,
      g.world
    )
    Audio.playAt(
      ev.attack.sound or voices.strike or 'cast',
      ev.toX,
      ev.toZ,
      Context.viewer(g),
      0.5,
      2,
      g.world
    )
  end,
  -- The grip closes: felt in the view, heard in the bones.
  Seized = function(g, ev)
    Audio.playAt('thud', ev.enemy.x, ev.enemy.z, Context.viewer(g), 0.6)
    Recipient.each(g, function(personal)
      Impulses.shake(personal.view, K.staggerShake)
    end)
  end,
  PlayerStaggered = function(g, ev)
    g = Recipient.context(g, ev.actor)
    if not g then
      return
    end
    g.view.recoilV = g.view.recoilV + K.staggerRecoil
    g.view.staggerFlash = K.staggerFlash
    Impulses.shake(g.view, K.staggerShake)
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
      if d < K.blastReach then
        local fade = math.min(1, math.max(0, (d - K.blastNear) / (K.blastReach - K.blastNear)))
        local shake = K.blastShake * (1 - (1 - K.blastFar) * fade)
        Impulses.shake(personal.view, shake)
      end
    end)
    FX.emit(g, 'powder', b.x, b.y + 0.65, b.z, 3.2)
    FX.emit(g, 'stone', b.x, b.y + 0.15, b.z, 0.9)
    Audio.playAt('blast', b.x, b.z, Context.viewer(g), 0.85)
  end,
  NearMiss = function(g, ev)
    local personal = Recipient.context(g, ev.actor)
    if personal then
      Weight.nearMiss(personal, ev.bullet, ev.distance)
    end
  end,
  ProjectileBurst = function(g, ev)
    local b = ev.bullet
    Audio.stopEmitter(b, 0.025)
    local style = Rites.projectiles.styles[b.packet and b.packet.damageType]
      or Rites.projectiles.default
    FX.emit(g, style.impact, b.x, b.y, b.z, 0.65)
    Audio.playAt(Profiles.projectile(g, b, 'impact'), b.x, b.z, Context.viewer(g), 0.23, 1, g.world)
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
      Audio.play(mechanism.voices[ev.stage], mechanism.sounds[ev.stage])
    else
      Audio.playAt(
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
    Audio.play('pickup', 0.4)
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
