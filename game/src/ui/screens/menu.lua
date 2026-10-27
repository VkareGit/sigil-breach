-- The main menu screen.
-- (0.24 F7: one file per screen; ui/views.lua dispatches.)
local Kit = require('src.ui.kit')
local Skin = require('src.ui.skin')
local Palette = require('src.ui.palette')
local Text = require('src.content.text')
local lg = love.graphics
local c, text, right, center = Kit.c, Kit.text, Kit.right, Kit.center
local rect, line, panel, key, bar = Kit.rect, Kit.line, Kit.panel, Kit.key, Kit.bar
local ivory, muted, gold = Skin.colors.ivory, Skin.colors.muted, Skin.colors.gold
local red, blue, green = Skin.colors.red, Skin.colors.blue, Palette.green
local S = {}
function S.draw(g, s, U)
  -- Abutting strips (no 1 px overlap): overlapping translucent strips drew dark lines every 20 px.
  for i = 0, 63 do
    rect(i * 20, 0, 20, 720, Palette.curtain, 0.98 * (1 - i / 70))
  end
  Skin.panel(36, 38, 500, 600, 5, 12)
  Skin.zone('menu writing field', 70, 74, 434, 532)
  Skin.inscription('sigil', 72, 105, 300, 104)
  Skin.inscription('breach', 72, 216, 240, 44)
  line(72, 274, 80, gold)
  text(Text.get('menu_trial'), 72, 292, 24, gold)
  text(Text.get('menu_tagline'), 72, 329, 18, ivory)
  Skin.icon('ring', 402, 145, 94)
  text(Text.get('menu_circle'), 76, 78, 20, gold)
  text(Text.get('menu_limbo'), 72, 360, 18, ivory)
  Skin.endZone()
  text(Text.get(require('src.app.release').menuLabel), 65, 659, 16, muted)
  right(Text.get('menu_fullscreen'), 1248, 673, 16, muted)
  Skin.panel(580, 324, 590, 284, 5, 12)
  Skin.zone('test field menu', 612, 358, 526, 226)
  Skin.boxText(Text.get('menu_proving'), 612, 360, 526, 35, U.fonts[28], gold)
  local stations = {}
  local field = require('src.app.release').sessionOptions.field
  for _, station in ipairs(require('src.run.field.catalog').stationsFor(field)) do
    if station.menuText then
      stations[#stations + 1] = station.menuText
    end
  end
  stations[#stations + 1] = 'menu_station_gallery'
  for i, line in ipairs(stations) do
    Skin.boxText(Text.get(line), 612, 400 + (i - 1) * 34, 526, 25, U.fonts[18], ivory)
  end
  Skin.boxText(Text.get('menu_waits'), 612, 560, 526, 24, U.fonts[16], muted)
  Skin.endZone()
  if g.saveRecovered then
    Skin.panel(566, 614, 650, 42, 2, 8)
    Skin.zone('save recovery field', 582, 622, 618, 26)
    Skin.boxText(
      Text.get(g.availableSave and 'menu_save_recovered' or 'menu_save_unreadable'),
      584,
      622,
      612,
      26,
      U.fonts[16],
      red
    )
    Skin.endZone()
  end
end
return S
