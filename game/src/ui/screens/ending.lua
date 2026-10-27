-- The ending screen: a broken or a lost trial.
-- (0.24 F7: one file per screen; ui/views.lua dispatches.)
local Stats = require('src.session.stats')
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
local Queries = require('src.run.queries')
local Text = require('src.content.text')
local S = {}
function S.draw(g, s, U)
  if Queries.field(g) then
    return FieldUI.ending(g, U)
  end
  if Queries.run(g) then
    return D.ending(g)
  end
  local won = g.state == 'won'
  local result = Queries.result(g) or {}
  rect(0, 0, 1280, 720, Palette.veil, 0.94)
  center(Text.get(won and 'classic_won_title' or 'classic_lost_title'), 140, 48, ivory)
  center(Text.get(won and 'classic_won_line' or 'classic_lost_line'), 208, 22, muted)
  center(
    won and Text.get('classic_rank', { rank = result.rank or 'A' }) or Text.get('classic_ended'),
    280,
    48,
    gold
  )
  center(
    Text.get('classic_stats', {
      minutes = string.format('%02d', math.floor(g.elapsed / 60)),
      seconds = string.format('%02d', math.floor(g.elapsed % 60)),
      kills = string.format('%d', Stats.total(g, 'kills')),
      seals = string.format('%d', result.seals or 0),
    }),
    365,
    24,
    ivory
  )
  center(
    Text.get('classic_score', {
      score = Stats.total(g, 'score'),
      damage = math.floor(Stats.total(g, 'damageTaken')),
    }),
    407,
    20,
    muted
  )
  if won then
    center(
      Text.get('classic_best', { score = result.bestScore or Stats.total(g, 'score') }),
      450,
      24,
      gold
    )
    center(Text.get('classic_ranks'), 488, 16, muted)
  else
    center(Text.get('classic_hint'), 460, 20, gold)
  end
end
return S
