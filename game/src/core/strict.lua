-- Strict mode for entities: writing a field that no component of the
-- entity declares is an error. Enabled by the QA runtime (tests), never in
-- the shipped game, so it costs nothing at play time.
local Strict = { enabled = false, retired = {} }
-- Fields an entity kind no longer has (moved elsewhere): reading one is an
-- error naming where it went. label: the prefab; names: list; hint: message.
function Strict.retire(label, names, hint)
  local set = Strict.retired[label] or {}
  for _, name in ipairs(names) do
    set[name] = hint
  end
  Strict.retired[label] = set
end
-- allowed: set of field names; label: what the table is (for the message).
function Strict.guard(t, allowed, label)
  if not Strict.enabled or getmetatable(t) then
    return t
  end
  local retired = Strict.retired[label]
  return setmetatable(t, {
    __index = retired and function(_, key)
      if retired[key] then
        error((label or 'entity') .. '.' .. tostring(key) .. ' is retired: ' .. retired[key], 2)
      end
    end,
    __newindex = function(tbl, key, value)
      if not allowed[key] then
        error((label or 'entity') .. ': undeclared field ' .. tostring(key), 2)
      end
      rawset(tbl, key, value)
    end,
  })
end
return Strict
