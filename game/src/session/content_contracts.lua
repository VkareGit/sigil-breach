-- Validate the composition of content and simulation before creating a world.
-- Schemas own values; this boundary owns references to executable behaviours.
-- Presentation/GPU resources are deliberately absent from this contract.
local Weapons = require('src.content.weapons')
local Abilities = require('src.content.abilities')
local Archetypes = require('src.content.enemies')
local Deliveries = require('src.combat.weapon_delivery')
local Reload = require('src.combat.reload')
local Intent = require('src.player.intent')
require('src.combat.abilities')
local ActionKinds = require('src.combat.action_kinds')
local Attacks = require('src.enemies.actions')
local Effects = require('src.combat.effects')
local Reactions = require('src.combat.reactions')
local AI = require('src.enemies.ai')
local Target = require('src.enemies.target')
local Animation = require('src.enemies.animation')
local HazardDefs = require('src.content.hazards')
local Hazards = require('src.enemies.hazards')
local Contracts = {}
local function effects(value, seen)
  if type(value) ~= 'table' then
    return
  end
  seen = seen or {}
  if seen[value] then
    return
  end
  seen[value] = true
  if value.effects then
    local ids = {}
    for _, effect in ipairs(value.effects) do
      Effects.kinds:get(effect.kind)
      assert(not ids[effect.id], 'duplicate contact effect identity: ' .. effect.id)
      ids[effect.id] = true
    end
  end
  for _, child in pairs(value) do
    effects(child, seen)
  end
end
-- What a reaction does must exist and be able to act from a place.
local function reactions(list, where)
  for _, reaction in ipairs(list or {}) do
    local kind = reaction.effect.kind
    assert(Reactions.kinds:find(kind) or Effects.kinds:find(kind), where .. ': reaction ' .. kind)
    local action = reaction.effect.action
    if action then
      assert(
        type(ActionKinds:get(action.kind).cast) == 'function',
        where .. ': cannot cast ' .. action.kind
      )
    end
  end
end
function Contracts.weapon(definition)
  Deliveries:get(definition.delivery.kind)
  if definition.reload then
    local mechanism = Reload.mechanisms[definition.reload.mechanism]
    assert(
      type(mechanism) == 'table',
      'weapon ' .. definition.id .. ': unknown reload ' .. definition.reload.mechanism
    )
    assert(
      type(mechanism.duration) == 'number'
        and mechanism.duration > 0
        and mechanism.duration < math.huge,
      'weapon ' .. definition.id .. ': invalid reload duration'
    )
    for _, method in ipairs({ 'offset', 'step', 'finish', 'primed', 'label' }) do
      assert(
        type(mechanism[method]) == 'function',
        'weapon ' .. definition.id .. ': reload needs ' .. method
      )
    end
  end
  assert(Intent.modes:has(definition.trigger.mode), definition.id .. ': no trigger behaviour')
  if definition.secondary then
    Deliveries:get(definition.secondary.delivery.kind)
  end
  effects(definition)
  reactions(definition.reactions, 'weapon ' .. definition.id)
end
function Contracts.ability(definition)
  local kind = ActionKinds:get(definition.action.kind)
  assert(
    type(kind.cast) == 'function',
    'ability ' .. definition.id .. ': kind ' .. definition.action.kind .. ' cannot be cast'
  )
  effects(definition)
end
function Contracts.creature(definition)
  local movement = definition.move
  assert(
    type(AI.styles[movement.style]) == 'function',
    'creature ' .. definition.id .. ': unknown movement style ' .. tostring(movement.style)
  )
  assert(
    type(Target.strategies[movement.targeting]) == 'function',
    'creature ' .. definition.id .. ': unknown targeting strategy ' .. tostring(movement.targeting)
  )
  local motion = definition.appearance and definition.appearance.motion
  assert(
    not motion or Animation.motions:has(motion),
    'creature ' .. definition.id .. ': unknown painted motion ' .. tostring(motion)
  )
  for _, action in ipairs(definition.attacks) do
    assert(
      not action.creature or Archetypes.get(action.creature),
      'creature ' .. definition.id .. ': it calls unknown ' .. tostring(action.creature)
    )
    local executor = Attacks.kinds[action.kind]
    assert(
      type(executor) == 'table' and type(executor.execute) == 'function',
      'creature ' .. definition.id .. ': unknown attack executor ' .. action.kind
    )
  end
  effects(definition)
end
function Contracts.validate()
  for id in HazardDefs:each() do
    Hazards.kinds:get(id)
  end
  for _, definition in Weapons.registry:each() do
    Contracts.weapon(definition)
  end
  for _, definition in Abilities:each() do
    Contracts.ability(definition)
  end
  for _, definition in Archetypes.each() do
    Contracts.creature(definition)
  end
end
return Contracts
