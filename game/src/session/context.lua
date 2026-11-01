-- Presentation context: the actor owns hands/HUD; the viewer owns the camera.
-- A normal one-player view is the session itself. Additional views keep only
-- private presentation data; world effects and settings remain shared.
local ViewState = require('src.session.view_state')
local Roles = require('src.core.roles')
local Pools = require('src.session.world')
local Fields = require('src.session.fields')
local Context = {}
local empty = {}
local function root(g)
  return g._contextRoot or g
end
local function resolve(g, actor)
  if type(actor) == 'string' then
    return Pools.get(g, actor)
  end
  return actor or Roles.controlled(g)
end
function Context.actor(g)
  return g.contextActor or Roles.controlled(g)
end
function Context.controlled(g)
  return Roles.controlled(root(g))
end
function Context.viewer(g)
  return g.viewer or Context.actor(g)
end
function Context.isControlled(g, actor)
  -- A rendered sample carries its own interpolated controlled alias.
  return (actor or Context.actor(g)) == Roles.controlled(g)
end
function Context.watched(g)
  return root(g).view.actors or empty
end
function Context.observers(g)
  return root(g).view.observers or empty
end
local function routed(shared, personal)
  return setmetatable({}, {
    __index = function(_, key)
      if Fields.viewScope(key) == 'world' then
        return shared[key]
      end
      return personal[key]
    end,
    __newindex = function(_, key, value)
      if Fields.viewScope(key) == 'world' then
        shared[key] = value
      else
        personal[key] = value
      end
    end,
  })
end
function Context.view(g, actor)
  g = root(g)
  actor = resolve(g, actor)
  if not actor then
    return nil
  end
  if Context.isControlled(g, actor) then
    return g.view
  end
  local private = g.view.actors and g.view.actors[actor.id]
  return private and routed(g.view, private) or nil
end
function Context.of(g, actor, viewer)
  local base = root(g)
  actor = actor == nil and Context.actor(g) or resolve(base, actor)
  assert(actor and type(actor) == 'table', 'unknown presentation actor')
  viewer = viewer or actor
  if actor == Roles.controlled(base) and viewer == actor and not base.viewer then
    return base
  end
  local view = assert(Context.view(base, actor), 'presentation actor is not watched')
  if viewer ~= actor then
    local observers = base.view.observers
    if not observers then
      observers = {}
      base.view.observers = observers
    end
    local state
    for _, observer in ipairs(observers) do
      if observer.actor == actor.id and observer.viewer == viewer then
        state = observer.state
        break
      end
    end
    if not state then
      state = {}
      observers[#observers + 1] = { actor = actor.id, viewer = viewer, state = state }
    end
    local personal = view
    view = setmetatable({}, {
      __index = function(_, key)
        if Fields.viewScope(key) == 'view' then
          return state[key]
        end
        return personal[key]
      end,
      __newindex = function(_, key, value)
        if Fields.viewScope(key) == 'view' then
          state[key] = value
        else
          personal[key] = value
        end
      end,
    })
  end
  return setmetatable({ _contextRoot = base, contextActor = actor, viewer = viewer, view = view }, {
    __index = function(_, key)
      if key == 'step' and actor ~= Roles.controlled(base) then
        return view.actorStep or 0
      end
      return base[key]
    end,
    __newindex = function(self, key, value)
      if key == 'step' and actor ~= Roles.controlled(base) then
        view.actorStep = value
      else
        rawset(self, key, value)
      end
    end,
  })
end
function Context.reset(g, actor)
  g = root(g)
  actor = resolve(g, actor)
  if not actor then
    return
  end
  local view = Context.view(g, actor)
  if not view then
    return
  end
  for _, group in ipairs(Fields.viewGroups) do
    if group.scope ~= 'world' then
      for _, name in ipairs(group.names) do
        view[name] = nil
      end
    end
  end
  view.muzzle, view.hurt, view.surge, view.hitmarker, view.shake = 0, 0, 0, 0, 0
  view.message, view.messageTimer, view.feedback, view.feedbackTimer, view.damageDir =
    '', 0, '', 0, 0
  view.actorStep = 0
  if Context.isControlled(g, actor) then
    g.step = 0
  end
  for _, observer in ipairs(Context.observers(g)) do
    if observer.actor == actor.id then
      observer.state.presentationPrevious = nil
    end
  end
  ViewState.init(Context.of(g, actor))
end
function Context.watch(g, id)
  g = root(g)
  local actor = resolve(g, id)
  if not actor or actor.prefab ~= 'knight' or Pools.get(g, actor.id) ~= actor then
    return nil
  end
  if Context.isControlled(g, actor) then
    return g.view
  end
  g.view.actors = g.view.actors or {}
  if not g.view.actors[actor.id] then
    g.view.actors[actor.id] = {}
    Context.reset(g, actor)
  end
  return Context.view(g, actor)
end
function Context.unwatch(g, id)
  g = root(g)
  id = type(id) == 'table' and id.id or id
  if g.view.actors then
    g.view.actors[id] = nil
  end
  for i = #Context.observers(g), 1, -1 do
    local observer = g.view.observers[i]
    if observer.actor == id or observer.viewer.id == id then
      table.remove(g.view.observers, i)
    end
  end
end
-- Detached cameras keep a stable identity while open; close the viewport
-- explicitly to release its private interpolation history and camera record.
function Context.unobserve(g, actor, viewer)
  g = root(g)
  actor = resolve(g, actor)
  if not actor then
    return
  end
  for i = #Context.observers(g), 1, -1 do
    local observer = g.view.observers[i]
    if observer.actor == actor.id and observer.viewer == viewer then
      table.remove(g.view.observers, i)
    end
  end
end
function Context.controlChanged(g, previous, actor)
  Context.unwatch(g, previous.id)
  Context.unwatch(g, actor.id)
  Context.reset(g, previous)
  Context.reset(g, actor)
end
return Context
