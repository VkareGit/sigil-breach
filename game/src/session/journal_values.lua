-- Journal v3 stores each displayed observation once. Commands keep explicit
-- references; replay expands into detached input, never lends the archive to
-- gameplay. Equal sequence IDs alone are not proof of equal geometry.
-- Journal v4 (plan v10 V5) also stores each body's geometry once while it
-- does not change: an observation lists references into the body pool, a
-- body equal to the last geometry kept for its id is that reference again,
-- and a body that changed is a delta: the earlier entry it starts from and
-- only its fields (and its surface's fields) that differ.
local Observation = require('src.combat.observation')
local Values = {}
local reference = '_journalObservation'
local bodyReference = '_journalBody'
local delta = '_journalDelta'
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
-- journal v4: recent observations stay searchable for the shot that uses
-- them (a held trigger keeps one for a few updates).
local recentObservations = require('src.content.tuning').recording.recall
-- The writer of command values. Returns pack(value) and, for journal v4,
-- used(observation): the shot resolved against that observation, so its
-- bodies enter the journal (an observation no shot used keeps only its
-- header: whether it was valid is all a replay asks of it). grow(bytes)
-- accounts for the text an observation gains then.
-- The fields of b that differ from a and the keys of a that b lacks.
local function differences(a, b, skip)
  local set, removed = {}, {}
  for k, v in pairs(b) do
    if k ~= skip and not equal(a[k], v) then
      set[k] = Observation.copy(v)
    end
  end
  for k in pairs(a) do
    if k ~= skip and b[k] == nil then
      removed[#removed + 1] = k
    end
  end
  table.sort(removed, function(x, y)
    return tostring(x) < tostring(y)
  end)
  return set, removed
end
-- A body from the entry it starts from and its delta.
local function apply(base, entry)
  local out = Observation.copy(base)
  for k, v in pairs(entry.set or {}) do
    out[k] = Observation.copy(v)
  end
  for _, k in ipairs(entry.removed or {}) do
    out[k] = nil
  end
  if entry.surface then
    out.surface = out.surface or {}
    for k, v in pairs(entry.surface) do
      out.surface[k] = Observation.copy(v)
    end
    for _, k in ipairs(entry.surfaceRemoved or {}) do
      out.surface[k] = nil
    end
  end
  return out
end
function Values.writer(journal, append, grow)
  local index = {}
  -- The pool index of the last geometry kept for each body id, and that
  -- geometry whole.
  local last, whole = {}, {}
  local function body(value)
    local id = value.id
    local previous = id ~= nil and last[id]
    local entry
    if previous then
      local base = whole[id]
      if equal(value, base) then
        return { [bodyReference] = previous }
      end
      local set, removed = differences(base, value, 'surface')
      entry = { [delta] = previous, set = set, removed = removed }
      if not equal(base.surface, value.surface) then
        if type(base.surface) == 'table' and type(value.surface) == 'table' then
          entry.surface, entry.surfaceRemoved = differences(base.surface, value.surface)
        else
          entry.set.surface = Observation.copy(value.surface)
          if value.surface == nil then
            entry.removed[#entry.removed + 1] = 'surface'
          end
        end
      end
    else
      entry = Observation.copy(value)
    end
    append(journal.bodies, entry)
    local kept = #journal.bodies
    if id ~= nil then
      last[id], whole[id] = kept, Observation.copy(value)
    end
    return { [bodyReference] = kept }
  end
  -- journal v4: live observation table -> its id; the recent ones by id.
  local ids = setmetatable({}, { __mode = 'k' })
  local recent, filled = {}, {}
  local function header(value)
    local stored = {}
    for k, v in pairs(value) do
      if k ~= 'bodies' then
        stored[k] = Observation.copy(v)
      end
    end
    stored.bodies = {}
    return stored
  end
  local function store(value)
    if journal.bodies then
      local id = ids[value]
      if not id then
        for _, entry in ipairs(recent) do
          if equal(value, entry.value) then
            id = entry.id
          end
        end
      end
      if not id then
        append(journal.observations, header(value))
        id = #journal.observations
        table.insert(recent, 1, { id = id, value = value })
        recent[recentObservations + 1] = nil
      end
      ids[value] = id
      return { [reference] = id }
    end
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
  local function used(value)
    local id = ids[value]
    if not id then
      for _, entry in ipairs(recent) do
        if equal(value, entry.value) then
          id = entry.id
        end
      end
    end
    assert(id, 'a shot used an observation the journal did not record')
    if filled[id] then
      return
    end
    filled[id] = true
    local refs = journal.observations[id].bodies
    for i, b in ipairs(value.bodies) do
      refs[i] = body(b)
    end
    if grow then
      grow(refs)
    end
  end
  return pack, used
end -- Body n of a v4 pool, whole (resolved through its deltas, kept per pool).
local resolved = setmetatable({}, { __mode = 'k' })
function Values.body(bodies, n)
  assert(type(n) == 'number' and type(bodies[n]) == 'table', 'missing journal body ' .. tostring(n))
  local cache = resolved[bodies] or {}
  resolved[bodies] = cache
  local chain, i = {}, n
  while not cache[i] do
    local entry = bodies[i]
    assert(type(entry) == 'table', 'missing journal body ' .. tostring(i))
    chain[#chain + 1] = i
    local base = entry[delta]
    if base == nil then
      break
    end
    assert(finite(base) and base >= 1 and base < i and base % 1 == 0, 'invalid journal body delta')
    i = base
  end
  for j = #chain, 1, -1 do
    local k = chain[j]
    local entry = bodies[k]
    cache[k] = entry[delta] == nil and entry or apply(cache[entry[delta]], entry)
  end
  return cache[n]
end
-- bodies (journal v4): the body pool the observations refer to.
function Values.expand(value, observations, bodies)
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
    local out = Observation.copy(source)
    if bodies then
      for i, b in ipairs(out.bodies) do
        out.bodies[i] = Observation.copy(Values.body(bodies, b[bodyReference]))
      end
    end
    return out
  end
  local out = {}
  for k, v in pairs(value) do
    out[k] = Values.expand(v, observations, bodies)
  end
  return out
end

-- Validate without expanding every reference into another full geometry copy.
-- Archive tables must be finite, acyclic plain data. A pool is checked once;
-- every reference is then an O(1) lookup, including references in later entries.
-- bodies (journal v4): the body pool; every observation's bodies must be
-- references into it.
function Values.validator(observations, bodies)
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
      if bodies then
        for _, b in ipairs(value.bodies) do
          local n = type(b) == 'table' and b[bodyReference]
          assert(
            finite(n) and n > 0 and n % 1 == 0 and type(bodies[n]) == 'table',
            'missing journal body ' .. tostring(n)
          )
        end
      end
    end
    assert(count == #observations, 'sparse journal observation pool')
  end
  if bodies then
    assert(type(bodies) == 'table', 'invalid journal body pool')
    local count = 0
    for n, b in pairs(bodies) do
      assert(finite(n) and n > 0 and n % 1 == 0 and type(b) == 'table', 'invalid journal body')
      local base = b[delta]
      assert(
        base == nil or (finite(base) and base >= 1 and base < n and base % 1 == 0),
        'invalid journal body delta'
      )
      count = count + 1
      plain(b, false, 0)
    end
    assert(count == #bodies, 'sparse journal body pool')
  end
  return function(value)
    plain(value, observations ~= nil, 0)
  end
end
return Values
