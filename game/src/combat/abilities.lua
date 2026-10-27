-- Casting the knight's abilities (0.24 F4). One caster for every ability:
-- the same gates (in play, armed, ready), the same live record (uses left,
-- ready time) and a delivery kind that does the rest. The powder charge is
-- the 'throw' kind (combat/explosives.lua); 'bolt' looses a missile that
-- hurts demons (combat/projectiles.lua, side 'knight'; no equipment uses it
-- yet). The knight is a man without magic: supernatural attacks belong to the
-- demons. A new kind of equipment is a new entry in Cast.kinds; the caster,
-- the input and the HUD do not change.
--   kinds[kind](g, ability, actor)  launch it for the casting actor; true when it went off
local Capabilities = require('src.session.capabilities')
local Signal = require('src.session.signal')
local Spawn = require('src.session.spawn')
local Abilities = require('src.content.abilities')
local Defaults = require('src.content.combat_defaults')
local B = require('src.combat.ballistics')
local Explosives = require('src.combat.explosives')
local Registry = require('src.core.registry')
local Action = require('src.content.defs.action')
local Roles = require('src.core.roles')
local Bodies = require('src.combat.bodies')
local Text = require('src.content.text')
local Cast = {}
Cast.registry = Registry:new('equipment deliveries', function(handler, id)
  Action.kinds:get(id)
  assert(type(handler) == 'function', 'equipment delivery ' .. id .. ' needs a function')
end)
Cast.kinds = Cast.registry:view()
function Cast.register(id, handler)
  return Cast.registry:register(id, handler)
end
Cast.register('throw', function(g, ability, actor)
  Explosives.launch(g, ability.action, actor)
  return true
end)
-- A missile from the eye along the aim, carrying the action's packet.
Cast.register('bolt', function(g, ability, actor)
  local action, p = ability.action, actor or Roles.controlled(g)
  local x, y, z = B.origin(g, p)
  local dx, dy, dz = B.direction(p.yaw, p.pitch)
  local reach = Defaults.attacks.muzzle
  Spawn.make(g, 'projectile', {
    x = x + dx * reach,
    y = y + dy * reach,
    z = z + dz * reach,
    vx = dx * action.speed,
    vy = dy * action.speed,
    vz = dz * action.speed,
    life = Defaults.attacks.boltLife,
    big = action.big or false,
    color = action.color,
    side = 'knight',
    owner = p.id,
    packet = action.packet,
    radius = action.radius,
  })
  return true
end)
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
-- Cast the ability in slot (default 1, the Q key) for who (an actor's id;
-- default the controlled knight). Returns true when it went off.
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
    or not Capabilities.armed(g)
    or (state.readyAt or 0) > g.elapsed
    or not valid(state, ability)
  then
    return false
  end
  local deliver = Cast.kinds[ability.action.kind]
  assert(
    type(deliver) == 'function',
    'ability ' .. ability.id .. ': unsupported delivery kind ' .. tostring(ability.action.kind)
  )
  if state.uses <= 0 then
    if actor == Roles.controlled(g) then
      g:notify(Text.get(ability.empty), Abilities.noticeTime)
    end
    return false
  end
  if not deliver(g, ability, actor) then
    return false
  end
  state.uses = state.uses - 1
  state.readyAt = g.elapsed + ability.action.cooldown
  Signal(g, 'AbilityCast', {
    ability = ability,
    slot = slot,
    actor = actor.id,
    byControlled = actor == Roles.controlled(g),
  })
  return true
end
-- Every ability of the loadout back at rest (a new life, a reset).
function Cast.rest(g, actor)
  for _, state in pairs((actor or Roles.controlled(g)).abilityState or {}) do
    state.readyAt = 0
  end
end
return Cast
