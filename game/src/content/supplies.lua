-- What can lie on the floor to be taken: its painted icon and size. What taking
-- it does is an entry of session/interactions.lua, or of the mode that owns it.
local Registry = require('src.core.registry')
local Supplies = Registry:new('supplies')
Supplies:register('health', { icon = 'health', size = 0.48 })
-- A pack for a weapon the creatures drop (run/drops.lua) is painted as its own rounds (Codex,
-- assets/art/pickups): shells and revolver rounds differ by shape, not only by colour.
Supplies:register('ammo', {
  icon = 'ammo',
  size = 0.48,
  images = {
    exorcist = 'assets/art/pickups/ammo_shells.png',
    judge = 'assets/art/pickups/ammo_rounds.png',
  },
})
Supplies:register('soul', { icon = 'soul', size = 0.42 })
return Supplies
