-- What an actor can spend besides an ability's own uses. A character says how
-- much of each it has; an ability says what it costs.
local Registry = require('src.core.registry')
local Resources = Registry:new('resources')
Resources:register('mana', { desc = 'what spells are paid with' })
return Resources
