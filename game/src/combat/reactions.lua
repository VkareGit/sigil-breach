-- What a body's own fighting sets off (content/defs/reaction.lua). Sources run
-- in a fixed order: weapon, the run's modifier, character, conditions. What a
-- reaction causes sets off no reaction, as an effect's pulse adds no effects.
local Definitions = require('src.content.defs.reaction')
local Characters = require('src.content.characters')
local Conditions = require('src.content.conditions')
local Weapons = require('src.content.weapons')
local Tuning = require('src.content.tuning')
local Registry = require('src.core.registry')
local Ground = require('src.physics.ground')
local Pools = require('src.session.world')
local Bodies = require('src.combat.bodies')
local Caster = require('src.combat.caster')
local Kinds = require('src.combat.action_kinds')
local Effects = require('src.combat.effects')
local Explosives = require('src.combat.explosives')
local Loadout = require('src.combat.loadout')
local Telemetry = require('src.combat.telemetry')
local Reactions = {}
Reactions.kinds = Registry:new('reaction handlers', function(entry, id)
  Definitions.kinds:get(id)
  assert(type(entry.run) == 'function', 'reaction handler ' .. id .. ' needs run')
end)
Reactions.kinds:register('heal', {
  run = function(g, effect, _, target)
    local gained = math.min(Characters.maxHp(target), target.hp + effect.amount) - target.hp
    target.hp = target.hp + math.max(0, gained)
    Telemetry.add(g, 'healed', math.max(0, gained))
  end,
})
Reactions.kinds:register('blast', {
  run = function(g, effect, body, _, at)
    local y = at.y or Ground.of(g.world, at) + Tuning.explosives.aimHeight
    local from = { x = at.x, y = y, z = at.z, owner = body.id }
    Explosives.strike(g, from, effect.radius, effect.blast, 'reaction')
  end,
})
-- An action at the place, on behalf of the body (combat/action_kinds.lua: cast).
Reactions.kinds:register('action', {
  run = function(g, effect, body, _, at)
    local y = at.y or Ground.of(g.world, at) + Tuning.explosives.aimHeight
    Kinds:get(effect.action.kind).cast(g, effect.action, Caster.point(g, body, at.x, y, at.z))
  end,
})
local function run(g, list, on, body, target, at)
  for i = 1, list and #list or 0 do
    local reaction = list[i]
    if reaction.on == on then
      local effect = reaction.effect
      local affected = reaction.target == 'struck' and target or body
      local handler = Reactions.kinds:find(effect.kind)
      if handler then
        handler.run(g, effect, body, affected, at)
      else
        Effects.apply(g, affected, { effect }, Effects.origin(g, body.id))
      end
    end
  end
end
-- on: the event; owner: the id of the body it belongs to; weapon: the weapon
-- behind it, when one was; target: the body struck; at: where (x, z, and y when
-- it is not a body).
function Reactions.fire(g, on, owner, weapon, target, at)
  local body = owner ~= nil and Pools.get(g, owner)
  if g.reacting or not body or body.hp <= 0 then
    return
  end
  g.reacting = true
  if weapon then
    run(g, weapon.reactions, on, body, target, at)
    Loadout.reactions(g, weapon, run, on, body, target, at)
  end
  if Bodies.isKnight(g, body) then
    run(g, Characters.of(body).reactions, on, body, target, at)
  end
  local conditions = body.conditions
  if conditions then
    for _, id in ipairs(Conditions.ids()) do
      if (conditions[id] or 0) > 0 then
        run(g, Definitions.ofCondition[id], on, body, target, at)
      end
    end
  end
  g.reacting = false
end
-- The blows of a body's hand; what follows from them (a pulse, a slam, stone
-- falling) is no new hit.
local blows = { weapon = true, ability = true, charge = true, creature = true }
local function weaponOf(event)
  return event.weapon and Weapons.get(event.weapon)
end
local function traced(g, event)
  local report = event.report
  local rays = report.rays
  if #rays == 0 then
    return
  end
  for _, ray in ipairs(rays) do
    if ray.kind ~= 'enemy' and ray.kind ~= 'range' then
      Reactions.fire(g, 'surface', report.actor, event.profile, nil, ray)
      break
    end
  end
  if report.targets == 0 then
    Reactions.fire(g, 'miss', report.actor, event.profile, nil, rays[1])
  end
end
-- A finite round tells where it ended (traced ones report with the volley).
local function ended(g, event)
  local b = event.bullet
  local shot = b.shot
  if not shot then
    return
  end
  if event.wall then
    Reactions.fire(g, 'surface', shot.shooter.id, shot.profile, nil, b)
  end
  if not event.struck and not shot.hit then
    Reactions.fire(g, 'miss', shot.shooter.id, shot.profile, nil, b)
  end
end
local function reloaded(g, event)
  if event.stage == 'close' and not event.interrupted then
    local body = Pools.get(g, event.actor)
    Reactions.fire(g, 'reload', event.actor, body and Weapons.inHand(g, nil, body), nil, body)
  end
end
-- After everything else an event sets in motion (session/listeners.lua).
function Reactions.attach(g, bus, order)
  bus:on('sim', 'ShotFired', function(e)
    Reactions.fire(g, 'shot', e.actor, e.profile, nil, Pools.get(g, e.actor))
  end, order)
  bus:on('sim', 'BodyHit', function(e)
    if blows[e.source] then
      Reactions.fire(g, 'hit', e.owner, weaponOf(e), e.enemy, e.enemy)
    end
  end, order)
  bus:on('sim', 'EnemyKilled', function(e)
    Reactions.fire(g, 'kill', e.owner, weaponOf(e), e.enemy, e.enemy)
  end, order)
  bus:on('sim', 'VolleyResolved', function(e)
    traced(g, e)
  end, order)
  bus:on('sim', 'ProjectileBurst', function(e)
    ended(g, e)
  end, order)
  bus:on('sim', 'ReloadStage', function(e)
    reloaded(g, e)
  end, order)
end
return Reactions
