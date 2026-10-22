-- The main menu screen.
-- (0.24 F7: one file per screen; ui/views.lua dispatches.)
local Kit = require('src.ui.kit')
local Skin = require('src.ui.skin')
local Palette = require('src.ui.palette')
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
  text('TRIAL BY FIRE', 72, 292, 24, gold)
  text('Guns, demons and heavy combat.', 72, 329, 18, ivory)
  Skin.icon('ring', 402, 145, 94)
  text('I  /  LIMBO', 76, 78, 20, gold)
  text('Limbo remains the proving field.', 72, 360, 18, ivory)
  Skin.endZone()
  text(require('src.app.release').menuLabel, 65, 659, 16, muted)
  right('F11  fullscreen', 1248, 673, 16, muted)
  Skin.panel(580, 324, 590, 284, 5, 12)
  Skin.zone('test field menu', 612, 358, 526, 226)
  Skin.boxText('THE PROVING GROUND', 612, 360, 526, 35, U.fonts[28], gold)
  local stations = {
    'Shooting range: distance, falloff, spread.',
    'Physics: wall slams, domino, trips.',
    'Wave trial: packs, portals, tiers 1 to 5.',
    'Gallery: every demon, weapon and texture.',
  }
  for i, line in ipairs(stations) do
    Skin.boxText(line, 612, 400 + (i - 1) * 34, 526, 25, U.fonts[18], ivory)
  end
  Skin.boxText(
    'The expedition waits until the combat is forged.',
    612,
    560,
    526,
    24,
    U.fonts[16],
    muted
  )
  Skin.endZone()
  if g.saveRecovered then
    Skin.panel(566, 614, 650, 42, 2, 8)
    Skin.zone('save recovery field', 582, 622, 618, 26)
    Skin.boxText(
      g.availableSave and 'Recovered the previous valid save.'
        or 'Cannot read the save. The files are kept.',
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
