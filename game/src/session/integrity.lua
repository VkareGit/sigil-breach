-- Canonical simulation data for replay diagnostics. Presentation, application
-- machinery and scratch buffers are excluded; gameplay data and RNG are not.
local Serialize = require('src.core.serialize')
local Integrity = {}
local excluded = { bus = true, ecs = true, view = true, testing = true, events = true }
-- The existing world mesh cache is renderer-owned despite living on the map.
local excludedPaths = { ['world["mesh"]'] = true, ['world["meshRevision"]'] = true }
local function keys(t)
  local out = {}
  for k, v in pairs(t) do
    if (type(k) == 'string' or type(k) == 'number') and type(v) ~= 'function' then
      out[#out + 1] = k
    end
  end
  table.sort(out, function(a, b)
    return type(a) .. tostring(a) < type(b) .. tostring(b)
  end)
  return out
end
local function flatten(value, path, out, seen)
  if excludedPaths[path] then
    return
  end
  if type(value) ~= 'table' then
    assert(
      type(value) ~= 'userdata' and type(value) ~= 'thread',
      'non-data simulation field: ' .. path
    )
    out[path] = Serialize.encode(value)
    return
  end
  if seen[value] then
    out[path] = '@' .. seen[value]
    return
  end
  seen[value] = path
  out[path] = '{}'
  for _, key in ipairs(keys(value)) do
    flatten(value[key], path .. '[' .. Serialize.encode(key) .. ']', out, seen)
  end
end
function Integrity.capture(g)
  local out = {}
  for _, key in ipairs(keys(g)) do
    if not excluded[key] and tostring(key):sub(1, 1) ~= '_' then
      local value = key == 'rng' and { sim = g.rng.sim } or g[key]
      flatten(value, tostring(key), out, {})
    end
  end
  return out
end
function Integrity.difference(expected, actual)
  local all = {}
  for key in pairs(expected) do
    all[key] = true
  end
  for key in pairs(actual) do
    all[key] = true
  end
  for _, key in ipairs(keys(all)) do
    if expected[key] ~= actual[key] then
      return key .. ': expected ' .. tostring(expected[key]) .. ', got ' .. tostring(actual[key])
    end
  end
end
return Integrity
