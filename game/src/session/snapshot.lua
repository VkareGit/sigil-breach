-- Memento (0.24 E10): the whole state of a session, captured and restored.
-- A snapshot is a deep copy of the session's own data; definitions (every
-- table reachable from src.content) are shared by identity, never copied, so
-- a demon restored mid-attack still points at its attack's definition. The
-- session's machinery (its event bus with its listeners, its ECS world over
-- the session's arrays) is not data: it stays and sees the restored arrays.
-- Uses: quick save/load, a replay that starts mid-fight, a test that rewinds.
-- File saves are data, not mementos (storage/save.lua, plan v10 V4): each
-- section's owner writes its state as a tree and reads it back.
local Snapshot = {}
-- Session fields that are machinery, not state.
Snapshot.machinery = { bus = true, ecs = true }
-- Definitions are shared: every table reachable from a loaded content module.
-- Existing definitions must remain immutable while sessions or snapshots refer
-- to them. Adding definitions in content tooling is allowed: after adding nested
-- tables to an already loaded module, call invalidateDefinitions before the next
-- capture/restore. This is an indexing API, not migration of live sessions or old
-- snapshots to replacement definitions.
-- Only module identities are checked per operation. Walking nested definitions
-- crosses every baked mask row and anatomy polygon, so that index is reused.
local cached, cachedModules, cachedCount = nil, {}, 0
function Snapshot.invalidateDefinitions()
  cached, cachedModules, cachedCount = nil, {}, 0
end
local function definitions()
  local modules, changed = 0, not cached
  for name, module in pairs(package.loaded) do
    if type(name) == 'string' and name:match('^src%.content%.') then
      modules = modules + 1
      changed = changed or cachedModules[name] ~= module
    end
  end
  if not changed and modules == cachedCount then
    return cached
  end
  local shared, identities = {}, {}
  local function walk(t)
    if type(t) ~= 'table' or shared[t] then
      return
    end
    shared[t] = true
    for k, v in pairs(t) do
      walk(k)
      walk(v)
    end
  end
  for name, module in pairs(package.loaded) do
    if type(name) == 'string' and name:match('^src%.content%.') then
      identities[name] = module
      walk(module)
    end
  end
  cached, cachedModules, cachedCount = shared, identities, modules
  return shared
end
local function copy(v, seen, shared)
  if type(v) ~= 'table' or shared[v] then
    return v
  end
  if seen[v] then
    return seen[v]
  end
  local out = {}
  seen[v] = out
  for k, x in pairs(v) do
    out[copy(k, seen, shared)] = copy(x, seen, shared)
  end
  local meta = getmetatable(v)
  if meta then
    setmetatable(out, meta)
  end
  return out
end
-- The memento of g: an opaque value; restore it with Snapshot.restore.
function Snapshot.capture(g)
  local shared, seen = definitions(), {}
  local data = {}
  for k, v in pairs(g) do
    if not Snapshot.machinery[k] then
      data[k] = copy(v, seen, shared)
    end
  end
  return { data = data }
end
-- Put g back in the captured state (the snapshot stays reusable).
function Snapshot.restore(g, snapshot)
  local shared, seen = definitions(), {}
  for k in pairs(g) do
    if not Snapshot.machinery[k] and snapshot.data[k] == nil then
      g[k] = nil
    end
  end
  for k, v in pairs(snapshot.data) do
    g[k] = copy(v, seen, shared)
  end
  -- The world's id index follows the restored arrays.
  if g.ecs then
    g.ecs:reindex()
  end
  require('src.session.presentation').call(g, 'worldRestored')
  return g
end
return Snapshot
