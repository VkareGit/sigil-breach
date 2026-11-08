-- What the player sees and hears of the simulation's events ('present'
-- phase): run after the step (or at once outside a step). Nothing here may
-- change the simulation; the golden master would catch it.
local Impulses = require('src.feedback.impulses')
local Archetypes = require('src.content.enemies')
local Audio = require('src.audio.audio')
local FX = require('src.feedback.effects')
local Weight = require('src.feedback.weight')
local Rules = require('src.combat.rules')
local Tuning = require('src.content.tuning')
local Shot = require('src.feedback.shot_feedback')
local WorldFeedback = require('src.feedback.world_feedback')
local Scenery = require('src.feedback.scenery_feedback')
local DamageNumbers = require('src.feedback.damage_numbers')
local AbilityFeedback = require('src.feedback.ability_feedback')
local MovementMarks = require('src.feedback.movement_marks')
local Text = require('src.content.text')
local Context = require('src.session.context')
local Recipient = require('src.feedback.recipient')
local Medals = require('src.feedback.medals')
local Lessons = require('src.feedback.lessons')
local Honours = require('src.content.chain')
local Characters = require('src.content.characters')
local Feel = Tuning.feel
local Listeners = {}
-- The visible consequence of a blow on a body: wound particles, or a spray.
local Impact = require('src.feedback.impact_response')
local function blow(g, e)
  local target, point, contact = e.target, e.point, e.contact
  if e.number then
    DamageNumbers.add(g, point, e.number.value, e.number.kill, e.number.head, false)
  end
  if contact then
    Impact.body(g, target, point, contact.healthDamage, contact.armorAbsorbed, contact)
    return
  end
  -- Dark madder and ichor, not bright confetti: the spray glows only a little.
  local strength = math.min(1, e.impact / Feel.sprayImpact)
  local color = Rules.body(target).blood
  -- Fewer, darker clots: the hit reads on the body, not as a cloud of sparks.
  g:burst(point[1], point[2], point[3], color, math.ceil(3 + strength * 5), 0.7 + strength * 1.6)
  FX.emit(g, 'blood', point[1], point[2], point[3], 0.28 + strength * 0.48)
end
local function bodyHit(g, e)
  local enemy = e.enemy
  local personal = Recipient.chain(g, e.owner)
  if personal then
    personal.view.hitmarker, personal.view.precisionHit = Feel.hitmarker, false
    personal.view.lastDamage = math.floor(e.health + 0.5)
    personal.view.lastKill = enemy.hp <= 0
    -- What this body lost to this view's blows: summed here, aged by systems/clocks, drawn by
    -- ui/hud while the body is in the sights. Another body begins its own.
    local trail = personal.view.damageTrail
    if not trail or trail.id ~= enemy.id then
      trail = { id = enemy.id, sum = 0, shown = enemy.hp + e.health }
      personal.view.damageTrail = trail
    end
    trail.sum, trail.hold = trail.sum + e.health, Tuning.clocks.trailHold
    trail.hp, trail.maxHp = enemy.hp, enemy.maxHp or enemy.hp + e.health
  end
  if e.source ~= 'weapon' then
    g:burst(enemy.x, Feel.bloodHeight, enemy.z, Rules.body(enemy).blood, 4, 1.0)
  end
end
local function enemyKilled(g, e)
  local enemy = e.enemy
  -- Retire the living voice before attaching the final performance to the same body.
  Audio.stopEmitter(enemy, 0.025)
  local death = Rules.archetype(enemy).sounds.death
  if death then
    Audio.playAt(death, enemy.x, enemy.z, Context.viewer(g), 0.65, 2, g.world, nil, enemy)
  end
  local personal = Recipient.chain(g, e.owner)
  if personal and e.offBalance then
    personal.view.breakKill = Feel.breakKillFlash
    Impulses.react(personal.view, 'breakKill')
    if (e.healed or 0) > 0 then
      Audio.play('seal', 0.22)
    end
  end
  FX.stain(g, enemy.x, enemy.z, Archetypes.look(enemy).deathStain, enemy.kind)
  if not personal then
    -- A world death leaves its stain regardless of who owns the blow.
    Audio.play('kill', 0.65)
    return
  end
  g = personal
  local p = Context.actor(g)
  if e.source == 'execution' then
    Medals.show(g, 'absolved')
  elseif p.hp <= Characters.maxHp(p) * Honours.lastRites then
    Medals.show(g, 'last_rites')
  elseif ((enemy.x - p.x) ^ 2 + (enemy.z - p.z) ^ 2) ^ 0.5 <= Honours.pointBlank then
    Medals.show(g, 'point_blank')
  end
  if e.souls then
    -- What the purse really gained, at the purse; a run of kills adds up.
    local running = 0
    if g.view.soulsGainTimer > 0 then
      running = g.view.soulsGain
    end
    g.view.soulsGain, g.view.soulsGainTimer = running + e.souls, Feel.soulsGain
  else
    g.view.feedback, g.view.feedbackTimer =
      Text.get('feedback_destroyed', { reward = e.reward or 0 }), 1.8
  end
  if e.offBalance then
    local healed = e.healed or 0
    g.view.feedback = e.heal == 0 and Text.get('feedback_break')
      or healed > 0 and Text.get(
        'feedback_break_heal',
        { amount = (string.format('%.1f', healed):gsub('%.0$', '')) }
      )
      or Text.get('feedback_break_full')
  end
  Audio.play('kill_confirm', Tuning.shot.killVolume)
end
local function playerHit(g, e)
  local info, player = e.info, Context.actor(g)
  if info.x and info.z then
    g.view.damageDir = math.atan2(info.x - player.x, info.z - player.z)
  end
  g.view.hurt = Feel.hurtFlash
  Impulses.react(g.view, 'hurt')
  Weight.playerHit(g, info)
end
-- The perfect dodge: the world stills into its underdrawing for a moment
-- (the post's sinopia, view.perfectDodge), a shade stays where the knight
-- stood (feedback/movement_marks.lua), the sanctuary's bells ring.
local function perfectDodge(g)
  g.view.perfectDodge = Feel.perfectDodgeFlash
  g.view.surge = math.max(g.view.surge, Feel.perfectDodgeSurge)
  g.view.feedback, g.view.feedbackTimer = Text.get('feedback_perfect_dodge'), 1.2
  MovementMarks.afterimage(g)
  Audio.play('afterimage', Feel.perfectDodgeSound)
end
function Listeners.attach(g)
  local bus = g.bus
  bus:on('present', 'BlowResolved', function(e)
    blow(g, e)
  end)
  bus:on('present', 'BodyHit', function(e)
    bodyHit(g, e)
  end)
  bus:on('present', 'EnemyKilled', function(e)
    enemyKilled(g, e)
  end)
  bus:on('present', 'PlayerHit', function(e)
    local personal = Recipient.context(g, e.actor)
    if personal then
      playerHit(personal, e)
    end
  end)
  bus:on('present', 'KnightHit', function(e)
    local personal = Recipient.context(g, e.knight)
    if personal then
      playerHit(personal, e)
    end
  end)
  bus:on('present', 'KnightFell', function(e)
    -- During a step KnightHit is queued before the fall. The simulation's
    -- immediate reset cannot clear feedback that has not been presented yet.
    -- Finish this lifecycle after the queued hurt response has run.
    Context.reset(g, e.knight)
  end)
  bus:on('present', 'ChainGrew', function(e)
    local personal = Recipient.context(g, e.actor)
    if personal then
      Medals.show(personal, e.step.id)
      Lessons.note(personal.view, 'chain')
    end
  end)
  -- The first golden ring a knight sees: a blow with a window to throw it back.
  bus:on('present', 'AttackTelegraphed', function(e)
    if e.attack and e.attack.parry then
      local personal = Recipient.context(g)
      Lessons.note(personal and personal.view, 'ring')
    end
  end)
  bus:on('present', 'PickupTaken', function(e)
    if e.pickup.kind == 'ammo' then
      local personal = Recipient.context(g)
      Lessons.note(personal and personal.view, 'rounds')
    end
  end)
  bus:on('present', 'PerfectDodge', function(e)
    local personal = Recipient.context(g, e.actor)
    if personal then
      perfectDodge(personal, e)
    end
  end)
  -- World shot effects are resolved once; the shot module routes only the
  -- personal recoil and confirmation to its observed owner.
  bus:on('present', 'ShotFired', function(e)
    Shot.discharge(g, e)
  end)
  bus:on('present', 'VolleyResolved', function(e)
    Shot.volley(g, e)
  end)
  Scenery.attach(g, bus)
  bus:on('present', 'AbilityCast', function(e)
    local personal = Recipient.context(g, e.actor)
    if personal then
      AbilityFeedback.cast(personal, e)
    end
  end)
  WorldFeedback.attach(g)
end
return Listeners
