-- The screens a session can show (game.state) and what their keys do: a
-- registry of key -> command names (app/commands.lua). Input looks the key
-- up here first, then falls back to list navigation (up / down / tab /
-- return) on every screen except play. A new screen (base, hub, inventory)
-- is a new entry; input.lua does not change.
--   keys      key -> command
--   gameplay  true: keys go to the knight (Input:gameplayKey), no navigation
local Registry = require('src.core.registry')
local Screens = Registry:new('screens', function(screen, id)
  assert(type(screen.keys) == 'table', 'screen ' .. id .. ' needs keys')
end)
local settingsKeys = {
  escape = 'resume',
  backspace = 'menu',
  c = 'motion',
  ['-'] = 'sens_down',
  ['kp-'] = 'sens_down',
  ['='] = 'sens_up',
  ['kp+'] = 'sens_up',
}
local pausedKeys = { r = 'restart' }
for key, command in pairs(settingsKeys) do
  pausedKeys[key] = command
end
Screens:register('menu', { keys = { space = 'start', escape = 'quit' } })
Screens:register('playing', { keys = {}, gameplay = true })
Screens:register('paused', { keys = pausedKeys })
Screens:register('settings', { keys = settingsKeys })
Screens:register('dead', { keys = { escape = 'menu' } })
Screens:register('won', { keys = { escape = 'menu' } })
local shopKeys = { escape = 'shop_back' }
for slot = 1, 9 do
  shopKeys[tostring(slot)] = 'shop_weapon_' .. slot
end
Screens:register('shop', { keys = shopKeys })
Screens:register('confirm_new', { keys = { escape = 'new_cancel' } })
Screens:register('field_archive', { keys = { escape = 'field_open' } })
Screens:register('field_catalog', { keys = { escape = 'field_close' } })
-- List navigation shared by every non-gameplay screen.
Screens.navigation = { up = -1, down = 1, tab = 1 }
return Screens
