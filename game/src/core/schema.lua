-- Declarative schemas for definitions (creatures, bodies, actions, weapons,
-- components). A schema lists every field with its type, default and limits;
-- fill() completes a definition from the defaults, validate() reports every
-- broken field with its path, inherit() merges a definition over its parent
-- (data inheritance: `extends`). Used at load time only, never per frame.
--
-- Field spec: { type = 'number'|'string'|'boolean'|'table'|'function'|'any',
--   default = v, required = true, min = n, max = n, values = {...},
--   check = fn (value -> message when it is wrong),
--   schema = Schema (nested record), list = Schema (array of records),
--   desc = 'what it means' }
local Class = require('src.core.class')
local Schema = Class:extend('Schema')

local function copy(v)
  if type(v) ~= 'table' then
    return v
  end
  local t = {}
  for k, x in pairs(v) do
    t[k] = copy(x)
  end
  return t
end
Schema.copy = copy

-- name: for messages; fields: { key = spec }; open: extra keys allowed.
function Schema:init(name, fields, open)
  self.name = name
  self.fields = fields or {}
  self.open = open or false
end
-- A schema with the fields of this one plus (or overriding) extra fields.
function Schema:extend(name, fields, open)
  local merged = {}
  for k, v in pairs(self.fields) do
    merged[k] = v
  end
  for k, v in pairs(fields or {}) do
    merged[k] = v
  end
  return Schema:new(name, merged, open == nil and self.open or open)
end
-- A copy of def completed with every default (nested schemas included).
function Schema:fill(def)
  local out = {}
  for k, v in pairs(def or {}) do
    out[k] = v
  end
  for key, spec in pairs(self.fields) do
    if out[key] == nil and spec.default ~= nil then
      out[key] = copy(spec.default)
    end
    if spec.schema and type(out[key]) == 'table' then
      out[key] = spec.schema:fill(out[key])
    elseif spec.list and type(out[key]) == 'table' then
      local list = {}
      -- Preserve every key until validation. ipairs would silently truncate a
      -- sparse definition and discard malformed or misspelled entries.
      for i, item in pairs(out[key]) do
        list[i] = type(item) == 'table' and spec.list:fill(item) or item
      end
      out[key] = list
    end
  end
  return out
end
local function typeOf(v)
  return type(v)
end
-- Every problem of def as 'path: message' strings (empty when valid).
function Schema:problems(def, path, out)
  out = out or {}
  path = path or self.name
  if type(def) ~= 'table' then
    out[#out + 1] = path .. ': expected a table'
    return out
  end
  for key, spec in pairs(self.fields) do
    local v = def[key]
    local where = path .. '.' .. key
    if v == nil then
      if spec.required then
        out[#out + 1] = where .. ': required'
      end
    else
      if spec.type and spec.type ~= 'any' and typeOf(v) ~= spec.type then
        out[#out + 1] = where .. ': expected ' .. spec.type .. ', got ' .. typeOf(v)
      elseif type(v) == 'number' then
        if v ~= v or v == math.huge or v == -math.huge then
          out[#out + 1] = where .. ': not a finite number'
        elseif spec.min and v < spec.min then
          out[#out + 1] = where .. ': below ' .. spec.min
        elseif spec.max and v > spec.max then
          out[#out + 1] = where .. ': above ' .. spec.max
        end
      end
      if spec.values then
        local ok = false
        for _, allowed in ipairs(spec.values) do
          ok = ok or allowed == v
        end
        if not ok then
          out[#out + 1] = where .. ': ' .. tostring(v) .. ' is not one of the allowed values'
        end
      end
      local complaint = spec.check and spec.check(v)
      if complaint then
        out[#out + 1] = where .. ': ' .. complaint
      end
      if spec.schema and type(v) == 'table' then
        spec.schema:problems(v, where, out)
      elseif spec.list and type(v) == 'table' then
        local count, last = 0, 0
        for i, item in pairs(v) do
          if type(i) ~= 'number' or i < 1 or i % 1 ~= 0 then
            out[#out + 1] = where .. ': expected consecutive integer keys'
          else
            count, last = count + 1, math.max(last, i)
          end
          spec.list:problems(item, where .. '[' .. tostring(i) .. ']', out)
        end
        if count ~= last then
          out[#out + 1] = where .. ': sparse lists are not allowed'
        end
      end
    end
  end
  if not self.open then
    for key in pairs(def) do
      if self.fields[key] == nil then
        out[#out + 1] = path .. '.' .. tostring(key) .. ': unknown field'
      end
    end
  end
  return out
end
-- Raise one error listing every problem (load-time failure, early and clear).
function Schema:validate(def, path)
  local problems = self:problems(def, path)
  if #problems > 0 then
    error('invalid definition:\n  ' .. table.concat(problems, '\n  '), 2)
  end
  return def
end
-- fill + validate in one step.
function Schema:build(def, path)
  return self:validate(self:fill(def), path)
end
-- Data inheritance: child over parent. Records merge key by key, arrays
-- (lists) and non-table values of the child replace the parent's. An empty
-- child list must also clear an inherited array (effects, attacks, loadout).
local function isArray(t)
  return type(t) == 'table' and t[1] ~= nil
end
function Schema.inherit(parent, child)
  if type(parent) ~= 'table' or type(child) ~= 'table' or isArray(parent) or isArray(child) then
    return copy(child)
  end
  local out = copy(parent)
  for k, v in pairs(child) do
    if type(v) == 'table' and type(out[k]) == 'table' and not isArray(v) then
      out[k] = Schema.inherit(out[k], v)
    else
      out[k] = copy(v)
    end
  end
  return out
end
return Schema
