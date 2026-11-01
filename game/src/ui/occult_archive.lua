local A = {}
local Skin = require('src.ui.skin')
local Goetia = require('src.ui.goetic_sigils')
local Plates = require('src.ui.occult_plates')
local Palette = require('src.ui.palette')
local Queries = require('src.session.queries')
local Text = require('src.content.text')
A.entries = require('src.content.occult_catalog').entries
function A.controls(g)
  local buttons = {}
  for i, entry in ipairs(A.entries) do
    buttons[#buttons + 1] = {
      id = 'archive_' .. i,
      label = Text.get(entry.name),
      x = 126,
      y = 177 + (i - 1) * 58,
      w = 340,
      h = 48,
    }
  end
  buttons[#buttons + 1] =
    { id = 'field_open', label = Text.get('archive_back'), x = 445, y = 612, w = 390, h = 44 }
  return buttons
end
function A.draw(g, U)
  Skin.auditLayer('occult archive')
  local C = Skin.colors
  local index = math.max(1, math.min(#A.entries, Queries.field(g).archiveSelection or 1))
  local entry = A.entries[index]
  love.graphics.setColor(0, 0, 0, 0.90)
  love.graphics.rectangle('fill', 0, 0, 1280, 720)
  Skin.panel(80, 45, 1120, 630, 6, 20)
  local function label(t, x, y, w, h, size, col, center)
    Skin.zone('archive inscription', x, y, w, h)
    Skin.boxText(t, x, y, w, h, U.fonts[size], col or C.ivory, center)
    Skin.endZone()
  end
  label(Text.get('archive_title'), 160, 92, 960, 36, 28, C.gold, true)
  label(Text.get('archive_subtitle'), 160, 138, 960, 25, 16, C.ivory, true)
  label(Text.get(entry.name), 518, 184, 610, 28, 20, C.gold, true)
  local x, y, w, h
  if Plates.entries[entry.id] then
    x, y, w, h = Plates.draw(entry.id, 668, 226, 310, 280, Palette.sepia)
  else
    Goetia.draw(entry.id, 683, 226, 280, Palette.sepia, 1)
    x, y, w, h = 683, 226, 280, 280
  end
  Skin.zone('historical figure', 620, 218, 400, 294)
  Skin.imageBounds('archive ' .. entry.id, x, y, w, h)
  Skin.endZone()
  label(Text.get(entry.source), 505, 522, 638, 24, 16, C.ivory, true)
  label(Text.get(entry.detail), 505, 551, 638, 23, 16, C.muted, true)
  label(Text.get('archive_hint'), 126, 578, 1026, 24, 16, C.muted, true)
end
return A
