local Sigils = require('src.combat.sigils')
-- Simulation consequences of events ('sim' phase): they run inside the
-- emitting system, in the priority order below, exactly where the direct
-- calls used to be. Presentation is attached by feedback/listeners.lua.
--   EnemyKilled  10 break-kill healing   15 corpse fall   20 score, combo
--                30 the mode's rewards and drops   40 reactions
--   PlayerHit    10 damage record, measurements, pacing, combo reset
--                20 the world's hit-stop when the knight's guard breaks
local Bodies = require('src.combat.bodies')
local Chain = require('src.combat.chain')
local Characters = require('src.content.characters')
local Rules = require('src.combat.rules')
local Telemetry = require('src.combat.telemetry')
local Corpse = require('src.enemies.corpse')
local Modes = require('src.session.modes')
local Archetypes = require('src.content.enemies')
local Tuning = require('src.content.tuning')
local Presentation = require('src.session.presentation')
local Stats = require('src.session.stats')
local Roles = require('src.core.roles')
local Spawn = require('src.session.spawn')
local Arena = require('src.world.arena')
local Destruction = require('src.combat.destruction')
local Reactions = require('src.combat.reactions')
local K = Tuning.rewards
local Listeners = {}
-- Break kill (0.24, the push-forward loop): a demon killed while off balance
-- heals the knight by a share of its guard. Breaking first, then killing.
-- The knight healed is the owner of the killing chain (plan v11 E3d:
-- session/stats.lua: healed), never merely the controlled one; a fallen or
-- departed owner heals no one.
local Capabilities = require('src.session.capabilities')
-- What a blow took stays open for a moment: the knight fights it back or loses it.
local Rally = Archetypes.defaults.rally
local function rallyOpens(g, info)
  if Capabilities.attrition(g) and (info.lost or 0) > 0 then
    local player = Roles.controlled(g)
    player.rally = (player.rally or 0) + info.lost * Rally.share
    player.rallyLeft = Rally.time
  end
end
local function rallyBack(g, event)
  local player = event.owner and Stats.healed(g, event.owner)
  if player and Sigils.rally(player, event) then
    return
  end
  if player and (player.rally or 0) > 0 and (event.health or 0) > 0 then
    local back = math.min(player.rally, event.health * Rally.rate)
    player.rally = player.rally - back
    player.hp = math.min(Characters.maxHp(player), player.hp + back)
  end
end
local function breakKill(g, event)
  if not event.offBalance then
    return
  end
  local player = Stats.healed(g, event.owner)
  local heal = Capabilities.attrition(g) and 0
    or Archetypes.defaults.breakKill.heal * Rules.body(event.enemy).poise
  local gained = player
      and math.max(0, math.min(Characters.maxHp(player), player.hp + heal) - player.hp)
    or 0
  if player then
    player.hp = player.hp + gained
  end
  event.healedKnight = player and player.id
  event.heal, event.healed = heal, gained
  Telemetry.add(g, 'breakKills')
  Telemetry.add(g, 'healed', gained)
  Telemetry.healing(g, event)
end
-- The kill, its combo and its score count for the chain's owner (plan v11
-- E3d: session/stats.lua).
local function score(g, event)
  local enemy = event.enemy
  local r = Stats.record(g, Stats.owner(g, event.owner))
  r.kills = r.kills + 1
  r.combo = r.comboTimer > 0 and r.combo + 1 or 1
  r.comboTimer = K.comboWindow
  local guardian = (Archetypes.of(enemy) or {}).guardian
  event.reward = (guardian and K.boss or K.demon)
    + math.min(K.comboSteps, r.combo - 1) * K.comboStep
  r.score = r.score + event.reward
end
-- A chain is the knight's, where effort is paid (combat/chain.lua).
local function chain(g, event)
  local knight = Bodies.actor(g, Stats.owner(g, event.owner))
  if knight and Capabilities.attrition(g) then
    Chain.kill(g, knight, event.weapon)
  end
end
-- The mode's consequences (run/modes.lua: reward): the chapel counts souls.
local function rewards(g, event)
  Modes.act(g, 'reward', event)
end
-- A blow taken ends the taker's combo.
local function breakCombo(r)
  r.combo, r.comboTimer = 0, 0
end
local function playerHit(g, event)
  local info = event.info
  local r = Stats.controlled(g)
  r.damageTaken = r.damageTaken + (info.requested or info.amount)
  Telemetry.add(g, 'hitsTaken')
  -- The pacing director's intensity (run/spawner.lua).
  g.intensity = (g.intensity or 0) + (info.requested or info.amount or 0)
  Telemetry.add(g, 'damageTaken', info.lost or 0)
  breakCombo(r)
  Chain.broken(Roles.controlled(g))
end
-- Another knight hit: his own damage record and combo (plan v11 E3d).
local function knightHit(g, event)
  local info = event.info
  local r = Stats.record(g, event.knight.id)
  r.damageTaken = r.damageTaken + (info.requested or info.amount)
  breakCombo(r)
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
-- A wounded guardian spills what it took: the fight must not end on empty guns.
-- What a body drops as it enters a phase lies where the knight can take it: beyond the body's
-- edge on his side, side by side, never under the body itself (0.42: it lay 0.15 m from the
-- middle of a living Margrave, out of reach until he was drawn away). Stone there: at his feet.
local function spill(g, event)
  local stage = Archetypes.phase(event.enemy)
  local e, p = event.enemy, Roles.controlled(g)
  local dx, dz = p.x - e.x, p.z - e.z
  local d = math.sqrt(dx * dx + dz * dz)
  local nx, nz = 0, 1
  if d > 1e-6 then
    nx, nz = dx / d, dz / d
  end
  local out = math.min(d, Rules.radius(e) + K.dropOut)
  for i, drop in ipairs(stage and stage.drops or {}) do
    local side = (i - 1) * K.dropSpacing
    local x, z = e.x + nx * out - nz * side, e.z + nz * out + nx * side
    if Arena.solid(g.world, x, z, 0) then
      x, z = p.x, p.z
    end
    Spawn.make(g, 'pickup', {
      x = x,
      z = z,
      level = p.level,
      kind = drop.kind,
      amount = drop.amount,
    })
  end
end
function Listeners.attach(g)
  local bus = g.bus
  bus:on('sim', 'EnemyPhaseChanged', function(e)
    spill(g, e)
  end)
  bus:on('sim', 'VolleyResolved', function(e)
    Destruction.volley(g, e)
  end, Tuning.scenery.listenerOrder)
  bus:on('sim', 'ChargeExploded', function(e)
    Destruction.blast(g, e.charge)
  end, Tuning.scenery.listenerOrder)
  bus:on('sim', 'BodyHit', function(e)
    rallyBack(g, e)
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
  end, 10) -- constant: listener order
  bus:on('sim', 'EnemyKilled', function(e)
    Corpse.begin(e.enemy, e.health, math.max(0, e.damage - e.health), e.source)
  end, 15) -- constant: listener order
  bus:on('sim', 'EnemyKilled', function(e)
    score(g, e)
    chain(g, e)
  end, 20) -- constant: listener order
  -- The mode's rewards come after the score and combo (the order in the header above).
  local rewardOrder = 30 -- constant: listener order
  bus:on('sim', 'EnemyKilled', function(e)
    rewards(g, e)
  end, rewardOrder)
  -- An execution pays the mode its own way, kill or not (run/modes.lua: executed).
  bus:on('sim', 'Executed', function(e)
    Modes.act(g, 'executed', e)
  end, rewardOrder)
  bus:on('sim', 'PlayerHit', function(e)
    rallyOpens(g, e.info)
    Sigils.hurt(Roles.controlled(g), e)
    playerHit(g, e)
  end, 10) -- constant: listener order
  bus:on('sim', 'PlayerHit', function(e)
    hitStop(g, e)
  end, 20) -- constant: listener order
  bus:on('sim', 'KnightHit', function(e)
    knightHit(g, e)
  end)
  Reactions.attach(g, bus, Tuning.reactionOrder)
  -- The presentation's own listeners, when one is loaded (feedback/install.lua).
  Presentation.attach(g)
end
return Listeners
