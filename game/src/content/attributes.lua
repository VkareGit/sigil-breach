-- The numbers a condition may change. A new one is one entry and one reader
-- through combat/attributes.lua: the rest of the rules do not change.
local Registry = require('src.core.registry')
local registry = Registry:new('attributes')
registry:register('speed', { desc = 'movement' })
registry:register('recovery', { desc = 'guard and breath recovery' })
registry:register('armor', { desc = 'armour rating of the body' })
return registry
