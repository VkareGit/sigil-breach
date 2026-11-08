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
local Kinds = Registry:new('action executors', function(kind, id)
  Action.kinds:get(id)
  -- A kind that changed its state brings every older one up (Kinds.resume).
  for v = 1, (kind.version or 1) - 1 do
    assert(
      kind.migrations and type(kind.migrations[v]) == 'function',
      'action executors: ' .. id .. ' has no migration from state version ' .. v
    )
  end
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
-- What a kind does when its attack ends early, each optional, given the body
-- (its state: Kinds.act(e)):
--   abandon(e)   the commitment broke before release: what it marked goes
--   release(e)   a holder that falters lets go
--   forget(e)    the body fell: it keeps no hold on the world
local function hook(e, name)
  local spec = e.attackSpec
  local kind = spec and e.act and Kinds:find(spec.kind)
  if kind and kind[name] then
    kind[name](e)
  end
end
-- A commitment broken before release: its string and its stillness end, and
-- its kind lets go of what it marked.
function Kinds.abandon(e)
  hook(e, 'abandon')
  e.chain, e.chainFrom, e.holdLeft, e.holdSpan = nil, nil, nil, nil
  Kinds.release(e)
end
-- A holder that falters lets go, whatever else it was doing.
function Kinds.release(e)
  hook(e, 'release')
end
-- A body that fell keeps no hold on the world through its attack.
function Kinds.forget(e)
  hook(e, 'forget')
end
-- A kind may change the shape of its state (PLAN F3): it declares version
-- (1 when absent) and migrations[v], which bring a state of version v to v + 1.
-- A save records the version of every kind that has one (session/world.lua).
function Kinds.versions()
  local versions = {}
  for _, id in ipairs(Kinds:ids()) do
    local kind = Kinds:get(id)
    if (kind.version or 1) > 1 then
      versions[id] = kind.version
    end
  end
  return versions
end
-- The state of a body from a save that recorded these versions, brought up
-- to the version of its kind.
function Kinds.resume(e, versions)
  local spec = e.attackSpec
  local kind = spec and e.act and Kinds:find(spec.kind)
  if not kind then
    return
  end
  local saved = versions and versions[spec.kind] or 1
  for v = saved, (kind.version or 1) - 1 do
    assert(kind.migrations and kind.migrations[v], spec.kind .. ': no state migration from ' .. v)
    kind.migrations[v](e.act)
  end
end
return Kinds
