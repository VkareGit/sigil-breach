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
      detailed = detailed or Kit.ui.fonts[11]:getInk(value).w > 208
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
  center(Text.get('help_rules'), 170, 18, gold)
  for i, rule in ipairs(rules) do
    local x = 182 + (i - 1) * 310
    local image = painting(rule.art)
    Skin.imageBounds('rule ' .. rule.art, x + 100, 200, 96, 96)
    lg.setColor(1, 1, 1)
    lg.draw(image, x + 100, 200, 0, 96 / image:getWidth())
    Skin.zone('rule ' .. rule.art, x, 304, 296, 92)
    Skin.boxText(Text.get(rule.name), x, 304, 296, 24, U.fonts[18], gold, true)
    for row = 1, 3 do
      local part = Text.get(rule.art .. '_' .. row)
      local size = Skin.inkBounds(U.fonts[14], part).w <= 290 and 14 or 12
      Skin.boxText(part, x, 312 + row * 20, 296, 20, U.fonts[size], ivory, true)
    end
    Skin.endZone()
  end
  for i, key in ipairs(lines) do
    center(Text.get(key), 410 + (i - 1) * 30, 14, i == 1 and gold or ivory)
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
  local controls = {
    { id = 'help_back', label = Text.get('help_back'), x = 460, y = 619, w = 360, h = 42 },
  }
  if total > 1 then
    controls[#controls + 1] =
      { id = 'help_prev', label = Text.get('help_previous'), x = 170, y = 619, w = 240, h = 42 }
    controls[#controls + 1] =
      { id = 'help_next', label = Text.get('help_next'), x = 870, y = 619, w = 240, h = 42 }
  end
  return controls
end
function S.draw(g, s, U)
  Skin.auditLayer('bestiary')
  rect(0, 0, 1280, 720, Palette.veil, 0.96)
  Skin.panel(70, 42, 1140, 640, 6, 14)
  for _, seal in ipairs(Occult.margins) do
    Skin.zone('Goetia parchment margin', seal[2] - 4, seal[3] - 4, 44, 44)
    GoeticSigils.draw(seal[1], seal[2], seal[3], 36, Palette.sepia, 0.55)
    Skin.imageBounds('Goetia ' .. seal[1], seal[2], seal[3], 36, 36)
    Skin.endZone()
  end
  Skin.zone('parchment writing field', 158, 106, 964, 492)
  local field = g and Queries.field(g)
  Skin.boxText(
    Text.get(field and 'menu_proving' or 'menu_chapel'),
    440,
    112,
    400,
    50,
    U.fonts[28],
    gold
  )
  local listed, first, last, page, total, detailed = S.page(g)
  if page == 1 then
    rulesPage(U)
    center(Text.get('page_count', { page = page, pages = total }), 572, 11, muted)
    Skin.endZone()
    return
  end
  center(Text.get(field and 'help_field' or 'help_pilgrim'), 170, 18, gold)
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
  for i, k in ipairs(keys) do
    local x = 170 + ((i - 1) % 4) * 240
    local y = 200 + math.floor((i - 1) / 4) * 44
    key(Text.get(k[1]), x, y, 88)
    text(Text.get(k[2]), x + 100, y + 8, 18, ivory)
  end
  line(170, 294, 940, gold)
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
  for i, v in ipairs(cards) do
    local x = 160 + (i - 1) * (detailed and 480 or 240)
    local width = detailed and 448 or 208
    U.face(
      v.artKind,
      x + (detailed and 186 or 54),
      312,
      detailed and 76 or 116,
      detailed and 76 or 116
    )
    local function caption(value, y, initial, tint, wrap, rowStep)
      local size = 11
      rowStep = rowStep or 18
      local height = wrap and rowStep * 2 or 26
      if wrap then
        size = initial
        value = TextFit.wrap(U.fonts[size], value, width, 2)
      else
        for _, candidate in ipairs({ 18, 16, 14, 13, 12, 11 }) do
          if candidate <= initial and Skin.inkBounds(U.fonts[candidate], value).w <= width then
            size = candidate
            break
          end
        end
        value = TextFit.ellipsis(U.fonts[size], value, width)
      end
      Skin.zone('bestiary card ' .. v.kind, x + 6, y, width, height)
      if wrap then
        local row = 0
        for line in value:gmatch('[^\n]+') do
          Skin.boxText(line, x + 6, y + row * rowStep, width, rowStep, U.fonts[size], tint)
          row = row + 1
        end
      else
        Skin.boxText(value, x + 6, y, width, height, U.fonts[size], tint)
      end
      Skin.endZone()
    end
    caption(v.name, detailed and 392 or 435, detailed and 13 or 18, v.color, detailed, 24)
    caption(v.desc, detailed and 446 or 467, detailed and 13 or 14, ivory, detailed)
    caption(v.tip, detailed and 486 or 491, detailed and 13 or 14, muted, detailed)
  end
  if total > 1 then
    center(Text.get('page_count', { page = page, pages = total }), 299, 11, muted)
  end
  center(Text.get('help_reload'), 528, 18, ivory)
  center(Text.get('help_charge'), 554, 16, gold)
  center(Text.get('help_ward'), 580, 14, muted)
  Skin.endZone()
end
return S
