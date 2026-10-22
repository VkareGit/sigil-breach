-- What each screen draws and which buttons it offers (0.24 F7). The screen
-- is the session's state (app/screens.lua holds its keys); a new screen is a
-- new entry here and its file in ui/screens/, ui/interface.lua does not change.
--   draw(g, s, U)       paint the screen (U: the interface: fonts, focus)
--   controls(g, s)      its buttons, or nil
-- Buttons come from a chain of providers, first answer wins (Chain of
-- Responsibility): the proving ground's archive and catalogue, the
-- expedition's own screens, the help and map overlays, then the screen.
local Registry = require('src.core.registry')
local Views = Registry:new('views')
-- A screen file's draw (full module names: tools/check follows them).
local function screen(module)
  return function(g, s, U)
    return require(module).draw(g, s, U)
  end
end
local hud = screen('src.ui.screens.hud')
Views:register('playing', { draw = hud })
Views:register('paused', {
  draw = function(g, s, U)
    hud(g, s, U)
    screen('src.ui.screens.pause')(g, s, U)
  end,
})
Views:register('menu', { draw = screen('src.ui.screens.menu') })
Views:register('settings', { draw = screen('src.ui.screens.pause') })
Views:register('dead', { draw = screen('src.ui.screens.ending') })
Views:register('won', { draw = screen('src.ui.screens.ending') })
Views:register('shop', {
  draw = function(g)
    require('src.ui.descent').shop(g)
  end,
})
Views:register('confirm_new', {
  draw = function()
    require('src.ui.descent').confirm()
  end,
})
Views:register('field_archive', {
  draw = function(g, _, U)
    require('src.ui.occult_archive').draw(g, U)
  end,
})
Views:register('field_catalog', {
  draw = function(g, _, U)
    require('src.ui.test_field').draw(g, U)
  end,
})
-- Overlays over any screen.
Views.overlays = {
  map = screen('src.ui.screens.map'),
  help = screen('src.ui.screens.help'),
}
-- The view of a session (an unknown state shows the play screen).
function Views.of(g)
  return Views:find(g.state) or Views:get('playing')
end
-- Settings and pause share one page; settings swaps the last row.
local function pageControls(g, s)
  local settings = g.state == 'settings'
  return {
    {
      id = 'resume',
      label = settings and 'BACK TO MENU  [ ESC ]' or 'BACK TO COMBAT  [ ESC ]',
      x = 380,
      y = 164,
      w = 520,
      h = 46,
    },
    { id = 'sens_down', label = '−', x = 784, y = 249, w = 48, h = 34 },
    { id = 'sens_up', label = '+', x = 852, y = 249, w = 48, h = 34 },
    { id = 'fov_down', label = '−', x = 784, y = 297, w = 48, h = 34 },
    { id = 'fov_up', label = '+', x = 852, y = 297, w = 48, h = 34 },
    { id = 'music_down', label = '−', x = 784, y = 345, w = 48, h = 34 },
    { id = 'music_up', label = '+', x = 852, y = 345, w = 48, h = 34 },
    {
      id = 'motion',
      label = s.motion == false and 'OFF  [ C ]' or 'ON  [ C ]',
      x = 670,
      y = 397,
      w = 230,
      h = 42,
    },
    {
      id = 'hints',
      label = s.hints == false and 'OFF' or 'ON',
      x = 670,
      y = 445,
      w = 230,
      h = 42,
    },
    { id = 'help', label = 'CONTROLS / DEMONS', x = 380, y = 510, w = 252, h = 42 },
    {
      id = 'mute',
      label = s.muted and 'UNMUTE [ M ]' or 'MUTE [ M ]',
      x = 648,
      y = 510,
      w = 252,
      h = 42,
    },
    {
      id = settings and 'fullscreen' or 'restart',
      label = settings and 'FULLSCREEN [ F11 ]' or 'NEW TRIAL  [ R ]',
      x = 380,
      y = 570,
      w = 252,
      h = 42,
    },
    {
      id = g.testField and 'field_leave' or (settings and 'quit' or 'menu'),
      label = g.testField and g.testField.returnLabel or (settings and 'QUIT GAME' or 'MAIN MENU'),
      x = 648,
      y = 570,
      w = 252,
      h = 42,
    },
  }
end
local ending = function()
  return {
    { id = 'restart', label = 'AGAIN  [ ENTER ]', x = 440, y = 530, w = 400, h = 50 },
    { id = 'menu', label = 'MAIN MENU  [ ESC ]', x = 440, y = 596, w = 400, h = 40 },
  }
end
Views:get('menu').controls = function()
  return {
    { id = 'start', label = 'ENTER LIMBO   [ ENTER ]', x = 72, y = 410, w = 400, h = 56 },
    { id = 'help', label = 'HELP  [ F1 ]', x = 72, y = 482, w = 194, h = 46 },
    { id = 'settings', label = 'SETTINGS', x = 270, y = 482, w = 194, h = 46 },
    { id = 'quit', label = 'QUIT', x = 72, y = 546, w = 194, h = 42 },
    { id = 'field_skirmish', label = 'QUICK SKIRMISH', x = 612, y = 444, w = 526, h = 44 },
    { id = 'field_start', label = 'PROVING GROUND [ F2 ]', x = 612, y = 498, w = 526, h = 44 },
  }
end
Views:get('paused').controls = pageControls
Views:get('settings').controls = pageControls
Views:get('dead').controls = ending
Views:get('won').controls = ending
-- The providers of buttons, in order; each returns a list or nil.
Views.providers = {
  function(g)
    if g.testField and g.state == 'field_archive' and not g.help and not g.map then
      return require('src.ui.occult_archive').controls(g)
    end
  end,
  function(g)
    return require('src.ui.test_field').controls(g)
  end,
  function(g)
    return require('src.ui.descent').controls(g)
  end,
  function(g)
    if g.help then
      return {
        { id = 'help_back', label = 'BACK  [ F1 / ESC ]', x = 460, y = 619, w = 360, h = 42 },
      }
    end
  end,
  function(g)
    if g.map then
      return { { id = 'map', label = 'BACK TO COMBAT  [ TAB ]', x = 810, y = 610, w = 290, h = 42 } }
    end
  end,
  function(g, s)
    local view = Views:find(g.state)
    return view and view.controls and view.controls(g, s)
  end,
}
function Views.controls(g, s)
  for _, provider in ipairs(Views.providers) do
    local list = provider(g, s)
    if list then
      return list
    end
  end
  return {}
end
return Views
