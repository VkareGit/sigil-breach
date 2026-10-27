-- The save core (plan v10 V4): a file is a tree of sections, each declared
-- by the module that owns its state (Save.declare: name, file, version,
-- schema, pack, unpack, restore, migrations, default). The core knows no
-- section: it writes their trees with core/serialize, reads them with the
-- literal core/data_reader (a save is never executed), checks a checksum,
-- migrates an older section version by its ordered list of functions and
-- rejects the whole file on any fault, before any state is touched.
-- Files are written atomically: a temporary file, verified, then swapped in
-- while the previous save is kept beside it.
--
-- A file:  SIGIL09 \n <file kind> \n <sequence> \n <checksum> \n <payload>
-- payload: { [section] = { version = n, data = <tree> }, ... }
local Serialize = require('src.core.serialize')
local Reader = require('src.core.data_reader')
local Execution = require('src.storage.execution')
local Save = { format = 'SIGIL09' }
-- Bounds of a save file the reader accepts.
Save.limits =
  { maxBytes = 8 * 1024 * 1024, maxValues = 2 * 1024 * 1024, maxDepth = 96, maxString = 64 * 1024 }
local sections, order = {}, {}
-- Section declaration:
--   name, file      the section and the kind of file it belongs to
--   version         the current version of its data (integer >= 1)
--   schema          (optional) core/schema Schema its data must satisfy
--   pack(source)    the data tree of the owner's state (source: what the
--                   file's owner passes: the session, a checkpoint...)
--   unpack(data)    the value read (validated; raise an error to reject)
--   restore(target, value)  (optional) put the value into a session
--   migrations      { [v] = function(data) return data of version v + 1 }
--   default()       (optional) the value when a file has no such section
--                   (an older file): without it the section is required
function Save.declare(def)
  assert(type(def.name) == 'string' and def.name:match('^[%w_]+$'), 'section needs a name')
  assert(type(def.file) == 'string' and def.file:match('^[%w_]+$'), 'section needs a file kind')
  assert(type(def.version) == 'number' and def.version >= 1 and def.version % 1 == 0)
  assert(type(def.pack) == 'function' and type(def.unpack) == 'function')
  assert(not sections[def.name], 'section declared twice: ' .. def.name)
  for v = 1, def.version - 1 do
    assert(def.migrations and def.migrations[v], 'section ' .. def.name .. ' lacks migration ' .. v)
  end
  sections[def.name] = def
  order[#order + 1] = def.name
  return def
end
-- Remove a declaration (a test's own section).
function Save.forget(name)
  sections[name] = nil
  for i = #order, 1, -1 do
    if order[i] == name then
      table.remove(order, i)
    end
  end
end
function Save.section(name)
  return sections[name]
end
-- The declared sections of a kind of file, in declaration order.
local function ofFile(file)
  local list = {}
  for _, name in ipairs(order) do
    if sections[name].file == file then
      list[#list + 1] = sections[name]
    end
  end
  return list
end
local function checksum(s)
  local a, b = 1, 0
  for i = 1, #s do
    a = (a + s:byte(i)) % 65521
    b = (b + a) % 65521
  end
  return tostring(b * 65536 + a)
end
Save.checksum = checksum
-- Every section of a kind of file packed from source.
function Save.capture(file, source)
  local packed = {}
  for _, def in ipairs(ofFile(file)) do
    packed[def.name] = { version = def.version, data = def.pack(source) }
  end
  return packed
end
function Save.encode(file, packed, sequence)
  local payload = Serialize.encode(packed)
  return table.concat({ Save.format, file, tostring(sequence), checksum(payload), payload }, '\n')
end
local function problems(schema, data, name)
  if schema then
    local found = schema:problems(data, name)
    assert(#found == 0, table.concat(found, '; '))
  end
end
-- The values of a file of this kind and its sequence, or nil and a reason.
-- Nothing is restored here; a fault anywhere rejects the whole file.
function Save.decode(file, text)
  if type(text) ~= 'string' or #text > Save.limits.maxBytes then
    return nil, 'invalid save size'
  end
  local ok, values, sequence = pcall(function()
    local format, kind, seq, hash, payload =
      text:match('^(SIGIL%d%d)\n([%w_]+)\n(%d+)\n(%d+)\n(.*)$')
    assert(format, 'not a save')
    assert(format == Save.format, 'save of another version: ' .. format)
    assert(kind == file, 'save of another kind: ' .. kind)
    assert(hash == checksum(payload), 'checksum mismatch')
    seq = tonumber(seq)
    assert(seq and seq >= 1 and seq <= 1e12, 'invalid sequence')
    local tree, reason = Reader.decode(payload, Save.limits)
    assert(type(tree) == 'table', reason or 'invalid payload')
    for name, entry in pairs(tree) do
      local def = sections[name]
      assert(def and def.file == file, 'unknown section ' .. tostring(name))
      assert(type(entry) == 'table', 'invalid section ' .. name)
      for key in pairs(entry) do
        assert(key == 'version' or key == 'data', 'invalid section field in ' .. name)
      end
      local v = entry.version
      assert(type(v) == 'number' and v >= 1 and v % 1 == 0, 'invalid version of ' .. name)
      assert(v <= def.version, 'section ' .. name .. ' from a newer game')
    end
    local out = {}
    for _, def in ipairs(ofFile(file)) do
      local entry = tree[def.name]
      if entry then
        local data = entry.data
        for v = entry.version, def.version - 1 do
          data = def.migrations[v](data)
        end
        problems(def.schema, data, def.name)
        out[def.name] = def.unpack(data)
      else
        assert(def.default, 'missing section ' .. def.name)
        out[def.name] = def.default()
      end
    end
    return out, seq
  end)
  if not ok then
    return nil, tostring(values)
  end
  return values, sequence
end
-- Put the values read into target, section by section (skip: a section
-- its caller restores itself).
function Save.restore(file, target, values, skip)
  for _, def in ipairs(ofFile(file)) do
    if def.restore and def.name ~= skip and values[def.name] ~= nil then
      def.restore(target, values[def.name])
    end
  end
  return target
end

-- FILES -----------------------------------------------------------------------
-- Through love.filesystem; the swap renames in the save directory. A test
-- may set Save.interrupt(stage) to stop a write after a stage ('temp': the
-- new save written beside the old one; 'swap': the old one moved aside).
local function real(path)
  return love.filesystem.getSaveDirectory() .. '/' .. path
end
local function exists(path)
  return love.filesystem.getInfo(path) ~= nil
end
local function move(from, to)
  if exists(to) then
    love.filesystem.remove(to)
  end
  return os.rename(real(from), real(to))
end
-- The newest complete save of name: the file itself, a new save left beside
-- it by an interrupted swap, or the previous one kept. Returns its values,
-- sequence and whether a damaged candidate was seen.
function Save.read(file, name)
  local best, sequence, damaged = nil, 0, false
  for _, path in ipairs({ name, name .. '.tmp', name .. '.previous' }) do
    local raw = love.filesystem.read(path)
    if raw then
      local values, seq = Save.decode(file, raw)
      if values and seq > sequence then
        best, sequence = values, seq
      elseif not values then
        damaged = true
      end
    end
  end
  return best, sequence, damaged
end
-- Write text as the save name: beside it first, verified, then swapped in.
function Save.write(name, text)
  if not Execution.canWrite() then
    return false, 'save writes are disabled during replay'
  end
  local temp, previous = name .. '.tmp', name .. '.previous'
  if not love.filesystem.write(temp, text) or love.filesystem.read(temp) ~= text then
    return false, 'could not write the save'
  end
  if Save.interrupt then
    Save.interrupt('temp')
  end
  if exists(name) and not move(name, previous) then
    return false, 'could not keep the previous save'
  end
  if Save.interrupt then
    Save.interrupt('swap')
  end
  if not move(temp, name) or love.filesystem.read(name) ~= text then
    return false, 'could not place the save'
  end
  return true
end
return Save
