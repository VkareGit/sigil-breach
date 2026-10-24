-- How the fight sounds and shows ('present' listeners): telegraphs, releases,
-- landings, rushes into stone, sidesteps, alerts, slams, collisions, portals,
-- arrivals, the knight's stagger, powder charges, near misses, projectile
-- bursts, reloads and supplies. Pure presentation; no simulation state.
local A = require('src.audio.audio')
local FX = require('src.feedback.effects')
local Weight = require('src.feedback.weight')
local Rules = require('src.combat.rules')
local Reload = require('src.combat.reload')
local Weapons = require('src.content.weapons')
local K = require('src.content.tuning').world
local World = {}
local function sounds(e)
  return Rules.archetype(e).sounds or {}
end
-- event kind -> function(g, event)
World.handlers = {
  AttackTelegraphed = function(g, ev)
    local e = ev.enemy
    A.playAt(sounds(e).windup or 'growl', e.x, e.z, g.player, 0.7)
  end,
  AttackReleased = function(g, ev)
    local e = ev.enemy
    A.playAt(ev.attack.sound or sounds(e).strike or 'cast', e.x, e.z, g.player, 0.65)
  end,
  ChargeBlocked = function(g, ev)
    A.playAt('thud', ev.enemy.x, ev.enemy.z, g.player, 0.5)
  end,
  -- A body meets the floor: low dust, a thud, a tremor felt only near it.
  Landed = function(g, ev)
    local e, p = ev.enemy, g.player
    FX.emit(g, 'stone', e.x, K.dustHeight, e.z, ev.heavy and 0.75 or 0.5)
    A.playAt('thud', e.x, e.z, p, ev.heavy and 0.55 or 0.42)
    local d = math.sqrt((p.x - e.x) ^ 2 + (p.z - e.z) ^ 2)
    if d < K.tremorReach then
      g.view.shake = math.max(g.view.shake or 0, K.tremor * (1 - d / K.tremorReach))
    end
  end,
  Evaded = function(g, ev)
    A.playAt('whoosh', ev.enemy.x, ev.enemy.z, g.player, 0.45)
  end,
  Alerted = function(g, ev)
    local e = ev.enemy
    A.playAt(sounds(e).alert or 'snarl', e.x, e.z, g.player, 0.4)
  end,
  -- A body driven into stone lands in the frame too.
  WallSlam = function(g, ev)
    if ev.player then
      g.view.shake = math.max(g.view.shake or 0, K.knightSlamShake)
      return
    end
    local e = ev.body
    g.view.killPunch = math.max(g.view.killPunch or 0, K.slamPunch)
    A.playAt('thud', e.x, e.z, g.player, 0.30 + 0.08 * (ev.lost or 0))
    g:burst(e.x, 1.0, e.z, Rules.body(e).blood, 6, 1.4)
  end,
  BodiesCollided = function(g, ev)
    A.playAt('hit', ev.other.x, ev.other.z, g.player, 0.35)
  end,
  PortalOpened = function(g, ev)
    A.playAt('cast', ev.gate.x, ev.gate.z, g.player, 0.3)
  end,
  -- Arrival: smoke, a burst in the portal's colour, a deep pulse.
  EnemyArrived = function(g, ev)
    local e, s = ev.enemy, ev.gate
    local color = require('src.content.enemies').look(e).portal
    FX.emit(g, 'smoke', s.x, 0.7, s.z, 0.9)
    g:burst(s.x, 1.0, s.z, color, 14, 2.6)
    A.playAt('pulse', s.x, s.z, g.player, 0.45)
  end,
  PlayerStaggered = function(g)
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
    g.view.shake = math.max(g.view.shake, K.blastShake)
    g:burst(b.x, b.y + 0.15, b.z, K.blastColor, 24, 4.5)
    FX.emit(g, 'smoke', b.x, b.y + 0.25, b.z, 1.2)
    FX.emit(g, 'stone', b.x, b.y + 0.15, b.z, 0.9)
    A.playAt('blast', b.x, b.z, g.player, 0.85)
  end,
  NearMiss = function(g, ev)
    Weight.nearMiss(g, ev.bullet, ev.distance)
  end,
  ProjectileBurst = function(g, ev)
    local b = ev.bullet
    g:burst(b.x, b.y, b.z, b.color or K.boltColor, 6, 1.2)
  end,
  -- A reload stage sounds as its mechanism's voice for it (the breech's
  -- lever and shells, the cylinder's crane and ratchet).
  ReloadStage = function(g, ev)
    local mechanism = Reload.mechanisms[ev.mechanism]
    A.play(mechanism.voices[ev.stage], mechanism.sounds[ev.stage])
    if ev.interrupted and ev.weapon == Weapons.idAt(g) and g.elapsed < ev.started + ev.duration then
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
