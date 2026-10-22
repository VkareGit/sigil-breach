-- Conditions: named states with a duration, the same for every body.
-- Part of the rules facade (src/combat/rules.lua); functions are installed
-- on the shared rules table R and call each other through it.
-- The effects of each condition are data (content/enemies.lua: conditions).
local Archetypes = require('src.content.enemies')
local max = math.max
return function(R)
  R.conditionEffects = Archetypes.conditions
  function R.addCondition(target, id, duration)
    target.conditions = target.conditions or {}
    target.conditions[id] = max(target.conditions[id] or 0, duration or 0)
  end
  function R.has(target, id)
    return target.conditions and (target.conditions[id] or 0) > 0
  end
  function R.tick(target, dt)
    local c = target.conditions
    if not c then
      return
    end
    for id, t in pairs(c) do
      c[id] = t > dt and t - dt or nil
    end
  end
  -- Effects multiply in one fixed order (the catalogue's ids, sorted), never
  -- in the hash order of a body's conditions: the product is the same on
  -- every build, so replays stay exact.
  local order = {}
  for id in pairs(R.conditionEffects) do
    order[#order + 1] = id
  end
  table.sort(order)
  local function conditionScale(target, key)
    local s = 1
    local c = target.conditions
    if not c then
      return 1
    end
    for _, id in ipairs(order) do
      local t = c[id]
      if t and t > 0 then
        s = s * (R.conditionEffects[id][key] or 1)
      end
    end
    return s
  end
  function R.speedScale(target)
    return conditionScale(target, 'speed')
  end
  function R.recoveryScale(target)
    return conditionScale(target, 'recovery')
  end
end
