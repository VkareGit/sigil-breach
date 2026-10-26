-- Definitions are read-only (plan v10 V1; the shared-definition finding of
-- the code handbook): every table reachable from a loaded src.content module.
-- seal() records each table's fields (values, and tables or functions by
-- identity); verify() reports every field that changed since. Registries may
-- gain and lose entries (tools, mods, a test that cleans up after itself);
-- an entry that stays is the same table, and its order list is theirs to keep.
-- New tables reached later are sealed by the next seal(); they are not
-- reported. The tests seal once and verify after every suite (strict mode).
local Registry = require('src.core.registry')
local Definitions = {}
local sealed, paths, storages, orders = nil, nil, nil, nil
local function isRegistry(t)
  local m = getmetatable(t)
  while m do
    if m == Registry then
      return true
    end
    m = rawget(m, 'super')
  end
  return false
end
local function label(key)
  return type(key) == 'string' and key or ('[' .. tostring(key) .. ']')
end
local function modules()
  local names = {}
  for name in pairs(package.loaded) do
    if type(name) == 'string' and name:match('^src%.content%.') then
      names[#names + 1] = name
    end
  end
  table.sort(names)
  return names
end
-- Every reachable table with its first path, registry storages marked.
local function walk()
  local found, where, storage, order = {}, {}, {}, {}
  local function visit(t, path)
    if type(t) ~= 'table' or found[t] then
      return
    end
    found[t], where[t] = true, path
    if isRegistry(t) then
      storage[t.entries] = true
      order[t.order] = true
    end
    for k, v in pairs(t) do
      visit(k, path .. '.<key>')
      visit(v, path .. '.' .. label(k))
    end
  end
  for _, name in ipairs(modules()) do
    visit(package.loaded[name], name)
  end
  return found, where, storage, order
end
local function fields(t)
  local out = {}
  for k, v in pairs(t) do
    out[k] = v
  end
  return out
end
function Definitions.seal()
  local found
  found, paths, storages, orders = walk()
  sealed = setmetatable({}, { __mode = 'k' })
  for t in pairs(found) do
    sealed[t] = fields(t)
  end
end
local function same(a, b)
  -- NaN never equals itself; treat two NaNs in the same field as unchanged.
  return a == b or (a ~= a and b ~= b)
end
-- The fields that changed since seal(), as readable lines (empty when none).
function Definitions.changes()
  local out = {}
  if not sealed then
    return out
  end
  local function report(path, key, before, after)
    out[#out + 1] = path
      .. '.'
      .. label(key)
      .. ': '
      .. tostring(before)
      .. ' -> '
      .. tostring(after)
  end
  for t, before in pairs(sealed) do
    local path = paths[t] or '?'
    if not orders[t] then
      local registry = storages[t]
      for k, v in pairs(before) do
        local now = rawget(t, k)
        if now == nil and registry then
          -- An unregistered entry.
        elseif not same(now, v) then
          report(path, k, v, now)
        end
      end
      if not registry then
        for k, v in pairs(t) do
          if before[k] == nil then
            report(path, k, nil, v)
          end
        end
      end
    end
  end
  table.sort(out)
  return out
end
-- Error naming the first changed fields (strict runs).
function Definitions.verify(context)
  local changes = Definitions.changes()
  if #changes > 0 then
    local shown = {}
    for i = 1, math.min(#changes, 8) do
      shown[i] = changes[i]
    end
    error(
      (context or 'definitions')
        .. ': '
        .. #changes
        .. ' definition field(s) changed after the content was sealed:\n  '
        .. table.concat(shown, '\n  '),
      2
    )
  end
end
return Definitions
