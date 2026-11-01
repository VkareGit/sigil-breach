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
return Registry:new('action executors', function(_, id)
  Action.kinds:get(id)
end)
