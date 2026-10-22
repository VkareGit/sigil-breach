-- The ending screen: a broken or a lost trial.
-- (0.24 F7: one file per screen; ui/views.lua dispatches.)
local Kit = require('src.ui.kit')
local Skin = require('src.ui.skin')
local Palette = require('src.ui.palette')
local lg = love.graphics
local c, text, right, center = Kit.c, Kit.text, Kit.right, Kit.center
local rect, line, panel, key, bar = Kit.rect, Kit.line, Kit.panel, Kit.key, Kit.bar
local ivory, muted, gold = Skin.colors.ivory, Skin.colors.muted, Skin.colors.gold
local red, blue, green = Skin.colors.red, Skin.colors.blue, Palette.green
local D = require('src.ui.descent')
local FieldUI = require('src.ui.test_field')
local S = {}
function S.draw(g, s, U)
  if g.testField then
    return FieldUI.ending(g, U)
  end
  if g.run then
    return D.ending(g)
  end
  rect(0, 0, 1280, 720, Palette.veil, 0.94)
  center(g.state == 'won' and 'LIMBO BROKEN' or 'HELL KNOWS YOUR NAME', 140, 48, ivory)
  center(
    g.state == 'won' and 'Same arena. Another trial. Better mastery.'
      or 'Raise your gun. Descend again.',
    208,
    22,
    muted
  )
  center(g.state == 'won' and ('RANK ' .. (g.rank or 'A')) or 'TRIAL ENDED', 280, 48, gold)
  center(
    string.format(
      'TIME %02d:%02d   DEMONS %d   SEALS %d/3',
      math.floor(g.elapsed / 60),
      math.floor(g.elapsed % 60),
      g.kills,
      g.seals
    ),
    365,
    24,
    ivory
  )
  center('SCORE ' .. g.score .. '   DAMAGE TAKEN ' .. math.floor(g.damageTaken), 407, 20, muted)
  if g.state == 'won' then
    center('YOUR BEST: ' .. (g.bestScore or g.score), 450, 24, gold)
    center('S: under 3 min and 100 damage. A: under 5 min.', 488, 16, muted)
  else
    center('Hint: dodge after the swing. The shotgun interrupts common attacks.', 460, 20, gold)
  end
end
return S
