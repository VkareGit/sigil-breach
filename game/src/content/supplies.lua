-- What can lie on the floor to be taken: its painted icon and size. What taking
-- it does is an entry of session/interactions.lua, or of the mode that owns it.
local Registry = require('src.core.registry')
local Supplies = Registry:new('supplies')
Supplies:register('health', { icon = 'health', size = 0.48 })
Supplies:register('ammo', { icon = 'ammo', size = 0.48 })
Supplies:register('soul', { icon = 'soul', size = 0.42 })
return Supplies
