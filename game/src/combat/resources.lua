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
function Resources.tick(actor, dt)
  local own = actor.resources
  if not own then
    return
  end
  for id, def in pairs(Characters.of(actor).resources) do
    own[id] = math.min(def.max, own[id] + def.regen * dt)
  end
end
return Resources
