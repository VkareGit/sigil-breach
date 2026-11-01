-- ECS on flat entities (verified by tools/spikes/ecs-events).
-- An entity is a plain table; a COMPONENT is a declared set of fields on it
-- (with defaults, see core/schema), so existing code keeps reading e.x, e.hp.
-- Entities live in POOLS (enemies, projectiles, hazards, pickups, knight):
-- a pool is read through a getter, so the session stays the owner of its
-- arrays, and every member of a pool has the pool's components. A PREFAB is
-- a named list of components plus the pool it spawns into (Factory).
-- Queries return entities in pool order, then array order: deterministic.
-- Structural changes are immediate and go through the world (add, remove,
-- keep, clear, move): it owns the arrays' membership and keeps the id index
-- of pools declared with ids, so get(id) is O(1). Removing while iterating
-- a pool forward is not supported: iterate backwards with removeAt, or use
-- keep after the loop (stable compaction).
local Class = require('src.core.class')
local Schema = require('src.core.schema')
local Strict = require('src.core.strict')
local World = Class:extend('World')

function World:init()
  self.components = {}
  self.pools = {}
  self.poolByName = {}
  self.prefabs = {}
  -- id -> entity for the pools declared with ids; stamps record each such
  -- pool's array and length when the index was last made whole.
  self.byId = {}
  self.stamps = {}
end
-- name: component; fields: { field = { default = v, desc = '...' }, ... }
function World:component(name, fields)
  self.components[name] = Schema:new('component ' .. name, fields, true)
  return self.components[name]
end
local function set(list)
  local s = {}
  for _, v in ipairs(list or {}) do
    s[v] = true
  end
  return s
end
-- name: pool; get(): the live array; components: what every member has.
-- options (optional): set(list) replaces the array (clear); ids = true
-- indexes its members by their id field.
function World:pool(name, get, components, options)
  options = options or {}
  local pool = {
    name = name,
    get = get,
    set = options.set,
    ids = options.ids == true,
    has = set(components),
    list = components or {},
  }
  self.pools[#self.pools + 1] = pool
  self.poolByName[name] = pool
  return pool
end
local function poolOf(world, name)
  return assert(world.poolByName[name], 'unknown pool ' .. tostring(name))
end
-- The live array of a pool (read it; change membership through the world).
function World:list(name)
  return poolOf(self, name).get()
end
local function stamp(world, pool)
  local list = pool.get()
  world.stamps[pool.name] = { list = list, count = #list }
end
-- A member without an id (a hand-made fixture) is held but not indexed.
local function index(world, pool, e)
  local id = e.id
  if id == nil then
    return
  end
  local held = world.byId[id]
  assert(
    held == nil or held == e,
    'id ' .. tostring(id) .. ' is already in the world (pool ' .. pool.name .. ')'
  )
  world.byId[id] = e
end
-- Rebuild the id index from the arrays (after a restore, or when an array
-- was replaced or resized outside the world).
function World:reindex()
  self.byId = {}
  for _, pool in ipairs(self.pools) do
    if pool.ids then
      for _, e in ipairs(pool.get()) do
        index(self, pool, e)
      end
      stamp(self, pool)
    end
  end
end
local function fresh(world)
  for _, pool in ipairs(world.pools) do
    if pool.ids then
      local seen, list = world.stamps[pool.name], pool.get()
      if not seen or seen.list ~= list or seen.count ~= #list then
        return false
      end
    end
  end
  return true
end
-- The entity with this id in an indexed pool, or nil.
function World:get(id)
  if not fresh(self) then
    self:reindex()
  end
  return self.byId[id]
end
function World:add(name, e)
  local pool = poolOf(self, name)
  local list = pool.get()
  if pool.ids then
    if not fresh(self) then
      self:reindex()
    end
    index(self, pool, e)
  end
  list[#list + 1] = e
  if pool.ids then
    stamp(self, pool)
  end
  return e
end
function World:removeAt(name, i)
  local pool = poolOf(self, name)
  local e = table.remove(pool.get(), i)
  if pool.ids and e then
    if self.byId[e.id] == e then
      self.byId[e.id] = nil
    end
    stamp(self, pool)
  end
  return e
end
-- Remove e from the pool; false when it is not a member.
function World:remove(name, e)
  local list = poolOf(self, name).get()
  for i = #list, 1, -1 do
    if list[i] == e then
      self:removeAt(name, i)
      return true
    end
  end
  return false
end
-- Keep only the members for which keep(e) is true, in order (stable).
-- Returns how many were removed.
function World:keep(name, keep)
  local pool = poolOf(self, name)
  local list = pool.get()
  local n, removed = 0, 0
  for i = 1, #list do
    local e = list[i]
    list[i] = nil
    if keep(e) then
      n = n + 1
      list[n] = e
    else
      removed = removed + 1
      if pool.ids and self.byId[e.id] == e then
        self.byId[e.id] = nil
      end
    end
  end
  if pool.ids then
    stamp(self, pool)
  end
  return removed
end
-- Empty the pool (a fresh array: what still refers to the old one keeps it).
function World:clear(name)
  local pool = poolOf(self, name)
  assert(pool.set, 'pool ' .. name .. ' cannot be replaced')
  if pool.ids then
    for _, e in ipairs(pool.get()) do
      if self.byId[e.id] == e then
        self.byId[e.id] = nil
      end
    end
  end
  pool.set({})
  if pool.ids then
    stamp(self, pool)
  end
end
-- Move e from one pool to the end of another (its id stays indexed).
function World:move(from, to, e)
  assert(self:remove(from, e), 'entity is not in pool ' .. tostring(from))
  return self:add(to, e)
end
-- name: prefab; spec: { pool = 'enemies', components = { ... }, born = fn };
-- born(e): what a new entity works out from its own values.
function World:prefab(name, spec)
  local pool = assert(
    self.poolByName[spec.pool],
    'prefab ' .. name .. ': unknown pool ' .. tostring(spec.pool)
  )
  local components = {}
  for _, c in ipairs(pool.list) do
    components[#components + 1] = c
  end
  for _, c in ipairs(spec.components or {}) do
    if not pool.has[c] then
      components[#components + 1] = c
    end
  end
  local fields = {}
  for _, c in ipairs(components) do
    local schema = assert(self.components[c], 'prefab ' .. name .. ': unknown component ' .. c)
    for field in pairs(schema.fields) do
      fields[field] = true
    end
  end
  local prefab = {
    name = name,
    born = spec.born,
    pool = pool,
    components = components,
    extra = set(spec.components),
    fields = fields,
  }
  self.prefabs[name] = prefab
  return prefab
end
-- The declared fields of an entity built from prefab (for strict mode).
function World:fields(prefabName)
  return self.prefabs[prefabName].fields
end
-- A new entity from a prefab: every component's defaults, then values.
-- insert = false builds without appending (the caller places it).
function World:create(prefabName, values, insert)
  local prefab = assert(self.prefabs[prefabName], 'unknown prefab ' .. tostring(prefabName))
  local e = {}
  for _, c in ipairs(prefab.components) do
    for field, spec in pairs(self.components[c].fields) do
      if spec.default ~= nil then
        e[field] = Schema.copy(spec.default)
      end
    end
  end
  for k, v in pairs(values or {}) do
    e[k] = v
  end
  if prefab.born then
    prefab.born(e)
  end
  e.components = prefab.extra
  e.prefab = prefabName
  Strict.guard(e, prefab.fields, prefabName)
  if insert ~= false then
    self:add(prefab.pool.name, e)
  end
  return e
end
-- Does entity e (a member of pool `poolName`) have component c?
function World:has(e, c, poolName)
  local pool = poolName and self.poolByName[poolName]
  return (pool and pool.has[c]) or (e.components and e.components[c]) or false
end
-- Every entity that has all the named components, across pools.
function World:query(...)
  local wanted = { ... }
  local out = {}
  for _, pool in ipairs(self.pools) do
    local whole = true
    for _, c in ipairs(wanted) do
      whole = whole and pool.has[c] == true
    end
    local list = pool.get() or {}
    if pool.single then
      list = { list }
    end
    for _, e in ipairs(list) do
      local ok = whole
      if not ok and e.components then
        ok = true
        for _, c in ipairs(wanted) do
          ok = ok and (pool.has[c] or e.components[c]) == true
        end
      end
      if ok then
        out[#out + 1] = e
      end
    end
  end
  return out
end
-- A pool holding exactly one entity (the knight).
function World:single(name, get, components)
  local pool = self:pool(name, get, components)
  pool.single = true
  return pool
end
return World
