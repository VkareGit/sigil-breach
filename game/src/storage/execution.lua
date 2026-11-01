-- External scalar facts belong to the command archive, not an implicit disk
-- dependency. Replay contexts are owned by the session and never serialized as
-- gameplay state. Durable writes are forbidden while replay is executing,
-- including synchronous listeners and nested calls without a session argument.
local finite = require('src.core.mathx').finite
local Execution = {}
local readers = setmetatable({}, { __mode = 'k' })
local replays = setmetatable({}, { __mode = 'k' })
local replayDepth = 0
local function root(g)
  return g and (g._contextRoot or g)
end
local function scalar(value)
  local kind = type(value)
  return value == nil
    or kind == 'boolean'
    or kind == 'string'
    or (kind == 'number' and finite(value))
end
local function input(entry)
  assert(type(entry) == 'table', 'invalid external input')
  assert(
    type(entry.name) == 'string' and entry.name:match('^[%w_.-]+$'),
    'invalid external input name'
  )
  assert(scalar(entry.value), 'external input must be a finite scalar')
  for key in pairs(entry) do
    assert(key == 'name' or key == 'value', 'invalid external input field')
  end
end
function Execution.validate(inputs)
  if inputs == nil then
    return -- Legacy archive: valid until it needs an unrecorded external fact.
  end
  assert(type(inputs) == 'table', 'invalid external input list')
  local count = 0
  for index, entry in pairs(inputs) do
    assert(finite(index) and index > 0 and index % 1 == 0, 'invalid external input index')
    input(entry)
    count = count + 1
  end
  assert(count == #inputs, 'sparse external input list')
end
-- One observer per recording session. The callback must not retain its owner.
function Execution.observe(g, consume)
  g = root(g)
  assert(not readers[g], 'session external inputs already observed')
  readers[g] = consume
  return function()
    if readers[g] == consume then
      readers[g] = nil
    end
  end
end
local function obtain(g, name, read, legacyEffect)
  g = root(g)
  local replay = replays[g]
  if replay then
    if replay.inputs == nil and legacyEffect then
      return nil -- Older archives performed no writes under their test policy.
    end
    local entry = replay.inputs and replay.inputs[replay.next]
    assert(entry, 'journal lacks external input ' .. name)
    assert(
      entry.name == name,
      'journal external input order differs: expected ' .. entry.name .. ', got ' .. name
    )
    replay.next = replay.next + 1
    return entry.value
  end
  assert(replayDepth == 0, 'unrecorded external input during replay: ' .. name)
  local value = read()
  local entry = { name = name, value = value }
  input(entry)
  if readers[g] then
    readers[g](entry)
  end
  return value
end
-- A durable effect may return a scalar receipt (e.g. an error displayed by the
-- session). The receipt replays, the effect never does. Tests record the same
-- successful no-op receipt without requiring a writable save directory.
function Execution.effect(g, name, write)
  return obtain(g, name, function()
    if Execution.canWrite(g) then
      return write()
    end
  end, true)
end
-- Called only after archive preflight. The returned cleanup is mandatory on
-- success and failure, and restores a surrounding replay of the same session.
function Execution.beginReplay(g, inputs)
  g = root(g)
  local previous = replays[g]
  local replay = { inputs = inputs, next = 1 }
  replays[g], replayDepth = replay, replayDepth + 1
  local active = true
  return function()
    if active then
      replays[g], replayDepth = previous, replayDepth - 1
      active = false
    end
  end, function()
    assert(not inputs or replay.next == #inputs + 1, 'journal has unused external inputs')
  end
end
function Execution.canWrite(g)
  return replayDepth == 0 and not (g and g.testing)
end
return Execution
