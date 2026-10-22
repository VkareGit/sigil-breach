local A = {}
local Skin = require('src.ui.skin')
local Goetia = require('src.ui.goetic_sigils')
local Plates = require('src.ui.occult_plates')
local Palette = require('src.ui.palette')
A.entries = require('src.content.occult_catalog').entries
function A.controls(g)
  local buttons = {}
  for i, entry in ipairs(A.entries) do
    buttons[#buttons + 1] = {
      id = 'archive_' .. i,
      label = entry.name,
      x = 126,
      y = 177 + (i - 1) * 58,
      w = 340,
      h = 48,
    }
  end
  buttons[#buttons + 1] =
    { id = 'field_open', label = 'BACK TO CATALOGUE [ ESC ]', x = 445, y = 612, w = 390, h = 44 }
  return buttons
end
A.action = require('src.content.occult_catalog').action
function A.draw(g, U)
  Skin.auditLayer('occult archive')
  local C = Skin.colors
  local index = math.max(1, math.min(#A.entries, g.testField.archiveSelection or 1))
  local entry = A.entries[index]
  love.graphics.setColor(0, 0, 0, 0.90)
  love.graphics.rectangle('fill', 0, 0, 1280, 720)
  Skin.panel(80, 45, 1120, 630, 6, 20)
  local function label(t, x, y, w, h, size, col, center)
    Skin.zone('archive inscription', x, y, w, h)
    Skin.boxText(t, x, y, w, h, U.fonts[size], col or C.ivory, center)
    Skin.endZone()
  end
  label('ARCHIVE OF SIGNS', 160, 92, 960, 36, 28, C.gold, true)
  label('Source drawings for the world and interface trials.', 160, 138, 960, 25, 16, C.ivory, true)
  label(entry.name, 518, 184, 610, 28, 20, C.gold, true)
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
  label(entry.source, 505, 522, 638, 24, 16, C.ivory, true)
  label(entry.detail, 505, 551, 638, 23, 16, C.muted, true)
  label(
    'Choose a sign on the left. Original orientation and strokes.',
    126,
    578,
    1026,
    24,
    16,
    C.muted,
    true
  )
end
return A
