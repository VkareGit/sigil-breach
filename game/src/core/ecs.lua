-- ECS on flat entities (verified by tools/spikes/ecs-events).
-- An entity is a plain table; a COMPONENT is a declared set of fields on it
-- (with defaults, see core/schema), so existing code keeps reading e.x, e.hp.
-- Entities live in POOLS (enemies, projectiles, hazards, pickups, knight):
-- a pool is read through a getter, so the session stays the owner of its
-- arrays, and every member of a pool has the pool's components. A PREFAB is
-- a named list of components plus the pool it spawns into (Factory).
-- Queries return entities in pool order, then array order: deterministic.
-- Structural changes are immediate (append), as the simulation always did.
local Class = require('src.core.class')
local Schema = require('src.core.schema')
local Strict = require('src.core.strict')
local World = Class:extend('World')

function World:init()
  self.components = {}
  self.pools = {}
  self.poolByName = {}
  self.prefabs = {}
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
function World:pool(name, get, components)
  local pool = { name = name, get = get, has = set(components), list = components or {} }
  self.pools[#self.pools + 1] = pool
  self.poolByName[name] = pool
  return pool
end
-- name: prefab; spec: { pool = 'enemies', components = { ... } }
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
  e.components = prefab.extra
  e.prefab = prefabName
  Strict.guard(e, prefab.fields, prefabName)
  if insert ~= false then
    local list = prefab.pool.get()
    list[#list + 1] = e
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
