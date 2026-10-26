-- Optional consequences of a damaging contact. Definitions are immutable;
-- ongoing clocks/provenance belong to the affected body, never the weapon.
-- Pulses re-enter the shared damage outcomes and cannot recursively add effects.
local Registry = require('src.core.registry')
local Definitions = require('src.content.defs.effect')
local Damage = require('src.combat.damage')
local Rules = require('src.combat.rules')
local Signal = require('src.session.signal')
local Capabilities = require('src.session.capabilities')
local Pools = require('src.session.world')
local Bodies = require('src.combat.bodies')
local Effects = {}
Effects.kinds = Registry:new('effect handlers', function(entry, id)
  Definitions.kinds:get(id)
  assert(type(entry.apply) == 'function', 'effect handler ' .. id .. ' needs apply')
  assert(
    entry.tick == nil or type(entry.tick) == 'function',
    'effect handler ' .. id .. ' needs a callable tick'
  )
end)
-- Who applied an effect: an explicit { side, id }, a body (its side and id;
-- the controlled knight is recorded without an id), else the knights.
local function sourceOf(g, source)
  if type(source) == 'table' and source.side then
    return source.side, source.id
  end
  if type(source) == 'table' and source ~= Bodies.controlled(g) then
    return Bodies.side(g, source), source.id
  end
  return 'knight', nil
end
local function aliveSource(g, instance)
  if instance.sourceId == nil and instance.sourceSide == 'knight' then
    return Bodies.controlled(g).hp > 0
  end
  local source = Pools.get(g, instance.sourceId)
  return source ~= nil and source.hp > 0
end
function Effects.cancel(target, id)
  local instances = target.effectState
  if not instances then
    return false
  end
  for index, instance in ipairs(instances) do
    if instance.definition.id == id then
      table.remove(instances, index)
      if #instances == 0 then
        target.effectState = nil
      end
      return true
    end
  end
  return false
end
function Effects.clear(target)
  target.effectState = nil
end
Effects.kinds:register('condition', {
  apply = function(_, target, definition)
    Rules.addCondition(target, definition.condition, definition.duration)
  end,
})
Effects.kinds:register('periodic', {
  apply = function(g, target, definition, source)
    local instances = target.effectState or {}
    target.effectState = instances
    local index = #instances + 1
    for i, old in ipairs(instances) do
      if old.definition.id == definition.id then
        if definition.stacking == 'refresh' then
          -- Keep the original payload and pulse phase; a stream of pellets
          -- can extend exposure but cannot multiply or postpone its pulses.
          old.remaining = math.max(old.remaining, definition.duration)
          return
        end
        index = i
        break
      end
    end
    local side, id = sourceOf(g, source)
    instances[index] = {
      definition = definition,
      remaining = definition.duration,
      untilPulse = definition.interval,
      bornAt = g.elapsed,
      sourceSide = side,
      sourceId = id,
    }
  end,
  tick = function(g, target, instance)
    local definition = instance.definition
    local before = target.hp
    if Bodies.isKnight(g, target) then
      -- Exposure already began; it is not a new dodgeable contact and does
      -- not grant or consume contact invulnerability.
      g:damageBody(
        target,
        definition.packet,
        nil,
        nil,
        nil,
        'effect:' .. definition.id,
        { ongoing = true }
      )
    else
      local damage = Damage.resolve(definition.packet, target, 0)
      g:damageEnemy(target, damage, 'effect:' .. definition.id)
    end
    local receipt =
      { target = target, definition = definition, health = math.max(0, before - target.hp) }
    Signal(g, 'EffectPulse', receipt)
  end,
})
function Effects.apply(g, target, definitions, source)
  if not definitions or target.hp <= 0 then
    return
  end
  for _, definition in ipairs(definitions) do
    Effects.kinds:get(definition.kind)
  end
  for _, definition in ipairs(definitions) do
    Effects.kinds:get(definition.kind).apply(g, target, definition, source)
    Signal(g, 'EffectApplied', { target = target, definition = definition })
  end
end
local function updateBody(g, target, dt)
  local instances = target.effectState
  if not instances then
    return
  end
  if target.hp <= 0 then
    Effects.clear(target)
    return
  end
  local index = 1
  while index <= #instances do
    local instance = instances[index]
    local definition = instance.definition
    local remove = definition.cancelOnSourceDeath and not aliveSource(g, instance)
    if not remove and instance.bornAt ~= g.elapsed then
      local active = math.min(dt, instance.remaining)
      instance.remaining = instance.remaining - active
      instance.untilPulse = instance.untilPulse - active
      while instance.untilPulse <= 1e-9 and target.hp > 0 do
        Effects.kinds:get(definition.kind).tick(g, target, instance)
        instance.untilPulse = instance.untilPulse + definition.interval
      end
      remove = instance.remaining <= 1e-9 or target.hp <= 0
    end
    if remove then
      table.remove(instances, index)
    else
      index = index + 1
    end
  end
  if #instances == 0 then
    target.effectState = nil
  end
end
function Effects.update(g, dt)
  if g.state ~= 'playing' or not Capabilities.groundActs(g) or Capabilities.held(g) then
    return
  end
  for _, knight in ipairs(Bodies.knights(g)) do
    updateBody(g, knight, dt)
  end
  for _, enemy in ipairs(Pools.of(g, 'enemies')) do
    if g.state ~= 'playing' then
      break
    end
    updateBody(g, enemy, dt)
  end
end
return Effects
