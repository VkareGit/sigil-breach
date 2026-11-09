-- The main menu screen.
-- (0.24 F7: one file per screen; ui/views.lua dispatches.)
local Release = require('src.app.release')
local Catalog = require('src.run.field.catalog')
local Kit = require('src.ui.kit')
local Skin = require('src.ui.skin')
local Palette = require('src.ui.palette')
local Text = require('src.content.text')
local MenuPage = require('src.content.screens.menu')
local FrameSize = require('src.content.ui_layout')
local lg = love.graphics
local c, text, right, center = Kit.c, Kit.text, Kit.right, Kit.center
local rect, line, panel, key, bar = Kit.rect, Kit.line, Kit.panel, Kit.key, Kit.bar
local ivory, muted, gold = Skin.colors.ivory, Skin.colors.muted, Skin.colors.gold
local red, blue, green = Skin.colors.red, Skin.colors.blue, Palette.green
local S = {}
function S.draw(g, s, U)
  local M = MenuPage
  local C = M.curtain
  for i = 0, C.strips - 1 do
    rect(i * C.width, 0, C.width, FrameSize.height, Palette.curtain, C.alpha * (1 - i / C.thins))
  end
  local function box(name)
    local b = M[name]
    return b[1], b[2], b[3], b[4]
  end
  Skin.panel(M.page[1], M.page[2], M.page[3], M.page[4], 5, M.page.corner)
  Skin.zone('menu writing field', box('writing'))
  Skin.inscription('sigil', box('sigil'))
  Skin.inscription('breach', box('breach'))
  line(M.rule[1], M.rule[2], M.rule[3], gold)
  text(Text.get('menu_trial'), M.trial[1], M.trial[2], M.trial.font, gold)
  text(Text.get('menu_tagline'), M.tagline[1], M.tagline[2], M.tagline.font, ivory)
  Skin.icon('ring', M.ring[1], M.ring[2], M.ring.size)
  text(Text.get('menu_chapel'), M.chapel[1], M.chapel[2], M.chapel.font, gold)
  text(Text.get('menu_way'), M.way[1], M.way[2], M.way.font, ivory)
  Skin.endZone()
  local version = Text.get(Release.menuLabel, { version = Release.version })
  text(version, M.version[1], M.version[2], M.version.font, muted)
  right(Text.get('menu_fullscreen'), M.fullscreen[1], M.fullscreen[2], M.fullscreen.font, muted)
  Skin.panel(M.proving[1], M.proving[2], M.proving[3], M.proving[4], 5, M.proving.corner)
  Skin.zone('test field menu', box('provingField'))
  local T = M.provingTitle
  Skin.boxText(Text.get('menu_proving'), T[1], T[2], T[3], T[4], U.fonts[T.font], gold)
  local stations = {}
  local field = Release.sessionOptions.field
  for _, station in ipairs(Catalog.stationsFor(field)) do
    if station.menuText then
      stations[#stations + 1] = station.menuText
    end
  end
  stations[#stations + 1] = 'menu_station_gallery'
  local R = M.station
  for i, line in ipairs(stations) do
    Skin.boxText(Text.get(line), R[1], R[2] + (i - 1) * R.step, R[3], R[4], U.fonts[R.font], ivory)
  end
  local W = M.waits
  Skin.boxText(Text.get('menu_waits'), W[1], W[2], W[3], W[4], U.fonts[W.font], muted)
  Skin.endZone()
  if g.saveRecovered then
    local P, F, X = M.recovery, M.recoveryField, M.recoveryText
    Skin.panel(P[1], P[2], P[3], P[4], 2, P.corner)
    Skin.zone('save recovery field', F[1], F[2], F[3], F[4])
    Skin.boxText(
      Text.get(g.availableSave and 'menu_save_recovered' or 'menu_save_unreadable'),
      X[1],
      X[2],
      X[3],
      X[4],
      U.fonts[X.font],
      red
    )
    Skin.endZone()
  end
end
return S
