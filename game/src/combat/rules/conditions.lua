-- Conditions: named states with a duration, the same for every body.
-- Part of the rules facade (src/combat/rules.lua); functions are installed
-- on the shared rules table R and call each other through it.
-- The effects of each condition are data (content/enemies.lua: conditions).
local Archetypes = require('src.content.enemies')
local Attributes = require('src.combat.attributes')
local max = math.max
return function(R)
  R.conditionEffects = Archetypes.conditions
  function R.addCondition(target, id, duration)
    R.conditionEffects.get(id)
    assert(
      type(duration) == 'number' and duration >= 0 and duration < math.huge,
      'condition duration must be finite seconds'
    )
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
  function R.speedScale(target)
    return Attributes.scale(target, 'speed')
  end
  function R.recoveryScale(target)
    return Attributes.scale(target, 'recovery')
  end
end
