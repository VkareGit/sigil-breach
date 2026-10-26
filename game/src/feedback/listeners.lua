-- What the player sees and hears of the simulation's events ('present'
-- phase): run after the step (or at once outside a step). Nothing here may
-- change the simulation; the golden master would catch it.
local Audio = require('src.audio.audio')
local Effects = require('src.feedback.effects')
local Weight = require('src.feedback.weight')
local Rules = require('src.combat.rules')
local Tuning = require('src.content.tuning')
local Shot = require('src.feedback.shot_feedback')
local WorldFeedback = require('src.feedback.world_feedback')
local Numbers = require('src.feedback.damage_numbers')
local AbilityFeedback = require('src.feedback.ability_feedback')
local MovementMarks = require('src.feedback.movement_marks')
local Text = require('src.content.text')
local Feel = Tuning.feel
local Listeners = {}
-- The visible consequence of a blow on a body: wound particles, or a spray.
local Impact = require('src.feedback.impact_response')
local FX = Effects
local function blow(g, e)
  local target, point, contact = e.target, e.point, e.contact
  if e.number then
    Numbers.add(g, point, e.number.value, e.number.kill, e.number.head, false)
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
  g.view.hitmarker, g.view.precisionHit = Feel.hitmarker, false
  g.view.lastDamage = math.floor(e.health + 0.5)
  g.view.lastKill = enemy.hp <= 0
  if e.source ~= 'weapon' then
    g:burst(enemy.x, Feel.bloodHeight, enemy.z, Rules.body(enemy).blood, 4, 1.0)
  end
end
local function enemyKilled(g, e)
  local enemy = e.enemy
  if e.offBalance then
    g.view.breakKill = Feel.breakKillFlash
    g.view.killPunch = math.max(g.view.killPunch or 0, Feel.breakKillPunch)
    if (e.healed or 0) > 0 then
      Audio.play('seal', 0.22)
    end
  end
  Effects.stain(
    g,
    enemy.x,
    enemy.z,
    require('src.content.enemies').look(enemy).deathStain,
    enemy.kind
  )
  g.view.feedback, g.view.feedbackTimer =
    Text.get('feedback_destroyed', { reward = e.reward or 0 }), 1.8
  if e.offBalance then
    local healed = e.healed or 0
    g.view.feedback = healed > 0
        and Text.get(
          'feedback_break_heal',
          { amount = (string.format('%.1f', healed):gsub('%.0$', '')) }
        )
      or Text.get('feedback_break_full')
  end
  Audio.play('kill', 0.65)
  if e.guardianFell then
    g:notify(Text.get('feedback_guardian_fell'), 7)
    Audio.play('seal')
  end
end
local function playerHit(g, e)
  local info, player = e.info, g.player
  if info.x and info.z then
    g.view.damageDir = math.atan2(info.x - player.x, info.z - player.z)
  end
  g.view.hurt = Feel.hurtFlash
  g.view.shake = math.max(g.view.shake or 0, Feel.hurtShake)
  Weight.playerHit(g, info)
end
-- The perfect dodge: the world stills into its underdrawing for a moment
-- (the post's sinopia, view.perfectDodge), a shade stays where the knight
-- stood (feedback/movement_marks.lua), the sanctuary's bells ring.
local function perfectDodge(g)
  g.view.perfectDodge = Feel.perfectDodgeFlash
  g.view.surge = math.max(g.view.surge or 0, Feel.perfectDodgeSurge)
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
    playerHit(g, e)
  end)
  bus:on('present', 'PerfectDodge', function(e)
    perfectDodge(g, e)
  end)
  bus:on('present', 'ShotFired', function(e)
    Shot.discharge(g, e)
  end)
  bus:on('present', 'VolleyResolved', function(e)
    Shot.volley(g, e)
  end)
  bus:on('present', 'AbilityCast', function(e)
    AbilityFeedback.cast(g, e)
  end)
  WorldFeedback.attach(g)
end
return Listeners
