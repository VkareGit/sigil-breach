-- The help panel (F1): controls and the bestiary.
-- (0.24 F7: one file per screen; ui/views.lua dispatches.)
local Archetypes = require('src.content.enemies')
local Occult = require('src.content.occult_catalog')
local Kit = require('src.ui.kit')
local Skin = require('src.ui.skin')
local Palette = require('src.ui.palette')
local lg = love.graphics
local c, text, right, center = Kit.c, Kit.text, Kit.right, Kit.center
local rect, line, panel, key, bar = Kit.rect, Kit.line, Kit.panel, Kit.key, Kit.bar
local ivory, muted, gold = Skin.colors.ivory, Skin.colors.muted, Skin.colors.gold
local GoeticSigils = require('src.ui.goetic_sigils')
local Text = require('src.content.text')
local TextFit = require('src.ui.text_fit')
local Pages = require('src.ui.pages')
local Queries = require('src.session.queries')
local HelpPage = require('src.content.screens.help')
local FrameSize = require('src.content.ui_layout')
local S = {}
require('src.session.fields').declareView('ui.screens.help', { 'helpPage' })
-- Page 1 is the rules of the fight (audit L04); the bestiary follows, its pages after it.
function S.page(g)
  local cards = Archetypes.listed('bestiary')
  local detailed = false
  for _, def in ipairs(cards) do
    local card = def.catalog.bestiary
    for _, value in ipairs({
      string.upper(Text.get(def.name)),
      Text.get(card.text),
      Text.get(card.tip),
    }) do
      local D = HelpPage.detail
      detailed = detailed or Kit.ui.fonts[D.font]:getInk(value).w > D.width
    end
  end
  local wanted = g and g.view.helpPage or 1
  local first, last, inner, total =
    Pages.range(#cards, math.max(1, wanted - 1), detailed and 2 or 4)
  return cards, first, last, wanted <= 1 and 1 or inner + 1, total + 1, detailed
end
-- The rules page: the three moves the fight turns on, painted as seals (Codex,
-- assets/art/rules), and one line for each rule beside them.
-- Each rule's words are three set lines (rule_<art>_1..3): a line of a translation is its own
-- text, never a fragment cut out of a longer one.
local rules = {
  { art = 'rule_ring', name = 'rule_ring_name' },
  { art = 'rule_guard', name = 'rule_guard_name' },
  { art = 'rule_execution', name = 'rule_execution_name' },
}
local lines = { 'rules_rally', 'rules_chain', 'rules_breath', 'rules_rounds', 'rules_fire' }
local paintings = {}
local function painting(id)
  paintings[id] = paintings[id]
    or lg.newImage('assets/art/rules/' .. id .. '.png', { mipmaps = true })
  return paintings[id]
end
local function rulesPage(U)
  local R = HelpPage.rules
  local seal, zone, name, row = R.seal, R.zone, R.name, R.line
  center(Text.get('help_rules'), R.title[1], R.title.font, gold)
  for i, rule in ipairs(rules) do
    local x = R.x + (i - 1) * R.step
    local image = painting(rule.art)
    Skin.imageBounds('rule ' .. rule.art, x + seal.x, seal.y, seal.side, seal.side)
    lg.setColor(1, 1, 1)
    lg.draw(image, x + seal.x, seal.y, 0, seal.side / image:getWidth())
    Skin.zone('rule ' .. rule.art, x, zone.y, zone.w, zone.h)
    Skin.boxText(Text.get(rule.name), x, name.y, zone.w, name.h, U.fonts[name.font], gold, true)
    for index = 1, 3 do
      local part = Text.get(rule.art .. '_' .. index)
      local size = Skin.inkBounds(U.fonts[row.font], part).w <= row.wide and row.font or row.small
      Skin.boxText(part, x, row.y + index * row.step, zone.w, row.step, U.fonts[size], ivory, true)
    end
    Skin.endZone()
  end
  local B = R.beneath
  for i, key in ipairs(lines) do
    center(Text.get(key), B.y + (i - 1) * B.step, B.font, i == 1 and gold or ivory)
  end
end
function S.turn(g, delta)
  local _, _, _, page, total = S.page(g)
  g.view.helpPage = math.max(1, math.min(total, page + delta))
end
function S.reset(g)
  g.view.helpPage = 1
end
function S.controls(g)
  local _, _, _, _, total = S.page(g)
  local function button(id, label, b)
    return { id = id, label = Text.get(label), x = b.x, y = b.y, w = b.w, h = b.h }
  end
  local controls = { button('help_back', 'help_back', HelpPage.back) }
  if total > 1 then
    controls[#controls + 1] = button('help_prev', 'help_previous', HelpPage.previous)
    controls[#controls + 1] = button('help_next', 'help_next', HelpPage.next)
  end
  return controls
end
function S.draw(g, s, U)
  Skin.auditLayer('bestiary')
  local H = HelpPage
  rect(0, 0, FrameSize.width, FrameSize.height, Palette.veil, H.veil)
  Skin.panel(H.page[1], H.page[2], H.page[3], H.page[4], 6, H.page.corner)
  local M = H.margin
  for _, seal in ipairs(Occult.margins) do
    local side, pad = M.side, M.pad
    Skin.zone(
      'Goetia parchment margin',
      seal[2] - pad,
      seal[3] - pad,
      side + 2 * pad,
      side + 2 * pad
    )
    GoeticSigils.draw(seal[1], seal[2], seal[3], side, Palette.sepia, M.alpha)
    Skin.imageBounds('Goetia ' .. seal[1], seal[2], seal[3], side, side)
    Skin.endZone()
  end
  local W, T = H.writing, H.heading
  Skin.zone('parchment writing field', W[1], W[2], W[3], W[4])
  local field = g and Queries.field(g)
  Skin.boxText(
    Text.get(field and 'menu_proving' or 'menu_chapel'),
    T[1],
    T[2],
    T[3],
    T[4],
    U.fonts[T.font],
    gold
  )
  local listed, first, last, page, total, detailed = S.page(g)
  if page == 1 then
    rulesPage(U)
    local count = Text.get('page_count', { page = page, pages = total })
    center(count, H.pageCount[1], H.pageCount.font, muted)
    Skin.endZone()
    return
  end
  center(Text.get(field and 'help_field' or 'help_pilgrim'), H.title[1], H.title.font, gold)
  local keys = {
    { 'key_move', 'help_move' },
    { 'key_aim', 'help_aim' },
    { 'key_fire', 'help_fire' },
    { 'key_weapon', 'help_weapon' },
    { 'key_dodge', 'help_dodge' },
    { 'key_jump', 'help_jump' },
    { 'key_charge', 'help_charge_key' },
    { 'key_slide', 'help_slide' },
  }
  local K = H.keys
  for i, k in ipairs(keys) do
    local x = K.x + ((i - 1) % 4) * K.column
    local y = K.y + math.floor((i - 1) / 4) * K.row
    key(Text.get(k[1]), x, y, K.width)
    text(Text.get(k[2]), x + K.words.x, y + K.words.y, K.words.font, ivory)
  end
  line(H.rule[1], H.rule[2], H.rule[3], gold)
  -- One card per creature whose definition has one (catalog.bestiary), in
  -- its order; the text and the title colour are the creature's data.
  local cards = {}
  for index = first, last do
    local def = listed[index]
    local card = def.catalog.bestiary
    cards[#cards + 1] = {
      kind = def.id,
      artKind = def.appearance.atlas or def.kind or def.id,
      name = string.upper(Text.get(def.name)),
      desc = Text.get(card.text),
      tip = Text.get(card.tip),
      color = assert(Palette[card.color], 'unknown palette colour ' .. card.color),
    }
  end
  local D = H.card
  local look = detailed and 'detailed' or 'plain'
  local face = D.face[look]
  for i, v in ipairs(cards) do
    local x = D.x + (i - 1) * D.step[look]
    local width = D.width[look]
    U.face(v.artKind, x + face.x, D.face.y, face.side, face.side)
    local function caption(value, y, initial, tint, wrap, rowStep)
      local size = D.smallest
      rowStep = rowStep or D.row
      local height = wrap and rowStep * 2 or D.height
      if wrap then
        size = initial
        value = TextFit.wrap(U.fonts[size], value, width, 2)
      else
        for _, candidate in ipairs(D.fonts) do
          if candidate <= initial and Skin.inkBounds(U.fonts[candidate], value).w <= width then
            size = candidate
            break
          end
        end
        value = TextFit.ellipsis(U.fonts[size], value, width)
      end
      local left = x + D.inset
      Skin.zone('bestiary card ' .. v.kind, left, y, width, height)
      if wrap then
        local row = 0
        for line in value:gmatch('[^\n]+') do
          Skin.boxText(line, left, y + row * rowStep, width, rowStep, U.fonts[size], tint)
          row = row + 1
        end
      else
        Skin.boxText(value, left, y, width, height, U.fonts[size], tint)
      end
      Skin.endZone()
    end
    local name, desc, tip = D.name[look], D.desc[look], D.tip[look]
    caption(v.name, name[1], name.font, v.color, detailed, D.name.row)
    caption(v.desc, desc[1], desc.font, ivory, detailed)
    caption(v.tip, tip[1], tip.font, muted, detailed)
  end
  if total > 1 then
    local count = Text.get('page_count', { page = page, pages = total })
    center(count, H.bestiaryCount[1], H.bestiaryCount.font, muted)
  end
  center(Text.get('help_reload'), H.reload[1], H.reload.font, ivory)
  center(Text.get('help_charge'), H.charge[1], H.charge.font, gold)
  center(Text.get('help_ward'), H.ward[1], H.ward.font, muted)
  Skin.endZone()
end
return S
