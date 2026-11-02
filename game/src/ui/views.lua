-- What each screen draws and which buttons it offers (0.24 F7). The screen
-- is the session's state (app/screens.lua holds its keys); a new screen is a
-- new entry here and its file in ui/screens/, ui/interface.lua does not change.
--   draw(g, s, U)       paint the screen (U: the interface: fonts, focus)
--   controls(g, s)      its buttons, or nil
-- Buttons come from a chain of providers, first answer wins (Chain of
-- Responsibility): the proving ground's archive and catalogue, the
-- chapel's own screens, the help and map overlays, then the screen.
local Chapel = require('src.ui.chapel')
local Hud = require('src.ui.hud')
local OccultArchive = require('src.ui.occult_archive')
local Help = require('src.ui.screens.help')
local TestField = require('src.ui.test_field')
local Registry = require('src.core.registry')
local Views = Registry:new('views')
local Text = require('src.content.text')
local Queries = require('src.session.queries')
local Settings = require('src.content.settings')
-- A screen file's draw (full module names: tools/check follows them).
local function screen(module)
  return function(g, s, U)
    return require(module).draw(g, s, U)
  end
end
local function hud(g, s, U)
  return Hud.draw(g, s, U, Chapel)
end
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
Views:register('shop', {
  draw = function(g)
    Chapel.shop(g)
  end,
})
Views:register('confirm_new', {
  draw = function(g)
    Chapel.confirm(g)
  end,
})
Views:register('field_archive', {
  draw = function(g, _, U)
    OccultArchive.draw(g, U)
  end,
})
Views:register('field_catalog', {
  draw = function(g, _, U)
    TestField.draw(g, U)
  end,
})
-- Overlays over any screen.
Views.overlays = {
  map = function(g)
    return Chapel.map(g)
  end,
  help = screen('src.ui.screens.help'),
}
-- The view of a session (an unknown state shows the play screen).
function Views.of(g)
  return Views:find(g.state) or Views:get('playing')
end
-- Settings and pause share one page; settings swaps the last row.
local function pageControls(g, s)
  local settings = g.state == 'settings'
  local row = Settings.pause.scale
  return {
    {
      id = 'resume',
      label = Text.get(settings and 'page_back_menu' or 'page_back_combat'),
      x = 380,
      y = 164,
      w = 520,
      h = 46,
    },
    { id = 'sens_down', label = Text.get('page_minus'), x = 784, y = 249, w = 48, h = 34 },
    { id = 'sens_up', label = Text.get('page_plus'), x = 852, y = 249, w = 48, h = 34 },
    { id = 'fov_down', label = Text.get('page_minus'), x = 784, y = 297, w = 48, h = 34 },
    { id = 'fov_up', label = Text.get('page_plus'), x = 852, y = 297, w = 48, h = 34 },
    { id = 'music_down', label = Text.get('page_minus'), x = 784, y = 345, w = 48, h = 34 },
    { id = 'music_up', label = Text.get('page_plus'), x = 852, y = 345, w = 48, h = 34 },
    {
      id = 'motion',
      label = Text.get(s.motion == false and 'page_motion_off' or 'page_motion_on'),
      x = 670,
      y = 397,
      w = 230,
      h = 42,
    },
    {
      id = 'hints',
      label = Text.get(s.hints == false and 'page_off' or 'page_on'),
      x = 670,
      y = 445,
      w = 230,
      h = 42,
    },
    {
      id = 'render_scale',
      label = Text.get('setting_percent', {
        percent = (s.renderScale or Settings.renderScale.default) * Settings.renderScale.percent,
      }),
      x = row.x,
      y = row.y,
      w = row.w,
      h = row.h,
    },
    {
      id = 'help',
      label = Text.get('page_help'),
      x = 380,
      y = Settings.pause.helpY,
      w = 252,
      h = 42,
    },
    {
      id = 'mute',
      label = Text.get(s.muted and 'page_unmute' or 'page_mute'),
      x = 648,
      y = Settings.pause.helpY,
      w = 252,
      h = 42,
    },
    {
      id = settings and 'fullscreen' or 'restart',
      label = Text.get(settings and 'page_fullscreen' or 'page_restart'),
      x = 380,
      y = Settings.pause.footerY,
      w = 252,
      h = 42,
    },
    {
      id = Queries.field(g) and 'field_leave' or (settings and 'quit' or 'menu'),
      label = Text.get(g.view.fieldReturnLabel or (settings and 'quit_game' or 'return_menu')),
      x = 648,
      y = Settings.pause.footerY,
      w = 252,
      h = 42,
    },
  }
end
Views:get('paused').controls = pageControls
Views:get('settings').controls = pageControls
-- The providers of buttons, in order; each returns a list or nil.
Views.providers = {
  function(g)
    if Queries.field(g) and g.state == 'field_archive' and not g.help and not g.map then
      return OccultArchive.controls(g)
    end
  end,
  function(g)
    return TestField.controls(g)
  end,
  function(g)
    return Chapel.controls(g)
  end,
  function(g)
    if g.help then
      return Help.controls(g)
    end
  end,
  function(g)
    if g.map then
      return { { id = 'map', label = Text.get('map_back'), x = 810, y = 610, w = 290, h = 42 } }
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
