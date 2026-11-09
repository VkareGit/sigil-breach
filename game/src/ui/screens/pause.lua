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
local Layout = require('src.ui.layout')
local S = {}
function S.draw(g, s, U)
  Skin.auditLayer('settings')
  local pause = Settings.pause
  local P, T, F = pause.panel, pause.title, pause.field
  rect(0, 0, Layout.width, Layout.height, Palette.veil, pause.veil)
  panel(P[1], P[2], P[3], P[4])
  Skin.inscription(g.state == 'settings' and 'settings' or 'interrupted', T[1], T[2], T[3], T[4])
  Skin.zone('settings writing field', F.x, F.y, F.w, pause.fieldHeight)
  local run = Queries.run(g)
  if run and run.rest and g.state == 'paused' then
    center(Text.get('pilgrim_saved'), pause.savedY, pause.small, muted)
  end
  local nameX, valueX, font = pause.nameX, pause.valueX, pause.font
  local function rowY(i)
    return pause.rowY + (i - 1) * pause.rowStep + 1
  end
  text(Text.get('setting_sensitivity'), nameX, rowY(1), font, ivory)
  text(string.format('%.1f', s.sensitivity), valueX, rowY(1), font, gold)
  text(Text.get('setting_fov'), nameX, rowY(2), font, ivory)
  local degrees = tostring(s.fov or Settings.fov.default)
  text(Text.get('setting_fov_value', { degrees = degrees }), valueX, rowY(2), font, gold)
  -- The four sound levels (0.45, owner D17), two to a row: name, percent, then its buttons.
  local L = pause.levels
  local left, right, first, second = L.left, L.right, L.first, L.second
  local levels = {
    { 'setting_master', s.master or 1, left[1], left[2], first },
    { 'setting_effects', s.effects or 1, right[1], right[2], first },
    { 'setting_music', s.music or Settings.music, left[1], left[2], second },
    { 'setting_ambience', s.ambience or Settings.ambience, right[1], right[2], second },
  }
  for _, level in ipairs(levels) do
    text(Text.get(level[1]), level[3], rowY(level[5]), pause.levelFont, ivory)
    local share = math.floor(level[2] * 100 + 0.5) -- constant: a percent
    local percent = Text.get('setting_percent', { percent = share })
    text(percent, level[4], rowY(level[5]), pause.levelFont, gold)
  end
  -- This label owns the left column; the later button's plaster starts at 670.
  local M = pause.motion
  local motionLabel, size = Text.get('setting_motion'), font
  while size > M.smallest and Skin.inkBounds(U.fonts[size], motionLabel).w > M.w do
    size = size - 2
  end
  Skin.zone('motion setting label', nameX, rowY(5) - 1, M.w, M.h)
  Skin.boxText(motionLabel, nameX, rowY(5) - 1, M.w, M.h, U.fonts[size], ivory)
  Skin.endZone()
  text(Text.get('setting_hints'), nameX, rowY(6), font, ivory)
  local row = Settings.pause.scale
  text(Text.get('setting_render_scale'), row.labelX, row.labelY, row.font, ivory)
  Skin.endZone()
  center(Text.get('settings_tip'), pause.tipY, pause.tipFont, muted)
end
return S
