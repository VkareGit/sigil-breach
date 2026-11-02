-- Rules own armor, damage and impulse mathematics. This module applies a
-- resolved blow to the session once and announces it: BodyHit, EnemyKilled,
-- PlayerHit (session/event_catalog.lua); a blow during a dodge is the dodge's
-- (combat/dodge.lua). What follows for the
-- simulation (score, healing, rewards, pacing) are 'sim' listeners in
-- session/listeners.lua; what is seen and heard are 'present' listeners in
-- feedback/listeners.lua.
local Hit = require('src.combat.hit')
local Observation = require('src.combat.observation')
local Ground = require('src.physics.ground')
local Context = require('src.session.context')
local Capabilities = require('src.session.capabilities')
local Presentation = require('src.session.presentation')
local Modes = require('src.session.modes')
local Rules = require('src.combat.rules')
local Dodge = require('src.combat.dodge')
local Defaults = require('src.content.combat_defaults')
local Effects = require('src.combat.effects')
local Bodies = require('src.combat.bodies')
local Pools = require('src.session.world')
local Cast = require('src.combat.abilities')
local Encounter = require('src.enemies.encounter')
local DamageTypes = require('src.content.damage_types')
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

-- owner (plan v11 E3d): the id of the body whose action began the damage
-- chain (a knight's id, a demon's id, nil: unknown), carried by every
-- consequence: the hit and the death name it, the body's shove remembers it
-- (slams, collisions) and an effect it applies keeps it.
-- weapon (optional): the id of the weapon behind it.
function Outcomes.enemy(g, enemy, damage, source, payload, owner, weapon)
  if enemy.hp <= 0 or not validDamage(damage) then
    return 0
  end
  local healthDamage = math.min(enemy.hp, damage)
  enemy.hp = math.max(0, enemy.hp - damage)
  Encounter.advance(g, enemy)
  enemy.hit, enemy.awake = Defaults.hitFlash, true
  if owner ~= nil then
    enemy.pushOwner = owner
  end
  emit(g, 'BodyHit', {
    enemy = enemy,
    health = healthDamage,
    source = source,
    owner = owner,
    weapon = weapon,
    target = enemy.id,
  })
  if enemy.hp > 0 then
    if payload and payload.effects then
      Effects.apply(g, enemy, payload.effects, Effects.origin(g, owner))
    end
    return healthDamage
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
    owner = owner,
    weapon = weapon,
    target = enemy.id,
  })
  return healthDamage
end

-- A blow from any side on a creature (plan v10 V2: an ally, a rival demon):
-- the creatures' law, as a blast resolves it (armour, resistances, guard and
-- shove from the source's place), never the knight's shield.
local function creatureBlow(g, target, amount, x, z, packet, source, context)
  local blow = {
    base = amount,
    impact = packet and packet.impact or 0,
    push = packet and packet.push,
    damageType = packet and packet.damageType,
    effects = packet and packet.effects,
  }
  local dealt, _, impact, push = Hit.measure(blow, target, 0)
  -- The chain belongs to the body that struck (a demon: no knight behind it).
  local origin = context and context.effectSource or source
  local owner = type(origin) == 'table' and origin.id or nil
  local y = Ground.of(g.world, target) + (Rules.body(target).aimY or 1)
  Hit.land(g, target, { damage = dealt, impact = impact }, {
    source = 'creature',
    payload = blow,
    owner = owner,
    strong = true,
    point = { target.x, y, target.z },
    extra = {
      push = push,
      direction = { target.x - (x or target.x), target.z - (z or target.z) },
      origin = type(source) == 'table' and source or { x = x or target.x, z = z or target.z },
    },
    numbered = true,
    label = source,
  })
end
-- One entry for harm to any body (plan v10 V2): a knight goes through the
-- knight's law (shield, guard, dodge), a creature through the creatures'.
-- Arguments as Outcomes.player, with the target first.
function Outcomes.body(g, target, amount, x, z, packet, source, context)
  if Bodies.law(g, target) == 'knight' then
    return Outcomes.player(g, amount, x, z, packet, source, context, target)
  end
  if type(amount) == 'table' then
    packet, amount = amount, amount.base
  end
  if target.hp <= 0 or not validDamage(amount) or g.state ~= 'playing' then
    return
  end
  creatureBlow(g, target, amount, x, z, packet, source, context)
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
    damageType = info.damageType or DamageTypes.fallback,
    staggered = info.staggered,
    wounded = info.wounded,
    source = info.source or 'attack',
  }
  emit(g, 'PlayerHit', { info = info })
end

-- Who dealt a blow to the knight, as the death screen names it: the text key of a creature's
-- name, 'death_by_self' for his own charge, or nil when nothing is known. A missile or a burn
-- names the body that owns it, alive or fallen.
local function harmOf(g, source, context)
  if source == 'self' then
    return 'death_by_self'
  end
  local id = context and context.owner or (type(source) == 'table' and source.id)
  local body = type(source) == 'table' and source.kind and source or (id and Pools.get(g, id))
  return body and body.kind and Rules.archetype(body).name or nil
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
    owner = context and context.owner,
    contact = context and context.contact,
  }
  if controlled then
    if healthDamage > 0 then
      g.lastHarm = harmOf(g, source, context)
    end
    g:recordPlayerDamage(info)
  else
    emit(g, 'KnightHit', { knight = player, info = info })
  end
  if not ongoing then
    player.invuln = Rules.playerBody(player).iframes
    Cast.interrupt(g, player)
  end
  if healthDamage > 0 then
    Effects.apply(g, player, packet.effects, context and context.effectSource or source)
  end
  if player.hp <= 0 then
    Effects.clear(player)
    player.hp = 0
    if not controlled then
      -- His observations end with him (plan v11 E4).
      Observation.invalidateActor(g, player)
      emit(g, 'KnightFell', { knight = player })
      Context.reset(g, player)
      return
    end
    g.state = 'dead'
    Presentation.capture(g, false)
    -- What a death means is the mode's (run/modes.lua: lose).
    Modes.act(g, 'lose')
  end
end

return Outcomes
