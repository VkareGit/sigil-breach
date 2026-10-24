-- Read-only sampling of authoritative action clocks. New kinds may register
-- a duration source without adding presentation branches to creature animation.
local Registry = require('src.core.registry')
local Archetypes = require('src.content.enemies')
local Defaults = require('src.content.animation_timing')
local ActionPhase = {}
local durations = Registry:new('action phase duration', function(sampler, id)
  assert(type(sampler) == 'function', 'action phase ' .. id .. ': expected duration sampler')
end)
local function finitePositive(value)
  return type(value) == 'number' and value == value and value > 0 and value < math.huge
end
local function attack(e)
  local spec = e.attackSpec
  if spec and (not e.attackKind or spec.id == e.attackKind) then
    return spec
  end
  -- Catalogue poses and restored samples can name a move without retaining
  -- its cached specification. Looking up data must never repair live state.
  local archetype = Archetypes.of(e)
  local attacks = archetype and archetype.attacks or {}
  for _, candidate in ipairs(attacks) do
    if candidate.id == e.attackKind then
      return candidate
    end
  end
  return attacks[1] or {}
end
function ActionPhase.register(id, sampler)
  assert(not durations:has(id), 'action phase duration already registered: ' .. id)
  return durations:register(id, sampler)
end
function ActionPhase.unregister(id)
  return durations:unregister(id)
end
ActionPhase.register('charge', function(e)
  return e.chargeTime
end)
function ActionPhase.sample(e, state)
  state = state or e.ai
  local spec = attack(e)
  local elapsed = type(e.phase) == 'number' and e.phase or 0
  local duration
  if state == 'windup' then
    duration = finitePositive(e.windupDuration) and e.windupDuration
      or spec.windup
      or Defaults.windup
    elapsed = duration - (e.windup or duration)
  elseif state == 'strike' then
    local sampler = durations:find(spec.kind)
    duration = sampler and sampler(e, spec) or spec.duration
    if not finitePositive(duration) then
      duration = Defaults.strike
    end
  elseif state == 'recover' then
    duration = finitePositive(e.recover) and elapsed + e.recover or spec.recover or Defaults.recover
  else
    return 0
  end
  if not finitePositive(duration) or elapsed ~= elapsed then
    return 0
  end
  return math.max(0, math.min(1, elapsed / duration))
end
return ActionPhase
