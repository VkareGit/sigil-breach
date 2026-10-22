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

function Outcomes.enemy(g, enemy, damage, source)
  if enemy.hp <= 0 or not validDamage(damage) then
    return
  end
  local healthDamage = math.min(enemy.hp, damage)
  enemy.hp = math.max(0, enemy.hp - damage)
  enemy.hit, enemy.awake = Defaults.hitFlash, true
  emit(g, 'BodyHit', { enemy = enemy, health = healthDamage, source = source })
  if enemy.hp > 0 then
    return
  end
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

-- Wall slams use this receipt without applying a second shove or damage pass.
function Outcomes.recordPlayerDamage(g, info)
  local player = g.player
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
-- for the knight's own powder charge.
function Outcomes.player(g, amount, x, z, packet, source)
  local player = g.player
  if type(amount) == 'table' then
    packet, amount = amount, amount.base
  end
  packet = packet or { base = amount, impact = 0 }
  if packet.base ~= amount then
    packet =
      { base = amount, impact = packet.impact, push = packet.push, damageType = packet.damageType }
  end
  if not validDamage(amount) then
    return
  end
  if g.state ~= 'playing' or not Capabilities.vulnerable(g) then
    return
  end
  if player.invuln > 0 then
    -- Only a demon's blow can be dodged perfectly (not the knight's own charge).
    if (player.dashTimer or 0) > 0 and source ~= 'self' then
      Dodge.perfect(g, packet, type(source) == 'table' and source or nil)
    end
    return
  end

  local healthDamage, absorbed, overkill, incoming, events = Rules.hitPlayer(g, packet, x, z)
  events = events or {}
  g:recordPlayerDamage({
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
  })
  player.invuln = Rules.playerBody().iframes
  if player.hp <= 0 then
    player.hp, g.state = 0, 'dead'
    Presentation.capture(g, false)
    -- What a death means is the mode's (run/modes.lua: lose).
    Modes.act(g, 'lose')
  end
end

return Outcomes
