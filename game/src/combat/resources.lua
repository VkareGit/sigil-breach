-- What an actor has of each resource (content/resources.lua). Its record is
-- actor.resources = { [id] = amount }; a character without any has none.
local Characters = require('src.content.characters')
local Resources = {}
-- Whether the actor can pay this cost. 'uses' is the ability's own record.
function Resources.can(actor, cost)
  for id, amount in pairs(cost) do
    if id ~= 'uses' and ((actor.resources or {})[id] or 0) < amount then
      return false
    end
  end
  return true
end
function Resources.spend(actor, cost)
  for id, amount in pairs(cost) do
    if id ~= 'uses' then
      actor.resources[id] = actor.resources[id] - amount
    end
  end
end
-- Effort is not a price: any left at all pays for the act, however dear, and the
-- debt is carried below nothing. An actor without this resource acts freely.
function Resources.ready(actor, id)
  local own = actor.resources
  return not own or own[id] == nil or own[id] > 0
end
function Resources.exert(actor, id, amount)
  local own = actor.resources
  if own and own[id] ~= nil then
    own[id] = own[id] - amount
    actor.resourcePause = actor.resourcePause or {}
    actor.resourcePause[id] = Characters.of(actor).resources[id].pause
  end
end
-- Some of it given back (a perfect dodge returns its price), never above its measure.
function Resources.restore(actor, id, amount)
  local own = actor.resources
  if own and own[id] ~= nil then
    own[id] = math.min(Characters.of(actor).resources[id].max, own[id] + amount)
  end
end
-- The share of it an actor has, or nil.
function Resources.share(actor, id)
  local own = actor.resources
  local def = own and own[id] and Characters.of(actor).resources[id]
  return def and math.max(0, own[id] / def.max) or nil
end
-- rate (optional): how fast it comes back, 1 by default (poison halves it: combat/rules recovery).
function Resources.tick(actor, dt, rate)
  local own = actor.resources
  if not own then
    return
  end
  local pause = actor.resourcePause
  for id, def in pairs(Characters.of(actor).resources) do
    if pause and (pause[id] or 0) > 0 then
      pause[id] = math.max(0, pause[id] - dt)
    else
      own[id] = math.min(def.max, own[id] + def.regen * dt * (rate or 1))
    end
  end
end
return Resources
