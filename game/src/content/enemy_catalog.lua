-- Compatibility view of src/content/enemies.lua for UI, catalog and audits.
-- The archetype data is the single source of truth.
local A = require('src.content.enemies')
local D = {}
for id, a in A.each() do
  local b = a.body
  D[id] = {
    kind = a.kind,
    variant = a.variant,
    name = a.name,
    hp = b.hp,
    armor = b.armor,
    souls = a.souls,
    speed = a.move.speed,
    mass = b.mass,
    resistances = b.resist,
    boss = b.boss,
  }
end
return D
