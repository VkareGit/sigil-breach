-- What each kind of action does (its fields: content/defs/action.lua), one
-- entry per kind:
--   cast(g, action, caster)      acts from a caster (combat/caster.lua): any
--                                body or a point; true when it went off
--   the life of a creature's attack (enemies/actions.lua):
--   commit(g, e, atk)            at commitment, after the aim is taken
--   aim(g, e, atk)               target prediction at commitment
--   execute(g, e, atk, a)        at release; a = aim angle
--   strike(g, e, atk, dt, ctx)   each step of the strike state
--   duration(e, atk)             length of the strike state (default data)
--   unseen                       needs no sight of its target
local Action = require('src.content.defs.action')
local Registry = require('src.core.registry')
local Kinds = Registry:new('action executors', function(_, id)
  Action.kinds:get(id)
end)
-- A commitment broken before release: what it marked on the ground goes with it.
function Kinds.abandon(e)
  local mark = e.pendingHazard
  if mark then
    mark.cancelled = true
    e.pendingHazard = nil
  end
  e.chain, e.chainFrom, e.holdLeft, e.holdSpan = nil, nil, nil, nil
  Kinds.release(e)
end
-- A holder that falters lets go, whatever else it was doing.
function Kinds.release(e)
  e.holding, e.holdUntil = nil, nil
end
return Kinds
