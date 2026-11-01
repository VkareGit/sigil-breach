-- Spawning: a fresh body from its archetype and its attack slots.
-- Part of the rules facade (src/combat/rules.lua); functions are installed
-- on the shared rules table R and call each other through it.
local Archetypes = require('src.content.enemies')
local defaults = Archetypes.defaults
return function(R)
  -- Copy the body of an archetype onto a fresh enemy record.
  function R.equip(e, archetype)
    local b = archetype.body
    e.archetype = archetype
    e.hp = b.hp
    e.maxHp = b.hp
    e.armorRating = b.armor
    e.resistances = b.resist
    e.immune = b.immune
    e.soak = b.soak
    e.locationArmor = b.locationArmor
    e.zones = b.zones or defaults.zones
    e.mass = b.mass
    e.boss = b.boss or false
    e.speed = archetype.move.speed
    e.rewardSouls = archetype.souls
    e.displayName = archetype.name
    e.conditions = {}
    e.phaseBaseHp = archetype.phases and e.maxHp or nil
    return e
  end
  -- How many demons may attack at once (a body may keep its own count).
  function R.maxAttackers(e)
    return R.archetype(e).maxAttackers or defaults.attackers
  end
end
