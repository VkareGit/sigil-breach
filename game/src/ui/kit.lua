-- Drawing helpers shared by every screen (0.24 F7): text in the painted
-- fonts, panels, keys, bars, in the interface palette. Kit.ui is the
-- interface (ui/interface.lua) whose fonts they use.
local Skin = require('src.ui.skin')
local Palette = require('src.ui.palette')
local lg = love.graphics
local Kit = {}
local ivory, gold = Skin.colors.ivory, Skin.colors.gold
local K = require('src.content.ui_look').kit
function Kit.c(t, a)
  lg.setColor(t[1], t[2], t[3], a or 1)
end
function Kit.text(t, x, y, size, col)
  Skin.text(t, x, y, Kit.ui.fonts[size or K.font], col or ivory)
end
function Kit.right(t, x, y, size, col)
  Kit.text(t, x - Kit.ui.fonts[size or K.font]:getWidth(t), y, size, col)
end
function Kit.center(t, y, size, col)
  local font = Kit.ui.fonts[size or K.font]
  Skin.text(t, (K.width - font:getWidth(t)) / 2, y, font, col or ivory)
end
function Kit.rect(x, y, w, h, col, a)
  Kit.c(col, a)
  lg.rectangle('fill', x, y, w, h)
end
function Kit.line(x, y, w, col)
  Kit.rect(x, y, w, 2, col or gold)
end
function Kit.panel(x, y, w, h)
  Skin.panel(x, y, w, h, 1, K.panelCorner)
end
function Kit.key(t, x, y, w)
  local key = K.key
  w = w or math.max(key.least, Kit.ui.fonts[key.font]:getWidth(t) + key.pad)
  local size = key.font
  while
    size > key.smallest
    and (
      Skin.inkBounds(Kit.ui.fonts[size], t).w > w - key.pad
      or Skin.inkBounds(Kit.ui.fonts[size], t).h > key.ink
    )
  do
    size = size - 1
  end
  local inset = key.inset
  Skin.panel(x, y, w, key.height, 2, key.corner)
  Skin.zone('key ' .. t, x + inset, y + inset, w - 2 * inset, key.ink)
  Skin.boxText(t, x + inset + 1, y + inset, w - key.pad, key.ink, Kit.ui.fonts[size], ivory)
  Skin.endZone()
end
function Kit.bar(x, y, w, value, col)
  Kit.rect(x, y, w, K.bar, Palette.track)
  Kit.rect(x, y, w * math.max(0, math.min(1, value)), K.bar, col)
end
return Kit
