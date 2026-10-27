-- Common presentation asks for a mode's contract, not its private state.
-- The view contract (plan v11 E2):
--   owner     a view belongs to its session: one table per session and view
--             kind, weakly held, never shared between sessions;
--   validity  until the session's next simulation step or command
--             (Game:act); a call in the same step returns the same object,
--             filled anew;
--   keeping   a view is borrowed for one frame: never mutate or retain it.
--             Queries.copy(view) is a copy of its own to keep;
--             Queries.valid(g, view) tells a view retained too long.
-- What every world view carries besides the mode's own fields: the
-- encounter's guardian (guardianSpawned, guardianDead) and the world's
-- hidden sigil (secretFound).
local Modes = require('src.run.modes')
local Encounter = require('src.session.encounter')
local Queries = {}
local sessions = setmetatable({}, { __mode = 'k' })
local stamps = setmetatable({}, { __mode = 'k' })
local function canonical(g)
  return g._contextRoot or g
end
local function entry(g)
  local e = sessions[g]
  if not e then
    e = { views = {}, commands = 0, ownerToken = {} }
    sessions[g] = e
  end
  return e
end
-- A command of the session (Game:act): its views from before are stale.
function Queries.command(g)
  local e = entry(canonical(g))
  e.commands = e.commands + 1
end
-- The session's table for a view kind, emptied and stamped.
local function borrow(g, name)
  local e = entry(g)
  local root = canonical(g)
  local revision = root == g and e or entry(root)
  local view = e.views[name]
  if not view then
    view = {}
    e.views[name] = view
  else
    for k in pairs(view) do
      view[k] = nil
    end
  end
  local s = stamps[view] or {}
  -- LuaJIT weak-key tables are not ephemerons. A stamp pointing back to g
  -- would keep the session alive through sessions[g].views -> stamps[view].
  -- An identity token proves ownership without retaining the owner.
  -- Different actors/samples keep separate result tables, but all answers
  -- become stale when a command changes their one authoritative session.
  s.ownerToken, s.time = e.ownerToken, root.time or 0
  s.revisionToken, s.commands = revision.ownerToken, revision.commands
  stamps[view] = s
  return view
end
-- Whether view is still valid for session g (borrowed from it, in this step
-- and since its last command).
function Queries.valid(g, view)
  local s = stamps[view]
  local owner = sessions[g]
  local root = canonical(g)
  local revision = root == g and owner or sessions[root]
  return s ~= nil
    and owner ~= nil
    and revision ~= nil
    and s.ownerToken == owner.ownerToken
    and s.revisionToken == revision.ownerToken
    and s.time == (root.time or 0)
    and s.commands == revision.commands
end
local function copy(value)
  if type(value) ~= 'table' then
    return value
  end
  local out = {}
  for k, v in pairs(value) do
    out[k] = copy(v)
  end
  return out
end
-- A view of one's own to keep (a deep copy, shared with nothing).
function Queries.copy(view)
  return copy(view)
end
-- The mode's answer in the session's view table: a mode may fill it (the
-- built-in ones) or return a table of its own, whose fields are taken over.
local function ask(g, hook, name)
  local view = borrow(g, name)
  local answer = Modes.act(g, hook, view)
  if not answer then
    return nil, view
  end
  if answer ~= view then
    for k, v in pairs(answer) do
      view[k] = v
    end
  end
  return view, view
end
local noGates = {}
function Queries.world(g)
  local built, view = ask(g, 'worldView', 'world')
  if not built then
    view.gates, view.paintedPickups, view.classicSecret = noGates, false, false
  end
  view.guardianSpawned = Encounter.guardianSpawned(g)
  view.guardianDead = Encounter.guardianDead(g)
  view.secretFound = g.world ~= nil and g.world.secretFound == true
  return view
end
function Queries.tools(g)
  return (ask(g, 'tools', 'tools'))
end
function Queries.objective(g)
  return Modes.act(g, 'objective') or ''
end
function Queries.remaining(g)
  return Modes.act(g, 'remaining') or 0
end
-- The run of the session's mode (phase, wave, wallet, echo...; nil when it
-- keeps none) and its proving ground (nil outside one): read-only views.
function Queries.run(g)
  return (ask(g, 'runView', 'run'))
end
function Queries.field(g)
  return (ask(g, 'fieldView', 'field'))
end
-- What a finished session shows of its mode (the classic arena: rank, best
-- score, seals broken); nil for a mode with no result of its own.
function Queries.result(g)
  return (ask(g, 'result', 'result'))
end
return Queries
