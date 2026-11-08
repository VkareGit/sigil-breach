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
-- The state of a committed attack belongs to its kind (PLAN F3): each kind
-- declares what it keeps in e.act (state = { field = meaning }), a fresh
-- table at every commitment (enemies/actions.lua), never a field of the body.
function Kinds.state(id)
  local kind = Kinds:find(id)
  return kind and kind.state or {}
end
-- The attack state of a body, made when a body was put into its attack
-- without a commitment (a test, a catalogue pose).
function Kinds.act(e)
  local act = e.act
  if not act then
    act = {}
    e.act = act
  end
  return act
end
-- A commitment broken before release: what it marked on the ground goes with it.
function Kinds.abandon(e)
  if e.act then
    e.act.harvestMarks, e.act.streamHits = nil, nil
  end
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
  if e.act then
    e.act.holding, e.act.holdUntil = nil, nil
  end
end
return Kinds
