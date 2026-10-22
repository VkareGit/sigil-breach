-- The pause and settings screen.
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
  Skin.auditLayer('settings')
  rect(0, 0, 1280, 720, Palette.veil, 0.88)
  panel(350, 62, 580, 586)
  Skin.inscription(g.state == 'settings' and 'settings' or 'interrupted', 430, 100, 420, 40)
  Skin.zone('settings writing field', 382, 100, 516, 514)
  if g.run and g.state == 'paused' then
    center(
      (g.run.phase == 'wave' or g.run.phase == 'countdown') and 'Save: start of the current wave.'
        or 'Save: last preparation.',
      221,
      14,
      muted
    )
  end
  text('Mouse sensitivity', 384, 250, 22, ivory)
  text(string.format('%.1f', s.sensitivity), 704, 250, 22, gold)
  text('Field of view', 384, 298, 22, ivory)
  text(tostring(s.fov or 100) .. '°', 704, 298, 22, gold)
  text('Music and ambience', 384, 346, 22, ivory)
  text(math.floor((s.music or 0.65) * 100 + 0.5) .. '%', 704, 346, 22, gold)
  -- This label owns the left column; the later button's plaster starts at 670.
  local motionLabel, size = 'Weapon motion and FOV', 22
  while size > 16 and Skin.inkBounds(U.fonts[size], motionLabel).w > 272 do
    size = size - 2
  end
  Skin.zone('motion setting label', 384, 399, 272, 32)
  Skin.boxText(motionLabel, 384, 399, 272, 32, U.fonts[size], ivory)
  Skin.endZone()
  text('Hints', 384, 448, 22, ivory)
  Skin.endZone()
  center('Mouse or arrows + ENTER. F11: fullscreen.', 667, 16, muted)
end
return S
