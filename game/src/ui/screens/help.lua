-- The help panel (F1): controls and the bestiary.
-- (0.24 F7: one file per screen; ui/views.lua dispatches.)
local Kit = require('src.ui.kit')
local Skin = require('src.ui.skin')
local Palette = require('src.ui.palette')
local lg = love.graphics
local c, text, right, center = Kit.c, Kit.text, Kit.right, Kit.center
local rect, line, panel, key, bar = Kit.rect, Kit.line, Kit.panel, Kit.key, Kit.bar
local ivory, muted, gold = Skin.colors.ivory, Skin.colors.muted, Skin.colors.gold
local red, blue, green = Skin.colors.red, Skin.colors.blue, Palette.green
local Goetia = require('src.ui.goetic_sigils')
local S = {}
function S.draw(g, s, U)
  Skin.auditLayer('bestiary')
  rect(0, 0, 1280, 720, Palette.veil, 0.96)
  Skin.panel(70, 42, 1140, 640, 6, 14)
  for _, seal in ipairs({ { 'asmoday', 110, 326 }, { 'buer', 110, 426 }, { 'stolas', 1134, 370 } }) do
    Skin.zone('Goetia parchment margin', seal[2] - 4, seal[3] - 4, 44, 44)
    Goetia.draw(seal[1], seal[2], seal[3], 36, Palette.sepia, 0.55)
    Skin.imageBounds('Goetia ' .. seal[1], seal[2], seal[3], 36, 36)
    Skin.endZone()
  end
  Skin.zone('parchment writing field', 158, 106, 964, 492)
  Skin.inscription('limbo', 440, 112, 400, 50)
  center(
    g
        and g.testField
        and 'PROVING GROUND / [F2] Targets, poses, guns and seals. Never saves the run.'
      or (
        g
          and g.run
          and '4 waves + guardian. [E] Ember merchant. [ENTER] Ready. Reclaim souls from the echo.'
        or 'Break three seals [E], defeat the defenders and the guardian. Return to the gate.'
      ),
    170,
    18,
    gold
  )
  local keys = {
    { 'WASD', 'Move' },
    { 'MOUSE', 'Aim' },
    { 'LMB', 'Fire' },
    { '1 / 2', 'Weapon' },
    { 'SHIFT', 'Dodge x2' },
    { 'SPACE', 'Jump' },
    { 'Q', 'Charge' },
    { 'CTRL', 'Slide' },
  }
  for i, k in ipairs(keys) do
    local x = 170 + ((i - 1) % 4) * 240
    local y = 200 + math.floor((i - 1) / 4) * 44
    key(k[1], x, y, 88)
    text(k[2], x + 100, y + 8, 18, ivory)
  end
  line(170, 294, 940, gold)
  local cards = {
    {
      kind = 'imp',
      name = 'EMBER THRALL',
      desc = 'Flanks and lunges.',
      tip = 'Sidestep its swing.',
      color = red,
    },
    {
      kind = 'stolas',
      name = 'STAR ACOLYTE',
      desc = 'Keeps away, shoots.',
      tip = 'Heavy shots interrupt.',
      color = blue,
    },
    {
      kind = 'buer',
      name = 'PLAGUE GARDENER',
      desc = 'Leaves venom pools.',
      tip = 'Leave the marked ring.',
      color = green,
    },
    {
      kind = 'armored',
      name = 'IRON THRALL',
      desc = 'Armour protects it.',
      tip = 'Pierce or the Judge.',
      color = blue,
    },
  }
  for i, v in ipairs(cards) do
    local x = 160 + (i - 1) * 240
    U.face(v.kind, x + 54, 312, 116, 116)
    local function caption(value, y, initial, tint)
      local size = initial
      for _, candidate in ipairs({ 18, 16, 14, 13, 12, 11 }) do
        if candidate <= initial and Skin.inkBounds(U.fonts[candidate], value).w <= 208 then
          size = candidate
          break
        end
      end
      Skin.zone('bestiary card ' .. v.kind, x + 6, y, 208, 26)
      Skin.boxText(value, x + 6, y, 208, 26, U.fonts[size], tint)
      Skin.endZone()
    end
    caption(v.name, 435, 18, v.color)
    caption(v.desc, 467, 14, ivory)
    caption(v.tip, 491, 14, muted)
  end
  center('R: reload. TAB: map. Judge: six rounds.', 528, 18, ivory)
  center('Q: powder charge. 1 s fuse. The blast hurts you too.', 554, 16, gold)
  center('Ward: remaining pool. Absorbs 55% of damage until spent.', 580, 14, muted)
  Skin.endZone()
end
return S
