-- Resolve mode-owned equipment modifiers at the simulation boundary.
-- Weapon definitions remain independent of any mode's mutable record shape.
local Weapons = require('src.content.weapons')
local Modes = require('src.run.modes')
local Loadout = {}
-- actor (optional): whose weapon (default the controlled knight's).
function Loadout.attack(g, slot, actor)
  return Weapons.attack(g, slot, Modes.act(g, 'weaponModifier'), actor)
end
function Loadout.spread(g, actor)
  return Weapons.spread(g, Modes.act(g, 'weaponModifier'), actor)
end
-- The reactions the run's modifier gives this weapon, if any.
function Loadout.reactions(g, weapon)
  local mod = weapon.glyphs and weapon.glyphs[Modes.act(g, 'weaponModifier')]
  return mod and mod.reactions
end
return Loadout
