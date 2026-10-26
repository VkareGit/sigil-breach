-- The ECS world of one session: pools over the session's own arrays (the
-- session stays their owner, so existing code and saves keep working),
-- component schemas and prefabs. Systems query it; factories spawn from it.
-- Membership changes and pool reads go through this module (plan v10 V1:
-- the pool-arrays ratchet), never through the session's array fields:
--   Pools.of(g, name)         the live array of a pool (read only)
--   Pools.add(g, name, e)     append (indexes the id of a creature)
--   Pools.removeAt / remove / keep / clear
--   Pools.get(g, id)          a creature, living or retired, by id
--   Pools.retire(g, e)        a corpse at rest leaves the step: remains
-- Pool names: enemies (living creatures and fresh corpses), remains (corpses
-- at rest, out of every step), projectiles, hazards, pickups, charges, and
-- knights (1..n; g.player is the knight this session controls).
local World = require('src.core.ecs')
local Components = require('src.session.components')
local Roles = require('src.core.roles')
local Tree = require('src.core.data_tree')
local Save = require('src.storage.save')
local M = {}
-- Pool name -> the session array field that stores it; order is the
-- deterministic order of queries across pools.
M.order = { 'enemies', 'remains', 'projectiles', 'hazards', 'pickups', 'charges', 'knights' }
M.arrays = {
  enemies = 'enemies',
  remains = 'remains',
  projectiles = 'bullets',
  hazards = 'hazards',
  pickups = 'pickups',
  charges = 'charges',
  knights = 'knights',
}
-- Pools whose members are found by id (Pools.get).
local indexed = { enemies = true, remains = true, knights = true }
function M.new(g)
  local w = World:new()
  Components.declare(w)
  -- Pools: every member has the pool's components (hand-made members too).
  for _, name in ipairs(M.order) do
    local field = M.arrays[name]
    local components = Components.pools[name] or Components.pools.enemies
    w:pool(
      name,
      function()
        return g[field]
      end,
      components,
      {
        set = function(list)
          g[field] = list
        end,
        ids = indexed[name] == true,
      }
    )
  end
  Components.prefabs(w)
  return w
end
-- A bare session (a hand-made fixture with no ECS world) keeps plain arrays.
local function bare(g, name)
  local field = assert(M.arrays[name], 'unknown pool ' .. tostring(name))
  g[field] = g[field] or {}
  return g[field]
end
function M.of(g, name)
  if g.ecs then
    return g.ecs:list(name)
  end
  return bare(g, name)
end
function M.add(g, name, e)
  if g.ecs then
    return g.ecs:add(name, e)
  end
  local list = bare(g, name)
  list[#list + 1] = e
  return e
end
function M.removeAt(g, name, i)
  if g.ecs then
    return g.ecs:removeAt(name, i)
  end
  return table.remove(bare(g, name), i)
end
function M.remove(g, name, e)
  if g.ecs then
    return g.ecs:remove(name, e)
  end
  local list = bare(g, name)
  for i = #list, 1, -1 do
    if list[i] == e then
      table.remove(list, i)
      return true
    end
  end
  return false
end
function M.keep(g, name, keep)
  if g.ecs then
    return g.ecs:keep(name, keep)
  end
  local list, out = bare(g, name), {}
  for _, e in ipairs(list) do
    if keep(e) then
      out[#out + 1] = e
    end
  end
  g[M.arrays[name]] = out
  return #list - #out
end
function M.clear(g, name)
  if g.ecs then
    return g.ecs:clear(name)
  end
  g[M.arrays[name]] = {}
end
-- A creature by id: living, a fresh corpse or a retired one.
function M.get(g, id)
  if id == nil then
    return nil
  end
  if g.ecs then
    return g.ecs:get(id)
  end
  for _, name in ipairs({ 'enemies', 'remains', 'knights' }) do
    for _, e in ipairs(bare(g, name)) do
      if e.id == id then
        return e
      end
    end
  end
end
function M.retire(g, e)
  if g.ecs then
    return g.ecs:move('enemies', 'remains', e)
  end
  M.remove(g, 'enemies', e)
  return M.add(g, 'remains', e)
end
-- Move every creature for which retires(e) holds to the remains, in order.
-- Allocates only when one does.
function M.retireWhere(g, retires)
  local any = false
  for _, e in ipairs(M.of(g, 'enemies')) do
    if retires(e) then
      any = true
      break
    end
  end
  if not any then
    return 0
  end
  local moved = {}
  M.keep(g, 'enemies', function(e)
    if retires(e) then
      moved[#moved + 1] = e
      return false
    end
    return true
  end)
  for _, e in ipairs(moved) do
    M.add(g, 'remains', e)
  end
  return #moved
end
-- After the arrays were replaced wholesale (a snapshot restored).
function M.reindex(g)
  if g.ecs then
    g.ecs:reindex()
  end
end
-- The session save's section of the pools (plan v10 V4): every member of
-- every pool with its components, its side (faction) and its references to
-- definitions and to other members (core/data_tree.lua), which knight this
-- session controls and the next id. A member's caches (Components.transient)
-- are not saved: they are rebuilt.
local members = setmetatable({}, { __mode = 'k' })
local function transient(t, k)
  return members[t] and Components.transient[k]
end
Save.declare({
  name = 'pools',
  file = 'session',
  version = 1,
  pack = function(g)
    local all, controlled = {}, nil
    for _, name in ipairs(M.order) do
      all[name] = M.of(g, name)
      for i, e in ipairs(all[name]) do
        members[e] = true
        if name == 'knights' and e == Roles.controlled(g) then
          controlled = i
        end
      end
    end
    return { pools = Tree.encode(all, transient), controlled = controlled, nextId = g.nextId }
  end,
  unpack = function(t)
    assert(type(t) == 'table', 'pools')
    local all = Tree.decode(t.pools)
    assert(type(all) == 'table', 'pools')
    for name in pairs(all) do
      assert(M.arrays[name], 'unknown pool ' .. tostring(name))
    end
    local ids = {}
    for _, name in ipairs(M.order) do
      local list = all[name] or {}
      all[name] = list
      for i, e in pairs(list) do
        assert(
          type(i) == 'number' and i >= 1 and i <= #list and type(e) == 'table',
          'pool ' .. name
        )
        if e.id ~= nil then
          assert(not ids[e.id], 'two members with one id')
          ids[e.id] = true
        end
      end
    end
    local knights = all.knights
    assert(#knights >= 1, 'no knight')
    assert(type(t.controlled) == 'number' and knights[t.controlled] ~= nil, 'no controlled knight')
    assert(t.nextId == nil or type(t.nextId) == 'number', 'next id')
    return { pools = all, controlled = t.controlled, nextId = t.nextId }
  end,
  restore = function(g, value)
    for _, name in ipairs(M.order) do
      M.clear(g, name)
      for _, e in ipairs(value.pools[name]) do
        M.add(g, name, e)
      end
    end
    Roles.control(g, value.pools.knights[value.controlled])
    g.nextId = value.nextId
    M.reindex(g)
  end,
})
return M
