local TestField = require('src.ui.test_field')
local Characters = require('src.content.characters')
local Tiles = require('src.core.tiles')
local Context = require('src.session.context')
local D = {}
local FireShop = require('src.ui.fire_shop')
local Stats = require('src.session.stats')
local Text = require('src.content.text')
local Pages = require('src.ui.pages')
local Fit = require('src.ui.text_fit')
local lg = love.graphics
local E = require('src.run.economy')
local Queries = require('src.session.queries')
local Way = require('src.content.pilgrimage')
local Skin = require('src.ui.skin')
local Weapons = require('src.content.weapons')
local Palette = require('src.ui.palette')
local Pools = require('src.session.world')
local Grid = require('src.physics.grid')
local ivory = Skin.colors.ivory
local muted = Skin.colors.muted
local gold = Skin.colors.gold
local blue = Skin.colors.blue
local red = Skin.colors.red
local U
require('src.session.fields').declareView('ui.chapel', { 'shopPage' })
-- Whether a fire other than the one he rests at is lit (travel has somewhere to go).
function D.elsewhere(g)
  local r = Queries.run(g)
  for _, fire in ipairs(Way.fires()) do
    if r and r.lit[fire.id] and fire.id ~= r.fire then
      return true
    end
  end
  return false
end
-- The offers shown: what belongs to a weapon only under that weapon's tab (the gun in hand;
-- the tabs at the top switch it), the rest under every tab (0.42, the owner).
function D.offers(g)
  local held, list = Weapons.idAt(g, nil, Context.actor(g)), {}
  for _, offer in ipairs(E.offersFor(g)) do
    if not offer.weapon or offer.weapon == held then
      list[#list + 1] = offer
    end
  end
  return list
end
function D.shopPage(g)
  local detailed = false
  local offers = D.offers(g)
  for _, offer in ipairs(offers) do
    local name, description = E.describe(g, offer.id)
    detailed = detailed
      or U.fonts[20]:getInk(name).w > 648
      or U.fonts[16]:getInk(description).w > 648
  end
  local first, last, page, total = Pages.range(#offers, g.view.shopPage, detailed and 4 or 6)
  return first, last, page, total, detailed and 80 or 56, detailed
end
function D.turnShop(g, delta)
  local _, _, page, total = D.shopPage(g)
  g.view.shopPage = math.max(1, math.min(total, page + delta))
end
function D.resetShop(g)
  g.view.shopPage = 1
end
function D.install(ui)
  U = ui
end
local function color(c, a)
  lg.setColor(c[1], c[2], c[3], a or 1)
end
local function text(t, x, y, size, c)
  Skin.text(t, x, y, U.fonts[size or 18], c or ivory)
end
local function center(t, y, size, c)
  local font = U.fonts[size or 18]
  Skin.text(t, (1280 - font:getWidth(t)) / 2, y, font, c or ivory)
end
local function rect(x, y, w, h, c, a)
  color(c, a)
  lg.rectangle('fill', x, y, w, h)
end
local function panel(x, y, w, h)
  Skin.panel(x, y, w, h, 1, 14)
end
function D.controls(g)
  local r = Queries.run(g)
  if not r or g.help or g.map then
    return nil
  end
  if g.state == 'shop' then
    if Queries.run(g).market == require('src.content.shop').markets.fire then
      return FireShop.controls(g, D.elsewhere(g))
    end
    local list = {}
    local first, last, page, pages, rowHeight = D.shopPage(g)
    local offers = D.offers(g)
    for i = first, last do
      local o = offers[i]
      local _, reason = E.quote(g, o.id)
      list[#list + 1] = {
        id = 'buy_' .. o.id,
        label = E.label(g, o.id),
        x = 881,
        y = 189 + (i - first) * rowHeight,
        w = 270,
        h = 42,
        disabled = reason ~= nil,
      }
    end
    local field = Queries.field(g)
    list[#list + 1] = {
      id = 'ready',
      label = Text.get(field and 'shop_ready_field' or 'shop_travel'),
      x = 824,
      y = 593,
      w = 328,
      h = 48,
      -- Travel goes only to a fire already found (owner): none yet, no journey.
      disabled = not field and not D.elsewhere(g),
    }
    list[#list + 1] = {
      id = 'shop_back',
      label = Text.get(Queries.field(g) and 'shop_back' or 'shop_leave'),
      x = 128,
      y = 593,
      w = 310,
      h = 48,
    }
    if pages > 1 then
      list[#list + 1] = {
        id = 'shop_prev',
        label = Text.get('previous_short', { page = page, pages = pages }),
        x = 450,
        y = 593,
        w = 170,
        h = 48,
      }
      list[#list + 1] =
        { id = 'shop_next', label = Text.get('next_short'), x = 638, y = 593, w = 170, h = 48 }
    end
    -- One button per weapon of the loadout across the shop's right half.
    local count = Weapons.count(g, Context.actor(g))
    local step = count <= 2 and 262 or math.floor(524 / count)
    for slot = 1, count do
      local mag, reserve = Weapons.meter(g, slot, Context.actor(g))
      list[#list + 1] = {
        id = 'shop_weapon_' .. slot,
        label = Text.get('shop_weapon', {
          slot = slot,
          tab = Text.get(Weapons.profile(slot, g, Context.actor(g)).hud.tab),
          mag = mag,
          reserve = reserve,
        }),
        x = 640 + (slot - 1) * step,
        y = 137,
        w = step - 12,
        h = 40,
        active = Weapons.slot(g, Context.actor(g)) == slot,
      }
    end
    return list
  elseif g.state == 'menu' then
    -- The way through the chapel, and the proving ground as a workshop beside it.
    local list = {
      {
        id = 'start',
        label = Text.get(r.saved and 'menu_continue' or 'menu_begin'),
        x = 72,
        y = 390,
        w = 400,
        h = 54,
      },
    }
    if r.saved then
      list[2] = { id = 'restart', label = Text.get('menu_new'), x = 72, y = 455, w = 194, h = 44 }
      list[3] = {
        id = 'field_start',
        label = Text.get('menu_field_short'),
        x = 270,
        y = 455,
        w = 194,
        h = 44,
      }
    else
      list[2] =
        { id = 'field_start', label = Text.get('menu_field'), x = 72, y = 455, w = 400, h = 44 }
    end
    list[#list + 1] =
      { id = 'help', label = Text.get('menu_help'), x = 72, y = 514, w = 194, h = 44 }
    list[#list + 1] =
      { id = 'settings', label = Text.get('menu_settings'), x = 270, y = 514, w = 194, h = 44 }
    list[#list + 1] =
      { id = 'quit', label = Text.get('menu_quit'), x = 72, y = 573, w = 194, h = 40 }
    list[#list + 1] = {
      id = 'field_skirmish',
      label = Text.get('menu_skirmish'),
      x = 270,
      y = 573,
      w = 194,
      h = 40,
    }
    if r.slot then
      list[#list + 1] = {
        id = 'save_slot',
        label = Text.get('menu_slot', { slot = r.slot, count = Way.slots }),
        x = 300,
        y = 648,
        w = 236,
        h = 38,
      }
    end
    return list
  elseif g.state == 'confirm_new' then
    return {
      { id = 'new_confirm', label = Text.get('confirm_new'), x = 440, y = 405, w = 400, h = 48 },
      { id = 'new_cancel', label = Text.get('confirm_keep'), x = 440, y = 470, w = 400, h = 44 },
    }
  elseif g.state == 'dead' then
    return {
      {
        id = 'retry',
        label = Text.get('pilgrim_wake'),
        x = 410,
        y = 524,
        w = 460,
        h = 50,
      },
      { id = 'menu', label = Text.get('dead_menu'), x = 410, y = 591, w = 460, h = 42 },
    }
  end
end
local Clocks = require('src.content.tuning').clocks
local place = {}
function D.heading(g)
  if Queries.field(g) then
    return TestField.heading(g, U)
  end
  -- The place stands for a moment when it changes and whenever the game stands (0.45, owner
  -- D18); in play nothing rests over the scene.
  local objective = Queries.objective(g)
  if objective ~= place.shown then
    place.shown, place.at = objective, g.elapsed
  end
  if g.state ~= 'playing' or g.map or g.elapsed - place.at < Clocks.placeFor then
    Skin.panel(20, 16, 378, 64, 2, 9)
    Skin.zone('objective field', 32, 26, 354, 44)
    Skin.boxText(Text.get('menu_chapel'), 35, 27, 348, 20, U.fonts[14], gold)
    local size = 16
    if Skin.inkBounds(U.fonts[size], objective).w > 348 then
      size = 14
    end
    Skin.boxText(objective, 35, 48, 348, 22, U.fonts[size], ivory)
    Skin.endZone()
  end
  if g.saveWarning then
    center(Text.get('save_warning', { reason = g.saveWarning }), 448, 18, red)
  end
end
function D.shop(g)
  if Queries.run(g).market == require('src.content.shop').markets.fire then
    return FireShop.draw(g, U)
  end
  local r, p = Queries.run(g), Context.actor(g)
  rect(0, 0, 1280, 720, Palette.veilDeep, 0.9)
  Skin.panel(96, 44, 1088, 628, 5, 14)
  Skin.zone('shop writing field', 128, 78, 1024, 562)
  Skin.icon('ring', 129, 84, 36)
  Skin.inscription('merchant', 188, 82, 420, 52)
  Skin.icon('soul', 844, 84, 31)
  text(Text.get('souls_amount', { amount = r.wallet }), 892, 84, 28, gold)
  text(Text.get(Queries.field(g) and 'shop_field_title' or 'shop_fire_title'), 130, 150, 20, gold)
  text(
    -- The weapon by the name the bar gives it, the ward against the knight's own maximum.
    Text.get('shop_buying', {
      weapon = Text.get(Weapons.inHand(g, nil, Context.actor(g)).hud.tab),
      ward = math.ceil(p.armor),
      max = Characters.maxWard(p),
    }),
    650,
    120,
    14,
    muted
  )
  local first, last, _, _, rowHeight, detailed = D.shopPage(g)
  local offers = D.offers(g)
  for i = first, last do
    local o = offers[i]
    local row = i - first + 1
    local y = 183 + (row - 1) * rowHeight
    rect(128, y, 1024, 1, gold, 0.22)
    if U.focus == row then
      rect(132, y + 3, 730, rowHeight - 6, Palette.highlight, 0.22)
    end
    Skin.icon(assert(o.icon, 'missing shop offer icon ' .. o.id), 145, y + 7, 40)
    Skin.zone('offer ' .. o.id, 208, y + 3, 650, rowHeight - 6)
    local name, description = E.describe(g, o.id)
    local titleSize = 20
    if detailed then
      for _, candidate in ipairs({ 20, 18, 16, 14 }) do
        titleSize = candidate
        if U.fonts[candidate]:getInk(name).w <= 648 then
          break
        end
      end
    end
    text(Fit.ellipsis(U.fonts[titleSize], name, 648), 209, y + 7, titleSize, gold)
    if detailed then
      local line = 0
      for value in Fit.wrap(U.fonts[16], description, 648, 2):gmatch('[^\n]+') do
        text(value, 209, y + 32 + line * 22, 16, muted)
        line = line + 1
      end
    else
      text(description, 209, y + 32, 16, muted)
    end
    Skin.endZone()
  end
  local selected = U.controls(g, {})[U.focus]
  local price, reason
  if selected and selected.id:sub(1, 4) == 'buy_' then
    price, reason = E.quote(g, selected.id:sub(5))
  end
  -- The purchase message and balance have their own columns; the rest message
  -- spans the next line, clear of both even with the longest fire description.
  Skin.zone('shop purchase message', 128, 530, 680, 32)
  -- A long message (the proving ground's) steps down a size or two rather than run into the
  -- balance column (0.43: it crossed the zone since the balance got its own column).
  local message = reason or g.shopMessage or Text.get('shop_engraving_tip')
  local size = 18
  while size > 14 and Skin.inkBounds(U.fonts[size], message).w > 676 do
    size = size - 2
  end
  text(message, 129, 536 + (18 - size) / 2, size, reason and red or ivory)
  Skin.endZone()
  Skin.zone('shop remaining souls', 824, 530, 328, 28)
  if price and not reason then
    text(Text.get('shop_after', { amount = r.wallet - price }), 825, 536, 16, gold)
  end
  Skin.endZone()
  Skin.zone('shop rest message', 128, 565, 1024, 26)
  text(Text.get('shop_fire_tip'), 129, 567, 16, muted)
  Skin.endZone()
  Skin.endZone()
  if g.saveWarning then
    center(g.saveWarning, 679, 16, red)
  end
end
function D.map(g)
  if Queries.field(g) then
    return TestField.map(g, U)
  end
  local r = Queries.run(g)
  rect(0, 0, 1280, 720, Palette.veilCool, 0.96)
  panel(100, 40, 1080, 640)
  Skin.zone('map writing field', 132, 76, 1016, 570)
  text(Text.get('map_fires'), 136, 131, 20, gold)
  -- The proving ground has no way of its own: it stands in the chapel.
  local area = r.area and Way.areas:get(r.area) or Way.start()
  for i, fire in ipairs(area.fires) do
    local lit = r.lit[fire.id]
    local y = 163 + (i - 1) * 39
    text(Text.get(fire.name), 136, y, 22, lit and gold or muted)
    text(Text.get(lit and 'map_fire_lit' or 'map_fire_dark'), 420, y + 5, 14, muted)
  end
  local sz, ox, oy = 420 / Grid.span(g.world), 652, 121
  for z = 1, Grid.depth(g.world) do
    for x = 1, Grid.width(g.world) do
      if Tiles.walkable[g.world.map[z][x]] then
        rect(ox + x * sz, oy + z * sz, sz - 1, sz - 1, Palette.stone)
      end
    end
  end
  local p = Context.actor(g)
  color(ivory)
  lg.circle('fill', ox + p.x * sz, oy + p.z * sz, 4)
  lg.line(
    ox + p.x * sz,
    oy + p.z * sz,
    ox + p.x * sz + math.sin(p.yaw) * 15,
    oy + p.z * sz + math.cos(p.yaw) * 15
  )
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.hp > 0 then
      rect(ox + e.x * sz - 2, oy + e.z * sz - 2, 4, 4, red)
    end
  end
  local cold = Palette.cold
  color(cold)
  lg.setLineWidth(2)
  for _, fire in ipairs(area.fires) do
    if r.lit[fire.id] and fire.id ~= area.first then
      lg.circle('line', ox + fire.x * sz, oy + fire.z * sz, 7)
    end
  end
  local shrine = g.world.ember
  local sx, sy = ox + shrine.x * sz, oy + shrine.z * sz
  color(cold)
  lg.setLineWidth(2)
  lg.circle('line', sx, sy, 13)
  Skin.icon('ring', sx - 8, sy - 8, 16)
  if r.echo then
    local e = r.echo
    color(blue)
    lg.circle('line', ox + e.x * sz, oy + e.z * sz, 7)
    text(Text.get('map_echo'), ox + e.x * sz - 18, oy + e.z * sz - 25, 14, blue)
  end
  text(Text.get('map_chapel_legend'), 132, 622, 16, muted)
  text(Text.get('map_legend_marks'), 652, 558, 14, muted)
  text(Text.get('map_pause'), 652, 585, 14, gold)
  Skin.endZone()
end
function D.ending(g)
  local r = Queries.run(g)
  rect(0, 0, 1280, 720, Palette.veil, 0.95)
  panel(96, 42, 1088, 628)
  Skin.icon('skull', 612, 52, 56)
  Skin.zone('ending writing field', 128, 110, 1024, 402)
  center(Text.get('pilgrim_died'), 116, 48, red)
  center(Text.get('pilgrim_died_kept'), 188, 22, muted)
  center(
    r.echo and Text.get('ending_echo', { amount = r.echo.amount }) or Text.get('ending_no_echo'),
    260,
    36,
    blue
  )
  center(Text.get('ending_echo_warning'), 326, 18, muted)
  -- What struck the last blow: what to read better next time.
  local harm = Queries.lastHarm(g)
  if harm then
    center(
      harm == 'death_by_self' and Text.get(harm) or Text.get('death_by', { name = Text.get(harm) }),
      364,
      22,
      red
    )
  end
  center(
    Text.get('ending_stats', {
      minutes = string.format('%02d', math.floor(g.elapsed / 60)),
      seconds = string.format('%02d', math.floor(g.elapsed % 60)),
      kills = string.format('%d', Stats.total(g, 'kills')),
      deaths = string.format('%d', r.deaths),
      souls = string.format('%d', r.wallet),
    }),
    412,
    22,
    ivory
  )
  if g.saveWarning then
    center(g.saveWarning, 490, 16, red)
  end
  Skin.endZone()
end
function D.confirm(g)
  rect(0, 0, 1280, 720, Palette.veil, 0.95)
  panel(250, 144, 780, 432)
  Skin.zone('confirmation writing field', 282, 176, 716, 180)
  Skin.inscription('new_run', 410, 185, 460, 54)
  center(Text.get('pilgrim_confirm'), 273, 22, muted)
  center(Text.get('confirm_kept'), 315, 20, gold)
  Skin.endZone()
end
return D
