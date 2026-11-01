-- Casting the knight's abilities (0.24 F4). One caster for every ability:
-- the same gates (in play, armed, ready), the same live record (uses left,
-- ready time) and a delivery kind that does the rest. The powder charge is
-- the 'throw' kind (combat/explosives.lua); 'bolt' looses the same missile a
-- demon does (enemies/ranged_kinds.lua). A new kind of equipment is an entry in
-- combat/action_kinds.lua with cast; the caster, the input and the HUD do not
-- change. An ability pays its cost at release, so an interrupted one costs
-- nothing.
local Capabilities = require('src.session.capabilities')
local Signal = require('src.session.signal')
local Abilities = require('src.content.abilities')
local Explosives = require('src.combat.explosives')
local ActionKinds = require('src.combat.action_kinds')
local Attributes = require('src.combat.attributes')
local Caster = require('src.combat.caster')
local Resources = require('src.combat.resources')
local Roles = require('src.core.roles')
local Bodies = require('src.combat.bodies')
local Text = require('src.content.text')
local Characters = require('src.content.characters')
local Presentation = require('src.session.presentation')
local Rules = require('src.combat.rules')
local Cast = {}
Cast.kinds = ActionKinds:view()
ActionKinds:register('throw', {
  cast = function(g, action, caster)
    Explosives.launch(g, action, caster)
    return true
  end,
})
-- The ability in a slot of an actor's loadout (default the controlled
-- knight's) and its live record.
function Cast.slot(g, slot, actor)
  local p = actor or Roles.controlled(g)
  local id = p.abilities and p.abilities[slot or 1]
  local ability = id and Abilities:find(id)
  return ability, ability and p.abilityState[id], id
end
local function valid(state, ability)
  local uses = state.uses
  return type(uses) == 'number'
    and uses == uses
    and uses >= 0
    and uses <= ability.capacity
    and uses == math.floor(uses)
end
local function deliverer(ability)
  local kind = Cast.kinds[ability.action.kind]
  assert(
    kind and type(kind.cast) == 'function',
    'ability ' .. ability.id .. ': unsupported delivery kind ' .. tostring(ability.action.kind)
  )
  return kind.cast
end
-- One release: the action goes off and is paid for. Returns true when it went.
local function release(g, ability, state, actor, slot)
  if not Resources.can(actor, ability.cost) then
    return false
  end
  if not deliverer(ability)(g, ability.action, Caster.actor(g, actor)) then
    return false
  end
  Resources.spend(actor, ability.cost)
  state.uses = state.uses - (ability.cost.uses or 0)
  state.readyAt = g.elapsed + ability.action.cooldown
  Signal(g, 'AbilityCast', {
    ability = ability,
    slot = slot,
    actor = actor.id,
    byControlled = actor == Roles.controlled(g),
  })
  return true
end
ActionKinds:register('drink', {
  cast = function(g, action, caster)
    local actor = caster.body
    actor.hp = math.min(Characters.maxHp(actor), actor.hp + action.heal)
    Presentation.cue(g, 'pickup', 0.5)
    return true
  end,
})
local function finish(g, actor, interrupted)
  local casting = actor.casting
  actor.casting = nil
  Signal(g, 'CastEnded', { actor = actor.id, ability = casting.id, interrupted = interrupted })
end
-- A cast that takes time lives in actor.casting = { id, slot, phase, left, next }
-- and is advanced after the trigger (systems/knight.lua): a windup, then the
-- pulses of a channel or a toggle. Whatever a condition forbids stops it unpaid.
local function pulsing(ability)
  return ability.channel or ability.toggle
end
local function begin(actor, ability, slot)
  local pulses = pulsing(ability)
  local windup = ability.action.windup
  if ability.posture then
    Rules.addCondition(actor, ability.posture, windup)
  end
  actor.casting = {
    id = ability.id,
    slot = slot,
    phase = windup > 0 and 'windup' or 'pulses',
    left = windup > 0 and windup or (pulses.time or math.huge),
    next = pulses and pulses.every or 0,
  }
end
function Cast.update(g, dt, actor)
  local casting = actor.casting
  if not casting then
    return
  end
  local ability, state = Cast.slot(g, casting.slot, actor)
  if not ability or actor.hp <= 0 or Attributes.forbids(actor, 'cast') then
    return finish(g, actor, true)
  end
  casting.left = casting.left - dt
  if casting.phase == 'windup' then
    if casting.left > 0 then
      return
    end
    local pulses = pulsing(ability)
    if not release(g, ability, state, actor, casting.slot) or not pulses then
      return finish(g, actor, false)
    end
    casting.phase, casting.left = 'pulses', pulses.time or math.huge
    return
  end
  casting.next = casting.next - dt
  while casting.next <= 0 do
    casting.next = casting.next + pulsing(ability).every
    if not release(g, ability, state, actor, casting.slot) then
      return finish(g, actor, false)
    end
  end
  if casting.left <= 0 then
    finish(g, actor, false)
  end
end
-- A blow stops what a blow can stop: nothing is paid for it.
function Cast.interrupt(g, actor)
  local casting = actor.casting
  local ability = casting and Abilities:find(casting.id)
  if ability and ability.fragile then
    if ability.posture then
      actor.conditions[ability.posture] = nil
    end
    finish(g, actor, true)
  end
end
-- Cast the ability in slot (default 1, the Q key) for who (an actor's id;
-- default the controlled knight). Returns true when it went off. Casting a
-- toggle that runs stops it.
function Cast.cast(g, slot, who)
  slot = slot or 1
  local actor = Bodies.actor(g, who)
  if not actor or (actor.hp or 1) <= 0 then
    return false
  end
  local ability, state = Cast.slot(g, slot, actor)
  if
    not ability
    or not state
    or g.state ~= 'playing'
    or g.map
    or g.help
    or (state.readyAt or 0) > g.elapsed
    or not valid(state, ability)
  then
    return false
  end
  deliverer(ability)
  if actor.casting then
    if actor.casting.id == ability.id and ability.toggle then
      finish(g, actor, false)
      return true
    end
    return false
  end
  if Attributes.forbids(actor, 'cast') then
    return false
  end
  if state.uses < (ability.cost.uses or 0) or (state.uses <= 0 and ability.cost.uses) then
    if actor == Roles.controlled(g) then
      g:notify(Text.get(ability.empty), Abilities.noticeTime)
    end
    return false
  end
  if not Resources.can(actor, ability.cost) then
    return false
  end
  if ability.action.windup > 0 or pulsing(ability) then
    begin(actor, ability, slot)
    return true
  end
  return release(g, ability, state, actor, slot)
end
-- Every ability of the loadout back at rest (a new life, a reset).
function Cast.rest(g, actor)
  for _, state in pairs((actor or Roles.controlled(g)).abilityState or {}) do
    state.readyAt = 0
  end
end
return Cast
