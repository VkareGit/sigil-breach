-- Rules own armor, damage and impulse mathematics. This module applies a
-- resolved blow to the session once and announces it: BodyHit, EnemyKilled,
-- PlayerHit (session/event_catalog.lua); a blow during a dodge is the dodge's
-- (combat/dodge.lua). What follows for the
-- simulation (score, healing, rewards, pacing) are 'sim' listeners in
-- session/listeners.lua; what is seen and heard are 'present' listeners in
-- feedback/listeners.lua.
local Capabilities = require('src.session.capabilities')
local Presentation = require('src.session.presentation')
local Modes = require('src.run.modes')
local Rules = require('src.combat.rules')
local Dodge = require('src.combat.dodge')
local Defaults = require('src.content.combat_defaults')
local Effects = require('src.combat.effects')
local Bodies = require('src.combat.bodies')
local Outcomes = {}

local function validDamage(amount)
  return type(amount) == 'number' and amount == amount and amount > 0 and amount ~= math.huge
end
local function emit(g, kind, event)
  if g.bus then
    g.bus:emit(kind, event)
  end
  return event
end
Outcomes.emit = emit

function Outcomes.enemy(g, enemy, damage, source, payload)
  if enemy.hp <= 0 or not validDamage(damage) then
    return
  end
  local healthDamage = math.min(enemy.hp, damage)
  enemy.hp = math.max(0, enemy.hp - damage)
  enemy.hit, enemy.awake = Defaults.hitFlash, true
  emit(g, 'BodyHit', { enemy = enemy, health = healthDamage, source = source })
  if enemy.hp > 0 then
    Effects.apply(g, enemy, payload and payload.effects, source)
    return
  end
  Effects.clear(enemy)
  -- Off balance at the moment of death, and why (combat/rules/balance.lua:
  -- offBalance, the one decision): the break kill of the push-forward loop
  -- (session/listeners.lua) and its measurement read this result.
  local causes = {}
  local offBalance = Rules.offBalance(enemy, causes)
  emit(g, 'EnemyKilled', {
    enemy = enemy,
    damage = damage,
    health = healthDamage,
    source = source,
    offBalance = offBalance,
    causes = causes,
  })
end

-- A blow from any side on a creature (plan v10 V2: an ally, a rival demon):
-- the creatures' law, as a blast resolves it (armour, resistances, guard and
-- shove from the source's place), never the knight's shield.
local function creatureBlow(g, target, amount, x, z, packet, source)
  local Damage = require('src.combat.damage')
  local Ground = require('src.physics.ground')
  local blow = {
    base = amount,
    impact = packet and packet.impact or 0,
    push = packet and packet.push,
    damageType = packet and packet.damageType,
    effects = packet and packet.effects,
  }
  local dealt, _, impact, push = Damage.resolve(blow, target, 0)
  local health = math.min(target.hp, dealt)
  Outcomes.enemy(g, target, dealt, 'creature', blow)
  local y = Ground.of(g.world, target) + (Rules.body(target).aimY or 1)
  require('src.combat.combat').react(
    g,
    target,
    impact,
    true,
    { target.x, y, target.z },
    nil,
    health,
    { push = push, direction = { target.x - (x or target.x), target.z - (z or target.z) } },
    { value = health, kill = target.hp <= 0, source = source }
  )
end
-- One entry for harm to any body (plan v10 V2): a knight goes through the
-- knight's law (shield, guard, dodge), a creature through the creatures'.
-- Arguments as Outcomes.player, with the target first.
function Outcomes.body(g, target, amount, x, z, packet, source, context)
  if Bodies.isKnight(g, target) then
    return Outcomes.player(g, amount, x, z, packet, source, context, target)
  end
  if type(amount) == 'table' then
    packet, amount = amount, amount.base
  end
  if target.hp <= 0 or not validDamage(amount) or g.state ~= 'playing' then
    return
  end
  creatureBlow(g, target, amount, x, z, packet, source)
end

-- Wall slams use this receipt without applying a second shove or damage pass.
function Outcomes.recordPlayerDamage(g, info)
  local player = Bodies.controlled(g)
  g.playerDamageReport = {
    incoming = info.amount,
    healthDamage = info.lost,
    absorbed = info.absorbed,
    overkill = info.overkill,
    hp = player.hp,
    armor = player.armor,
    damageType = info.damageType or 'physical',
    staggered = info.staggered,
    wounded = info.wounded,
    source = info.source or 'attack',
  }
  emit(g, 'PlayerHit', { info = info })
end

-- The amount is incoming damage; a packet adds type and physical impulse.
-- source (optional): the demon whose own body delivered the blow, or 'self'
-- for the knight's own powder charge. knight (optional): which knight
-- (default the controlled one). Only the controlled knight's harm is the
-- session's report, its feedback and its death; another knight is hit
-- (KnightHit) and falls (KnightFell) without ending the fight.
function Outcomes.player(g, amount, x, z, packet, source, context, knight)
  local player = knight or Bodies.controlled(g)
  local controlled = player == Bodies.controlled(g)
  local ongoing = context and context.ongoing
  if type(amount) == 'table' then
    packet, amount = amount, amount.base
  end
  packet = packet or { base = amount, impact = 0 }
  if packet.base ~= amount then
    packet = {
      base = amount,
      impact = packet.impact,
      push = packet.push,
      damageType = packet.damageType,
      effects = packet.effects,
    }
  end
  if not validDamage(amount) then
    return
  end
  if g.state ~= 'playing' or not Capabilities.vulnerable(g) then
    return
  end
  if not ongoing and player.invuln > 0 then
    -- Only a demon's blow can be dodged perfectly (not the knight's own charge).
    if (player.dashTimer or 0) > 0 and source ~= 'self' then
      Dodge.perfect(g, packet, type(source) == 'table' and source or nil, player)
    end
    return
  end

  local healthDamage, absorbed, overkill, incoming, events =
    Rules.hitPlayer(g, packet, x, z, player)
  events = events or {}
  local info = {
    amount = incoming or amount,
    requested = amount,
    lost = healthDamage,
    absorbed = absorbed,
    overkill = overkill,
    impact = packet.impact,
    damageType = packet.damageType,
    x = x,
    z = z,
    staggered = events.staggered,
    wounded = events.wounded,
    source = ongoing and source or nil,
  }
  if controlled then
    g:recordPlayerDamage(info)
  else
    emit(g, 'KnightHit', { knight = player, info = info })
  end
  if not ongoing then
    player.invuln = Rules.playerBody().iframes
  end
  if healthDamage > 0 then
    Effects.apply(g, player, packet.effects, context and context.effectSource or source)
  end
  if player.hp <= 0 then
    Effects.clear(player)
    player.hp = 0
    if not controlled then
      emit(g, 'KnightFell', { knight = player })
      return
    end
    g.state = 'dead'
    Presentation.capture(g, false)
    -- What a death means is the mode's (run/modes.lua: lose).
    Modes.act(g, 'lose')
  end
end

return Outcomes
