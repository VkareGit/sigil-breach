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
local Abilities = require('src.content.abilities')
local Characters = require('src.content.characters')
local Weapons = require('src.content.weapons')
local World = require('src.core.ecs')
local Components = require('src.session.components')
local Roles = require('src.core.roles')
local Tree = require('src.core.data_tree')
local Save = require('src.storage.save')
local Schema = require('src.core.schema')
local M = {}
-- Pool name -> the session array field that stores it; order is the
-- deterministic order of queries across pools.
M.order =
  { 'enemies', 'remains', 'projectiles', 'hazards', 'pickups', 'charges', 'knights', 'entities' }
-- The dead a session keeps; a long one forgets the oldest.
M.remainsKept = require('src.content.tuning').remainsKept
M.arrays = {
  enemies = 'enemies',
  remains = 'remains',
  projectiles = 'bullets',
  hazards = 'hazards',
  pickups = 'pickups',
  charges = 'charges',
  knights = 'knights',
  entities = 'things',
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
  -- A long session keeps only the latest dead: they are saved with it, and nothing asks for
  -- an old one. M.get answers nil for what is gone.
  local remains = M.of(g, 'remains')
  if #remains >= M.remainsKept then
    M.remove(g, 'remains', remains[1])
  end
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
    local remains = M.of(g, 'remains')
    if #remains >= M.remainsKept then
      M.remove(g, 'remains', remains[1])
    end
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
-- Version 2 (plan v11 E3): a knight carries its actor state (the slot in
-- hand, reload, trigger, shots, shot sequence). A version 1 save had none
-- (the session kept it and saved it nowhere): its knights take the defaults
-- of their component when restored. Version 3 (plan v12 R1): a knight names
-- its character and carries its limits; an older one is the default character.
local function actorDefaults(knight)
  for name, spec in pairs(Components.schemas.knight) do
    if knight[name] == nil and spec.default ~= nil then
      knight[name] = type(spec.default) == 'table' and Schema.copy(spec.default) or spec.default
    end
  end
  Characters.born(knight)
end
Save.declare({
  name = 'pools',
  file = 'session',
  version = 4,
  migrations = {
    [3] = function(data)
      local all = Tree.decode(data.pools)
      for _, knight in ipairs(all.knights or {}) do
        -- P6 replaces the old passive sigil fields. Equipped copies belong
        -- to the pilgrimage collection; resumeField binds those afterwards.
        knight.rallyRate, knight.dodgeEdge, knight.edgeUntil = nil, nil, nil
        knight.sigilRanks, knight.sigilState = nil, nil
      end
      data.pools = Tree.encode(all)
      return data
    end,
    [1] = function(data)
      data.actorDefaults = true
      return data
    end,
    [2] = function(data)
      data.actorDefaults = true
      return data
    end,
  },
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
    return {
      pools = all,
      controlled = t.controlled,
      nextId = t.nextId,
      actorDefaults = t.actorDefaults == true,
    }
  end,
  restore = function(g, value)
    for _, name in ipairs(M.order) do
      M.clear(g, name)
      for _, e in ipairs(value.pools[name]) do
        M.add(g, name, e)
      end
    end
    if value.actorDefaults then
      for _, knight in ipairs(value.pools.knights) do
        actorDefaults(knight)
      end
    end
    Roles.control(g, value.pools.knights[value.controlled])
    g.nextId = value.nextId
    M.reindex(g)
  end,
})
-- A knight as one member of the pools section (plan v11 E3: what a journal's
-- actorJoin carries): its components, place, level and facing, its
-- equipment and arsenal, health and ward, side and actor state, written by
-- the same coder as the save (core/data_tree.lua).
function M.memberRecord(knight)
  members[knight] = true
  local record = Tree.encode(knight, transient)
  members[knight] = nil
  return record
end
local finite = function(v)
  return type(v) == 'number' and v == v and v > -math.huge and v < math.huge
end
-- A new knight of session g from a member record, checked as a save's member
-- is: the coder, the knight's declared fields, existing definitions and an id
-- the session does not use. Returns the knight (not yet in the pool) or nil
-- and the reason.
function M.knightFromRecord(g, record)
  local ok, knight = pcall(Tree.decode, record)
  if not ok or type(knight) ~= 'table' then
    return nil, 'not a member record'
  end
  if type(knight.id) ~= 'string' or not knight.id:match('^[%w_]+$') then
    return nil, 'a knight needs an id'
  end
  if M.get(g, knight.id) or knight.id == (Roles.controlled(g) or {}).id then
    return nil, 'id already used: ' .. knight.id
  end
  local fields = g.ecs:fields('knight')
  for key in pairs(knight) do
    if not (fields[key] or key == 'prefab' or key == 'components') then
      return nil, 'not a field of a knight: ' .. tostring(key)
    end
  end
  if knight.prefab ~= nil and knight.prefab ~= 'knight' then
    return nil, 'not a knight'
  end
  for _, key in ipairs({ 'x', 'z', 'hp' }) do
    if knight[key] ~= nil and not finite(knight[key]) then
      return nil, 'invalid ' .. key
    end
  end
  for _, id in ipairs(knight.loadout or {}) do
    if not Weapons.registry:has(id) or not (knight.arsenal and knight.arsenal[id]) then
      return nil, 'unknown weapon ' .. tostring(id)
    end
  end
  for _, id in ipairs(knight.abilities or {}) do
    if not Abilities:has(id) then
      return nil, 'unknown ability ' .. tostring(id)
    end
  end
  knight.prefab, knight.components = nil, nil
  return g.ecs:create('knight', knight, false)
end
return M
