-- One registry type for everything there can be more of: creatures, attack
-- kinds, movement styles, AI states, reload mechanisms, supplies,
-- conditions, game modes, event kinds. Entries keep registration order
-- (deterministic iteration). An optional check(entry, id) validates an
-- entry when it is registered (schemas, required functions). Registration
-- introduces an id once; deliberate replacement is a separate operation.
local Class = require('src.core.class')
local Id = require('src.core.id')
local Registry = Class:extend('Registry')
function Registry:init(name, check)
  self.name = name
  self.check = check
  self.entries = {}
  self.order = {}
end
local function validate(registry, id, entry)
  assert(entry ~= nil, registry.name .. ': empty entry ' .. id)
  if registry.check then
    registry.check(entry, id)
  end
end
function Registry:register(id, entry)
  Id.check(id, self.name .. '.id')
  assert(self.entries[id] == nil, self.name .. ': already registered ' .. id .. '; use replace')
  validate(self, id, entry)
  -- A rejected definition changes neither the entries nor their order.
  self.order[#self.order + 1] = id
  self.entries[id] = entry
  return entry
end
-- Register an entry to be met before an existing one, where the order of the
-- entries decides (the first that applies wins).
function Registry:insert(id, entry, before)
  assert(
    self.entries[before] ~= nil,
    self.name .. ': nothing to insert before: ' .. tostring(before)
  )
  self:register(id, entry)
  table.remove(self.order)
  for i, known in ipairs(self.order) do
    if known == before then
      table.insert(self.order, i, id)
      break
    end
  end
  return entry
end
-- A deliberate override (tool or mod). It must name an existing entry and
-- pass the same validator; success preserves that id's iteration position.
function Registry:replace(id, entry)
  Id.check(id, self.name .. '.id')
  assert(self.entries[id] ~= nil, self.name .. ': cannot replace missing ' .. id)
  validate(self, id, entry)
  self.entries[id] = entry
  return entry
end
-- Remove an entry (a mod unloading, a test cleaning up after itself).
function Registry:unregister(id)
  if self.entries[id] == nil then
    return nil
  end
  local entry = self.entries[id]
  self.entries[id] = nil
  for i, known in ipairs(self.order) do
    if known == id then
      table.remove(self.order, i)
      break
    end
  end
  return entry
end
-- The entry, or a clear error naming the known ids.
function Registry:get(id)
  local entry = self.entries[id]
  if entry == nil then
    error(
      self.name
        .. ': unknown '
        .. tostring(id)
        .. ' (known: '
        .. table.concat(self.order, ', ')
        .. ')',
      2
    )
  end
  return entry
end
-- The entry or nil (for optional lookups with a fallback).
function Registry:find(id)
  return self.entries[id]
end
function Registry:has(id)
  return self.entries[id] ~= nil
end
-- for id, entry in registry:each() do ... end (registration order)
function Registry:each()
  local i = 0
  return function()
    i = i + 1
    local id = self.order[i]
    if id then
      return id, self.entries[id]
    end
  end
end
function Registry:ids()
  local out = {}
  for i, id in ipairs(self.order) do
    out[i] = id
  end
  return out
end
-- Expose entries as a plain table view (registry.entries) for code that
-- indexes kinds directly: Attacks.kinds[atk.kind].
function Registry:view()
  return self.entries
end
return Registry
