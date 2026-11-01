-- Stable text form of plain data (numbers, strings, booleans, tables with
-- sorted keys). Used by component snapshots (saves, replays) and the golden
-- master; the same value always gives the same text.
local DataReader = require('src.core.data_reader')
local Serialize = {}
local format = string.format
local function key(k)
  return type(k) == 'number' and format('%.17g', k) or tostring(k)
end
function Serialize.encode(v)
  local t = type(v)
  if t == 'number' then
    return format('%.17g', v)
  elseif t == 'string' then
    return format('%q', v)
  elseif t == 'boolean' or t == 'nil' then
    return tostring(v)
  elseif t == 'table' then
    local keys = {}
    for k in pairs(v) do
      keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b)
      return key(a) < key(b)
    end)
    local out = {}
    for i, k in ipairs(keys) do
      out[i] = '[' .. Serialize.encode(k) .. ']=' .. Serialize.encode(v[k])
    end
    return '{' .. table.concat(out, ',') .. '}'
  end
  return '<' .. t .. '>'
end
-- Only the listed fields of a record, in list order.
function Serialize.fields(record, fields)
  local out = {}
  for i, f in ipairs(fields) do
    out[i] = Serialize.encode(record[f])
  end
  return table.concat(out, ',')
end
-- Literal-only parsing with bounded input, depth, string length and value count.
-- Invalid input returns nil plus a diagnostic; a valid false stays false.
function Serialize.decode(text, limits)
  return DataReader.decode(text, limits)
end
return Serialize
