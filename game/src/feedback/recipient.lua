-- An event names its actor; observing it never transfers control or creates
-- a new personal view. World effects are emitted by the caller just once.
local Context = require('src.session.context')
local Pools = require('src.session.world')
local Recipient = {}
function Recipient.actor(g, id)
  if type(id) == 'table' then
    return id
  end
  local controlled = Context.controlled(g)
  if id == nil or controlled and controlled.id == id then
    return controlled
  end
  return Pools.get(g, id)
end
function Recipient.context(g, id)
  local actor = Recipient.actor(g, id)
  if actor and Context.view(g, actor) then
    return Context.of(g, actor)
  end
end
function Recipient.each(g, callback)
  local controlled = Context.controlled(g)
  if controlled then
    callback(Context.of(g, controlled), controlled)
  end
  if next(Context.watched(g)) == nil then
    return
  end
  for _, actor in ipairs(Pools.of(g, 'knights')) do
    if actor ~= controlled and Context.view(g, actor) then
      callback(Context.of(g, actor), actor)
    end
  end
end
return Recipient
