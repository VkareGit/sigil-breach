-- Compatibility view of src/content/enemies.lua for UI, catalog and audits.
-- The archetype data is the single source of truth: this reads it when asked, so a creature
-- registered or replaced later is seen as it is now.
local Archetypes = require('src.content.enemies')
return setmetatable({}, {
  __index = function(_, id)
    local a = Archetypes.get(id)
    local b = a and a.body
    return b
      and {
        kind = a.kind,
        variant = a.variant,
        name = a.name,
        hp = b.hp,
        armor = b.armor,
        souls = a.souls,
        speed = a.move.speed,
        mass = b.mass,
        resistances = b.resist,
        tier = b.tier,
      }
  end,
})
