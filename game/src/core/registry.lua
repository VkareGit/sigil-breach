-- One registry type for everything there can be more of: creatures, attack
-- kinds, movement styles, AI states, reload mechanisms, supplies,
-- conditions, game modes, event kinds. Entries keep registration order
-- (deterministic iteration). An optional check(entry, id) validates an
-- entry when it is registered (schemas, required functions).
local Class = require('src.core.class')
local Id = require('src.core.id')
local Registry = Class:extend('Registry')
function Registry:init(name, check)
  self.name = name
  self.check = check
  self.entries = {}
  self.order = {}
end
function Registry:register(id, entry)
  Id.check(id, self.name .. '.id')
  assert(entry ~= nil, self.name .. ': empty entry ' .. id)
  if self.check then
    self.check(entry, id)
  end
  -- A rejected definition changes neither the entries nor their order.
  if self.entries[id] == nil then
    self.order[#self.order + 1] = id
  end
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
