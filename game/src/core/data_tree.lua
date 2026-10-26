-- Live values as a plain data tree and back (plan v10 V4): what a save
-- section writes with core/serialize and reads with core/data_reader.
-- A definition (a table reachable from a loaded src.content module) is
-- written as its path from that module, never copied: read back, it is the
-- same definition. A table met twice is written once and referred to after
-- (a hazard both in its pool and as a demon's pending strike stays one
-- table). Numbers outside the reader's finite range are written by name.
-- Functions, userdata and table keys cannot be written: an error says where.
local Tree = {}
local DEF, REF, ID, VALUES, NUMBER = '$def', '$ref', '$id', '$v', '$n'
local CONTENT = '^src%.content%.'
-- Definitions: table -> { module, key, key, ... }, rebuilt when the loaded
-- content modules change.
local paths, modules = nil, {}
local function rank(k)
  local t = type(k)
  return (t == 'number' and '1' or t == 'string' and '2' or '3') .. tostring(k)
end
local function sortedKeys(t)
  local keys = {}
  for k in pairs(t) do
    if type(k) ~= 'table' then
      keys[#keys + 1] = k
    end
  end
  table.sort(keys, function(a, b)
    if type(a) == 'number' and type(b) == 'number' then
      return a < b
    end
    return rank(a) < rank(b)
  end)
  return keys
end
local function definitions()
  local names, changed = {}, not paths
  for name, module in pairs(package.loaded) do
    if type(name) == 'string' and name:match(CONTENT) then
      names[#names + 1] = name
      changed = changed or modules[name] ~= module
    end
  end
  local count = 0
  for _ in pairs(modules) do
    count = count + 1
  end
  if not changed and count == #names then
    return paths
  end
  table.sort(names)
  paths, modules = {}, {}
  -- Breadth first in a stable order: each definition gets its shortest path.
  local queue, head = {}, 1
  for _, name in ipairs(names) do
    local module = package.loaded[name]
    modules[name] = module
    if type(module) == 'table' and not paths[module] then
      paths[module] = { name }
      queue[#queue + 1] = module
    end
  end
  while head <= #queue do
    local t = queue[head]
    head = head + 1
    local base = paths[t]
    for _, k in ipairs(sortedKeys(t)) do
      local v = t[k]
      if type(v) == 'table' and not paths[v] then
        local path = { unpack(base) }
        path[#path + 1] = k
        paths[v] = path
        queue[#queue + 1] = v
      end
    end
  end
  return paths
end
-- The definitions index is rebuilt on the next use (after content tooling
-- added nested definitions to a loaded module).
function Tree.invalidate()
  paths, modules = nil, {}
end
local function number(n)
  if n ~= n then
    return { [NUMBER] = 'nan' }
  elseif n == math.huge then
    return { [NUMBER] = 'inf' }
  elseif n == -math.huge then
    return { [NUMBER] = '-inf' }
  end
  return n
end
-- The tree of value v. skip(t, k) (optional): leave field k of table t out.
function Tree.encode(v, skip)
  local index = definitions()
  local ids, count = {}, 0
  local function encode(x, where)
    local t = type(x)
    if t == 'number' then
      return number(x)
    elseif t == 'string' or t == 'boolean' or t == 'nil' then
      return x
    elseif t ~= 'table' then
      error('cannot save a ' .. t .. ' at ' .. where, 0)
    end
    if index[x] then
      return { [DEF] = index[x] }
    end
    if ids[x] then
      return { [REF] = ids[x] }
    end
    count = count + 1
    local id = count
    ids[x] = id
    local values = {}
    for _, k in ipairs(sortedKeys(x)) do
      if not (skip and skip(x, k)) then
        values[k] = encode(x[k], where .. '.' .. tostring(k))
      end
    end
    for k in pairs(x) do
      if type(k) == 'table' then
        error('cannot save a table key at ' .. where, 0)
      end
    end
    return { [ID] = id, [VALUES] = values }
  end
  return encode(v, 'value')
end
-- The value of tree t: definitions found again, shared tables shared again.
-- Raises an error on anything Tree.encode would not have written.
function Tree.decode(t)
  local tables = {}
  -- First every written table, so a reference may come before its table.
  local function collect(x)
    if type(x) ~= 'table' then
      return
    end
    if x[ID] ~= nil then
      local id = x[ID]
      assert(type(id) == 'number' and id % 1 == 0 and not tables[id], 'invalid table id')
      assert(type(x[VALUES]) == 'table', 'table without values')
      tables[id] = {}
      for _, v in pairs(x[VALUES]) do
        collect(v)
      end
    end
  end
  collect(t)
  local function decode(x)
    if type(x) ~= 'table' then
      return x
    end
    if x[NUMBER] ~= nil then
      local name = x[NUMBER]
      assert(name == 'nan' or name == 'inf' or name == '-inf', 'invalid number')
      return name == 'inf' and math.huge or (name == '-inf' and -math.huge or 0 / 0)
    end
    if x[DEF] ~= nil then
      local path = x[DEF]
      assert(type(path) == 'table' and type(path[1]) == 'string' and path[1]:match(CONTENT))
      local value = package.loaded[path[1]]
      assert(type(value) == 'table', 'definition module not loaded: ' .. path[1])
      for i = 2, #path do
        value = value[path[i]]
        assert(type(value) == 'table', 'unknown definition')
      end
      return value
    end
    if x[REF] ~= nil then
      return assert(tables[x[REF]], 'reference to an unknown table')
    end
    local out = assert(tables[x[ID]], 'invalid table')
    for k, v in pairs(x[VALUES]) do
      out[k] = decode(v)
    end
    return out
  end
  return decode(t)
end
return Tree
