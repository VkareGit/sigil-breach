-- Resolve mode-owned equipment modifiers at the simulation boundary.
-- Weapon definitions remain independent of any mode's mutable record shape.
local Weapons = require('src.content.weapons')
local Modes = require('src.run.modes')
local Loadout = {}
function Loadout.attack(g, slot)
  return Weapons.attack(g, slot, Modes.act(g, 'weaponModifier'))
end
function Loadout.spread(g)
  return Weapons.spread(g, Modes.act(g, 'weaponModifier'))
end
return Loadout
