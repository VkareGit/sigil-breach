-- A body's named numbers as its conditions change them. A body with no
-- condition takes the fast path; a body with some multiplies them in one fixed
-- order (the catalogue's ids, sorted), so the product is the same on every build
-- and replays stay exact.
local Conditions = require('src.content.conditions')
local Attributes = {}
function Attributes.scale(target, attribute)
  local c = target.conditions
  if not c then
    return 1
  end
  local s = 1
  for _, id in ipairs(Conditions.ids()) do
    local t = c[id]
    if t and t > 0 then
      local modifier = Conditions[id].modifiers[attribute]
      if modifier then
        s = s * modifier.mul
      end
    end
  end
  return s
end
-- Whether a condition of the body forbids this act.
function Attributes.forbids(target, act)
  local c = target.conditions
  if not c then
    return false
  end
  for id, t in pairs(c) do
    if t > 0 and Conditions[id].forbids[act] then
      return true
    end
  end
  return false
end
return Attributes
