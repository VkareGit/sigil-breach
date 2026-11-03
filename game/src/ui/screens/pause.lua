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
local Queries = require('src.session.queries')
local Text = require('src.content.text')
local Settings = require('src.content.settings')
local S = {}
function S.draw(g, s, U)
  Skin.auditLayer('settings')
  rect(0, 0, 1280, 720, Palette.veil, 0.88)
  panel(350, 62, 580, 586)
  Skin.inscription(g.state == 'settings' and 'settings' or 'interrupted', 430, 100, 420, 40)
  Skin.zone('settings writing field', 382, 100, 516, Settings.pause.fieldHeight)
  local run = Queries.run(g)
  if run and run.rest and g.state == 'paused' then
    center(Text.get('pilgrim_saved'), 221, 14, muted)
  end
  local pause = Settings.pause
  local function rowY(i)
    return pause.rowY + (i - 1) * pause.rowStep + 1
  end
  text(Text.get('setting_sensitivity'), 384, rowY(1), 22, ivory)
  text(string.format('%.1f', s.sensitivity), 704, rowY(1), 22, gold)
  text(Text.get('setting_fov'), 384, rowY(2), 22, ivory)
  text(Text.get('setting_fov_value', { degrees = tostring(s.fov or 100) }), 704, rowY(2), 22, gold)
  -- The four sound levels (0.45, owner D17), two to a row: name, percent, then its buttons.
  local levels = {
    { 'setting_master', s.master or 1, 384, 470, 3 },
    { 'setting_effects', s.effects or 1, 630, 758, 3 },
    { 'setting_music', s.music or 0.65, 384, 470, 4 },
    { 'setting_ambience', s.ambience or 0.65, 630, 758, 4 },
  }
  for _, level in ipairs(levels) do
    text(Text.get(level[1]), level[3], rowY(level[5]), 20, ivory)
    local percent = Text.get('setting_percent', { percent = math.floor(level[2] * 100 + 0.5) })
    text(percent, level[4], rowY(level[5]), 20, gold)
  end
  -- This label owns the left column; the later button's plaster starts at 670.
  local motionLabel, size = Text.get('setting_motion'), 22
  while size > 16 and Skin.inkBounds(U.fonts[size], motionLabel).w > 272 do
    size = size - 2
  end
  Skin.zone('motion setting label', 384, rowY(5) - 1, 272, 32)
  Skin.boxText(motionLabel, 384, rowY(5) - 1, 272, 32, U.fonts[size], ivory)
  Skin.endZone()
  text(Text.get('setting_hints'), 384, rowY(6), 22, ivory)
  local row = Settings.pause.scale
  text(Text.get('setting_render_scale'), row.labelX, row.labelY, row.font, ivory)
  Skin.endZone()
  center(Text.get('settings_tip'), 667, 16, muted)
end
return S
