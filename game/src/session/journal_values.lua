-- Journal v3 stores each displayed observation once. Commands keep explicit
-- references; replay expands into detached input, never lends the archive to
-- gameplay. Equal sequence IDs alone are not proof of equal geometry.
local Observation = require('src.combat.observation')
local Values = {}
local reference = '_journalObservation'
local finite = require('src.core.mathx').finite
local MAX_DEPTH = require('src.core.data_reader').depthLimit
local function equal(a, b)
  if type(a) ~= type(b) then
    return false
  end
  if type(a) ~= 'table' then
    return a == b
  end
  for k, v in pairs(a) do
    if not equal(v, b[k]) then
      return false
    end
  end
  for k in pairs(b) do
    if a[k] == nil then
      return false
    end
  end
  return true
end
local function observed(value)
  return type(value) == 'table'
    and value.version == 1
    and value.session ~= nil
    and value.generation ~= nil
    and value.sequence ~= nil
    and type(value.bodies) == 'table'
    and type(value.origin) == 'table'
end
function Values.writer(journal, append)
  local index = {}
  local function store(value)
    local key = tostring(value.session)
      .. ':'
      .. tostring(value.generation)
      .. ':'
      .. tostring(value.sequence)
    local candidates = index[key] or {}
    index[key] = candidates
    for _, id in ipairs(candidates) do
      if equal(value, journal.observations[id]) then
        return { [reference] = id }
      end
    end
    local id = #journal.observations + 1
    append(journal.observations, Observation.copy(value))
    candidates[#candidates + 1] = id
    return { [reference] = id }
  end
  local function pack(value)
    if type(value) ~= 'table' then
      return value
    end
    local out = {}
    for k, v in pairs(value) do
      assert(k ~= reference, 'reserved journal reference in command data')
      out[k] = k == 'observation' and observed(v) and store(v) or pack(v)
    end
    return out
  end
  return pack
end
function Values.expand(value, observations)
  if type(value) ~= 'table' then
    return value
  end
  local id = value[reference]
  if id ~= nil then
    assert(type(id) == 'number' and id > 0 and id % 1 == 0, 'invalid journal observation reference')
    for key in pairs(value) do
      assert(key == reference, 'ambiguous journal observation reference')
    end
    local source = observations and observations[id]
    assert(observed(source), 'missing journal observation ' .. tostring(id))
    return Observation.copy(source)
  end
  local out = {}
  for k, v in pairs(value) do
    out[k] = Values.expand(v, observations)
  end
  return out
end

-- Validate without expanding every reference into another full geometry copy.
-- Archive tables must be finite, acyclic plain data. A pool is checked once;
-- every reference is then an O(1) lookup, including references in later entries.
function Values.validator(observations)
  local valid, visiting = {}, {}
  local function plain(value, references, depth)
    local kind = type(value)
    if kind == 'number' then
      assert(finite(value), 'non-finite journal number')
      return
    end
    if kind == 'nil' or kind == 'string' or kind == 'boolean' then
      return
    end
    assert(kind == 'table' and getmetatable(value) == nil, 'journal requires plain data')
    assert(depth < MAX_DEPTH and not visiting[value], 'cyclic or excessively nested journal data')
    if valid[value] then
      return
    end
    visiting[value] = true
    local id = value[reference]
    if id ~= nil then
      assert(
        references and finite(id) and id > 0 and id % 1 == 0,
        'invalid journal observation reference'
      )
      for key in pairs(value) do
        assert(key == reference, 'ambiguous journal observation reference')
      end
      assert(
        observations and observed(observations[id]),
        'missing journal observation ' .. tostring(id)
      )
    else
      for key, child in pairs(value) do
        assert(
          type(key) == 'string' or (type(key) == 'number' and finite(key)),
          'invalid journal table key'
        )
        plain(child, references, depth + 1)
      end
    end
    visiting[value], valid[value] = nil, true
  end
  if observations then
    assert(type(observations) == 'table', 'invalid journal observation pool')
    local count = 0
    for id, value in pairs(observations) do
      assert(
        type(id) == 'number' and finite(id) and id > 0 and id % 1 == 0 and observed(value),
        'invalid journal observation pool entry'
      )
      count = count + 1
      plain(value, false, 0)
    end
    assert(count == #observations, 'sparse journal observation pool')
  end
  return function(value)
    plain(value, observations ~= nil, 0)
  end
end
return Values
