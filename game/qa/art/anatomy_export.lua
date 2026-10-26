-- The anatomy export (plan v10 V7): an annotation (content/art/
-- anatomy_regions.lua: frames of parts and anchors, in frame UV), however it
-- was made (authored with Author helpers, edited in tools/art/
-- anatomy_editor, generated from part layers by qa/art/anatomy_layers.lua),
-- written as a data file the game loads like any other annotation
-- (content/art/anatomy/index.lua names it). Numbers are written as the
-- shortest decimal that reads back to the same double, so an exported
-- annotation equals its source exactly (same reads, same masks clipping).
local Export = {}
local function number(value)
  if value == math.floor(value) and math.abs(value) < 2 ^ 53 then
    return string.format('%d', value)
  end
  for digits = 1, 17 do
    local text = string.format('%.' .. digits .. 'g', value)
    if tonumber(text) == value then
      return text
    end
  end
end
Export.number = number
local function scalar(value)
  if type(value) == 'string' then
    return string.format('%q', value)
  elseif type(value) == 'number' then
    return number(value)
  end
  return tostring(value)
end
local function isList(t)
  local n = 0
  for _ in pairs(t) do
    n = n + 1
  end
  return n == #t
end
local function flat(t)
  for _, v in pairs(t) do
    if type(v) == 'table' then
      return false
    end
  end
  return true
end
local function keys(t)
  local out = {}
  for k in pairs(t) do
    out[#out + 1] = k
  end
  table.sort(out, function(a, b)
    if type(a) == type(b) then
      return a < b
    end
    return type(a) == 'number'
  end)
  return out
end
-- Any table of strings, numbers, booleans and tables, written as Lua.
function Export.value(value, indent)
  indent = indent or ''
  if type(value) ~= 'table' then
    return scalar(value)
  end
  if isList(value) and flat(value) then
    local out = {}
    for i, v in ipairs(value) do
      out[i] = scalar(v)
    end
    return '{ ' .. table.concat(out, ', ') .. ' }'
  end
  local inner, out = indent .. '  ', {}
  if isList(value) then
    for _, v in ipairs(value) do
      out[#out + 1] = inner .. Export.value(v, inner) .. ','
    end
  else
    for _, k in ipairs(keys(value)) do
      local name = type(k) == 'string' and k:match('^[%a_][%w_]*$') and k
        or ('[' .. scalar(k) .. ']')
      out[#out + 1] = inner .. name .. ' = ' .. Export.value(value[k], inner) .. ','
    end
  end
  return '{\n' .. table.concat(out, '\n') .. '\n' .. indent .. '}'
end
function Export.text(id, annotation)
  return '-- The '
    .. id
    .. ' anatomy annotation as data (content/art/anatomy_regions.lua), written\n'
    .. '-- by the anatomy tools (qa/art/anatomy_export.lua). Frame UV: u across, v\n'
    .. '-- down from the top-left of each frame (content/art/anatomy/author.lua).\n'
    .. 'return '
    .. Export.value(annotation)
    .. '\n'
end
-- Exact structural equality: same keys, same strings, the same doubles.
function Export.same(a, b)
  if type(a) ~= type(b) then
    return false
  end
  if type(a) ~= 'table' then
    return a == b
  end
  for k, v in pairs(a) do
    if not Export.same(v, b[k]) then
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
-- The annotation read back from its text.
function Export.read(text)
  return assert(loadstring(text))()
end
return Export
