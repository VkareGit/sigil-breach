-- Simulation consequences of events ('sim' phase): they run inside the
-- emitting system, in the priority order below, exactly where the direct
-- calls used to be. Presentation is attached by feedback/listeners.lua.
--   EnemyKilled  10 break-kill healing   15 corpse fall   20 score, combo
--                30 the mode's rewards and drops
--   PlayerHit    10 damage record, measurements, pacing, combo reset
--                20 the world's hit-stop when the knight's guard breaks
local Rules = require('src.combat.rules')
local Telemetry = require('src.combat.telemetry')
local Corpse = require('src.enemies.corpse')
local Modes = require('src.run.modes')
local Archetypes = require('src.content.enemies')
local Tuning = require('src.content.tuning')
local Presentation = require('src.session.presentation')
local K = Tuning.rewards
local Listeners = {}
-- Break kill (0.24, the push-forward loop): a demon killed while off balance
-- heals the knight by a share of its guard. Breaking first, then killing.
local function breakKill(g, event)
  if not event.offBalance then
    return
  end
  local player, knight = g.player, Rules.playerBody()
  local heal = Archetypes.defaults.breakKill.heal * Rules.body(event.enemy).poise
  local gained = math.max(0, math.min(knight.hp, player.hp + heal) - player.hp)
  player.hp = player.hp + gained
  event.heal, event.healed = heal, gained
  Telemetry.add(g, 'breakKills')
  Telemetry.add(g, 'healed', gained)
  Telemetry.healing(g, event)
end
local function score(g, event)
  local enemy = event.enemy
  g.kills = g.kills + 1
  g.combo = g.comboTimer > 0 and g.combo + 1 or 1
  g.comboTimer = K.comboWindow
  local guardian = (require('src.content.enemies').of(enemy) or {}).guardian
  event.reward = (guardian and K.boss or K.demon)
    + math.min(K.comboSteps, g.combo - 1) * K.comboStep
  g.score = g.score + event.reward
end
-- The mode's consequences (run/modes.lua: reward): the expedition counts
-- souls; the classic arena drops supplies and ends with the Margrave.
local function rewards(g, event)
  Modes.act(g, 'reward', event)
end
local function playerHit(g, event)
  local info = event.info
  g.damageTaken = g.damageTaken + (info.requested or info.amount)
  Telemetry.add(g, 'hitsTaken')
  -- The pacing director's intensity (run/spawner.lua).
  g.intensity = (g.intensity or 0) + (info.requested or info.amount or 0)
  Telemetry.add(g, 'damageTaken', info.lost or 0)
  g.combo, g.comboTimer = 0, 0
end
-- A broken guard: the world holds its breath for one beat (souls hit-stop):
-- the demons wait, and (0.25) their missiles, marked ground and the knight's
-- charges stand still with them (systems/combat.lua: worldStop).
local function hitStop(g, event)
  if event.info.staggered then
    local stop = Tuning.feel.guardBreakStop
    g.impactSlow = math.max(g.impactSlow or 0, stop)
    g.worldStop = math.max(g.worldStop or 0, stop)
  end
end
function Listeners.attach(g)
  local bus = g.bus
  bus:on('sim', 'BodyHit', function(e)
    Telemetry.hit(g, e.enemy)
  end, 5)
  bus:on('sim', 'Alerted', function(e)
    Telemetry.aware(g, e.enemy)
  end, 5)
  -- Measurements first: they only count (combat/telemetry.lua).
  bus:on('sim', 'BlowResolved', function(e)
    Telemetry.react(g, e.result, e.target)
  end, 5)
  bus:on('sim', 'EnemyKilled', function(e)
    Telemetry.kill(g, e.enemy)
  end, 5)
  bus:on('sim', 'PerfectDodge', function(e)
    Telemetry.add(g, 'perfectDodges')
    if e.returned then
      Telemetry.react(g, e.returned)
    end
  end, 5)
  bus:on('sim', 'EnemyKilled', function(e)
    breakKill(g, e)
  end, 10)
  bus:on('sim', 'EnemyKilled', function(e)
    Corpse.begin(e.enemy, e.health, math.max(0, e.damage - e.health), e.source)
  end, 15)
  bus:on('sim', 'EnemyKilled', function(e)
    score(g, e)
  end, 20)
  bus:on('sim', 'EnemyKilled', function(e)
    rewards(g, e)
  end, 30)
  bus:on('sim', 'PlayerHit', function(e)
    playerHit(g, e)
  end, 10)
  bus:on('sim', 'PlayerHit', function(e)
    hitStop(g, e)
  end, 20)
  -- The presentation's own listeners, when one is loaded (feedback/install.lua).
  Presentation.attach(g)
end
return Listeners
