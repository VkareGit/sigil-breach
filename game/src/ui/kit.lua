-- Drawing helpers shared by every screen (0.24 F7): text in the painted
-- fonts, panels, keys, bars, in the interface palette. Kit.ui is the
-- interface (ui/interface.lua) whose fonts they use.
local Skin = require('src.ui.skin')
local Palette = require('src.ui.palette')
local lg = love.graphics
local Kit = {}
local ivory, gold = Skin.colors.ivory, Skin.colors.gold
function Kit.c(t, a)
  lg.setColor(t[1], t[2], t[3], a or 1)
end
function Kit.text(t, x, y, size, col)
  Skin.text(t, x, y, Kit.ui.fonts[size or 18], col or ivory)
end
function Kit.right(t, x, y, size, col)
  Kit.text(t, x - Kit.ui.fonts[size or 18]:getWidth(t), y, size, col)
end
function Kit.center(t, y, size, col)
  local font = Kit.ui.fonts[size or 18]
  Skin.text(t, (1280 - font:getWidth(t)) / 2, y, font, col or ivory)
end
function Kit.rect(x, y, w, h, col, a)
  Kit.c(col, a)
  lg.rectangle('fill', x, y, w, h)
end
function Kit.line(x, y, w, col)
  Kit.rect(x, y, w, 2, col or gold)
end
function Kit.panel(x, y, w, h)
  Skin.panel(x, y, w, h, 1, 12)
end
function Kit.key(t, x, y, w)
  w = w or math.max(30, Kit.ui.fonts[14]:getWidth(t) + 22)
  local size = 14
  while
    size > 11
    and (
      Skin.inkBounds(Kit.ui.fonts[size], t).w > w - 22
      or Skin.inkBounds(Kit.ui.fonts[size], t).h > 20
    )
  do
    size = size - 1
  end
  Skin.panel(x, y, w, 40, 2, 10)
  Skin.zone('key ' .. t, x + 10, y + 10, w - 20, 20)
  Skin.boxText(t, x + 11, y + 10, w - 22, 20, Kit.ui.fonts[size], ivory)
  Skin.endZone()
end
function Kit.bar(x, y, w, value, col)
  Kit.rect(x, y, w, 5, Palette.track)
  Kit.rect(x, y, w * math.max(0, math.min(1, value)), 5, col)
end
return Kit
