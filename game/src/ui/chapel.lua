local FieldUI = require('src.ui.test_field')
local Characters = require('src.content.characters')
local Tiles = require('src.core.tiles')
local Context = require('src.session.context')
local D = {}
local FireShop = require('src.ui.fire_shop')
local Stats = require('src.session.stats')
local Text = require('src.content.text')
local Pages = require('src.ui.pages')
local TextFit = require('src.ui.text_fit')
local lg = love.graphics
local Economy = require('src.run.economy')
local Queries = require('src.session.queries')
local Way = require('src.content.pilgrimage')
local Skin = require('src.ui.skin')
local Weapons = require('src.content.weapons')
local Palette = require('src.ui.palette')
local Pools = require('src.session.world')
local Grid = require('src.physics.grid')
local PilgrimScreens = require('src.content.screens.pilgrimage')
local FrameSize = require('src.content.ui_layout')
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
  for _, offer in ipairs(Economy.offersFor(g)) do
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
    local name, description = Economy.describe(g, offer.id)
    local R = PilgrimScreens.rows
    detailed = detailed
      or U.fonts[R.nameFont]:getInk(name).w > R.width
      or U.fonts[R.descFont]:getInk(description).w > R.width
  end
  local first, last, page, total = Pages.range(#offers, g.view.shopPage, detailed and 4 or 6)
  return first,
    last,
    page,
    total,
    detailed and PilgrimScreens.rows.detailed or PilgrimScreens.rows.plain,
    detailed
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
  Skin.text(t, x, y, U.fonts[size or PilgrimScreens.font], c or ivory)
end
local function center(t, y, size, c)
  local font = U.fonts[size or PilgrimScreens.font]
  Skin.text(t, (FrameSize.width - font:getWidth(t)) / 2, y, font, c or ivory)
end
-- A button on its box.
local function button(id, label, box, extra)
  local b = { id = id, label = label, x = box[1], y = box[2], w = box[3], h = box[4] }
  for key, value in pairs(extra or {}) do
    b[key] = value
  end
  return b
end
-- A text at its place ({ x, y, font }), or centred on its line ({ y, font }).
local function at(t, place, c)
  text(t, place[1], place[2], place.font, c)
end
local function centred(t, line, c)
  center(t, line[1], line.font, c)
end
local function box(b)
  return b[1], b[2], b[3], b[4]
end
local function rect(x, y, w, h, c, a)
  color(c, a)
  lg.rectangle('fill', x, y, w, h)
end
local function panel(x, y, w, h)
  Skin.panel(x, y, w, h, 1, PilgrimScreens.panelCorner)
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
      local _, reason = Economy.quote(g, o.id)
      local B = PilgrimScreens.buy
      list[#list + 1] = {
        id = 'buy_' .. o.id,
        label = Economy.label(g, o.id),
        x = B.x,
        y = B.y + (i - first) * rowHeight,
        w = B.w,
        h = B.h,
        disabled = reason ~= nil,
      }
    end
    local field = Queries.field(g)
    -- Travel goes only to a fire already found (owner): none yet, no journey.
    list[#list + 1] = button(
      'ready',
      Text.get(field and 'shop_ready_field' or 'shop_travel'),
      PilgrimScreens.travel,
      { disabled = not field and not D.elsewhere(g) }
    )
    list[#list + 1] = button(
      'shop_back',
      Text.get(Queries.field(g) and 'shop_back' or 'shop_leave'),
      PilgrimScreens.back
    )
    if pages > 1 then
      local label = Text.get('previous_short', { page = page, pages = pages })
      list[#list + 1] = button('shop_prev', label, PilgrimScreens.previous)
      list[#list + 1] = button('shop_next', Text.get('next_short'), PilgrimScreens.next)
    end
    -- One button per weapon of the loadout across the shop's right half.
    local count = Weapons.count(g, Context.actor(g))
    local T = PilgrimScreens.weaponTab
    local step = count <= 2 and T.pair or math.floor(T.span / count)
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
        x = T.x + (slot - 1) * step,
        y = T.y,
        w = step - T.gap,
        h = T.h,
        active = Weapons.slot(g, Context.actor(g)) == slot,
      }
    end
    return list
  elseif g.state == 'menu' then
    -- The way through the chapel, and the proving ground as a workshop beside it.
    local M = PilgrimScreens.menu
    local list = { button('start', Text.get(r.saved and 'menu_continue' or 'menu_begin'), M.start) }
    if r.saved then
      list[2] = button('restart', Text.get('menu_new'), M.restart)
      list[3] = button('field_start', Text.get('menu_field_short'), M.fieldShort)
    else
      list[2] = button('field_start', Text.get('menu_field'), M.field)
    end
    list[#list + 1] = button('help', Text.get('menu_help'), M.help)
    list[#list + 1] = button('settings', Text.get('menu_settings'), M.settings)
    list[#list + 1] = button('quit', Text.get('menu_quit'), M.quit)
    list[#list + 1] = button('field_skirmish', Text.get('menu_skirmish'), M.skirmish)
    if r.slot then
      local label = Text.get('menu_slot', { slot = r.slot, count = Way.slots })
      list[#list + 1] = button('save_slot', label, M.slot)
    end
    return list
  elseif g.state == 'confirm_new' then
    local C = PilgrimScreens.confirmButtons
    return {
      button('new_confirm', Text.get('confirm_new'), C.yes),
      button('new_cancel', Text.get('confirm_keep'), C.keep),
    }
  elseif g.state == 'dead' then
    local B = PilgrimScreens.deadButtons
    return {
      button('retry', Text.get('pilgrim_wake'), B.retry),
      button('menu', Text.get('dead_menu'), B.menu),
    }
  end
end
local Clocks = require('src.content.tuning').clocks
local place = {}
function D.heading(g)
  if Queries.field(g) then
    return FieldUI.heading(g, U)
  end
  -- The place stands for a moment when it changes and whenever the game stands (0.45, owner
  -- D18); in play nothing rests over the scene.
  local objective = Queries.objective(g)
  if objective ~= place.shown then
    place.shown, place.at = objective, g.elapsed
  end
  if g.state ~= 'playing' or g.map or g.elapsed - place.at < Clocks.placeFor then
    local P = PilgrimScreens.place
    local plate, title, name = P.plate, P.title, P.name
    Skin.panel(plate[1], plate[2], plate[3], plate[4], 2, plate.corner)
    Skin.zone('objective field', box(P.zone))
    Skin.boxText(
      Text.get('menu_chapel'),
      title[1],
      title[2],
      title[3],
      title[4],
      U.fonts[title.font],
      gold
    )
    local size = name.font
    if Skin.inkBounds(U.fonts[size], objective).w > name[3] then
      size = name.small
    end
    Skin.boxText(objective, name[1], name[2], name[3], name[4], U.fonts[size], ivory)
    Skin.endZone()
  end
  if g.saveWarning then
    centred(Text.get('save_warning', { reason = g.saveWarning }), PilgrimScreens.saveWarning, red)
  end
end
function D.shop(g)
  if Queries.run(g).market == require('src.content.shop').markets.fire then
    return FireShop.draw(g, U)
  end
  local r, p = Queries.run(g), Context.actor(g)
  local S = PilgrimScreens.shop
  rect(0, 0, FrameSize.width, FrameSize.height, Palette.veilDeep, S.veil)
  Skin.panel(S.page[1], S.page[2], S.page[3], S.page[4], 5, S.page.corner)
  Skin.zone('shop writing field', box(S.writing))
  Skin.icon('ring', S.ring[1], S.ring[2], S.ring.size)
  Skin.inscription('merchant', box(S.merchant))
  Skin.icon('soul', S.soul[1], S.soul[2], S.soul.size)
  at(Text.get('souls_amount', { amount = r.wallet }), S.wallet, gold)
  at(Text.get(Queries.field(g) and 'shop_field_title' or 'shop_fire_title'), S.title, gold)
  at(
    -- The weapon by the name the bar gives it, the ward against the knight's own maximum.
    Text.get('shop_buying', {
      weapon = Text.get(Weapons.inHand(g, nil, Context.actor(g)).hud.tab),
      ward = math.ceil(p.armor),
      max = Characters.maxWard(p),
    }),
    S.buying,
    muted
  )
  local first, last, _, _, rowHeight, detailed = D.shopPage(g)
  local offers = D.offers(g)
  for i = first, last do
    local o = offers[i]
    local row = i - first + 1
    local R, H, I, Z, T, D = S.row, S.highlight, S.icon, S.zone, S.rowTitle, S.description
    local width = PilgrimScreens.rows.width
    local y = R.y + (row - 1) * rowHeight
    rect(R.x, y, R.w, 1, gold, R.ruleAlpha)
    if U.focus == row then
      rect(H.x, y + H.inset, H.w, rowHeight - 2 * H.inset, Palette.highlight, H.alpha)
    end
    Skin.icon(assert(o.icon, 'missing shop offer icon ' .. o.id), I.x, y + I.y, I.size)
    Skin.zone('offer ' .. o.id, Z.x, y + H.inset, Z.w, rowHeight - 2 * H.inset)
    local name, description = Economy.describe(g, o.id)
    local titleSize = T.font
    if detailed then
      for _, candidate in ipairs(T.fonts) do
        titleSize = candidate
        if U.fonts[candidate]:getInk(name).w <= width then
          break
        end
      end
    end
    text(TextFit.ellipsis(U.fonts[titleSize], name, width), T.x, y + T.y, titleSize, gold)
    if detailed then
      local line = 0
      for value in TextFit.wrap(U.fonts[D.font], description, width, D.lines):gmatch('[^\n]+') do
        text(value, T.x, y + D.y + line * D.step, D.font, muted)
        line = line + 1
      end
    else
      text(description, T.x, y + D.y, D.font, muted)
    end
    Skin.endZone()
  end
  local selected = U.controls(g, {})[U.focus]
  local price, reason
  if selected and selected.id:sub(1, 4) == 'buy_' then
    price, reason = Economy.quote(g, selected.id:sub(5))
  end
  -- The purchase message and balance have their own columns; the rest message
  -- spans the next line, clear of both even with the longest fire description.
  local Ms, Bs, Rs = S.message, S.balance, S.rest
  Skin.zone('shop purchase message', box(Ms.zone))
  -- A long message (the proving ground's) steps down a size or two rather than run into the
  -- balance column (0.43: it crossed the zone since the balance got its own column).
  local message = reason or g.shopMessage or Text.get('shop_engraving_tip')
  local size = Ms.font
  while size > Ms.smallest and Skin.inkBounds(U.fonts[size], message).w > Ms.wide do
    size = size - 2
  end
  text(message, Ms.x, Ms.y + (Ms.font - size) / 2, size, reason and red or ivory)
  Skin.endZone()
  Skin.zone('shop remaining souls', box(Bs.zone))
  if price and not reason then
    text(Text.get('shop_after', { amount = r.wallet - price }), Bs.x, Bs.y, Bs.font, gold)
  end
  Skin.endZone()
  Skin.zone('shop rest message', box(Rs.zone))
  text(Text.get('shop_fire_tip'), Rs.x, Rs.y, Rs.font, muted)
  Skin.endZone()
  Skin.endZone()
  if g.saveWarning then
    centred(g.saveWarning, S.warning, red)
  end
end
function D.map(g)
  if Queries.field(g) then
    return FieldUI.map(g, U)
  end
  local r = Queries.run(g)
  local M = PilgrimScreens.map
  rect(0, 0, FrameSize.width, FrameSize.height, Palette.veilCool, M.veil)
  panel(box(M.page))
  Skin.zone('map writing field', box(M.writing))
  at(Text.get('map_fires'), M.fires, gold)
  -- The proving ground has no way of its own: it stands in the chapel.
  local area = r.area and Way.areas:get(r.area) or Way.start()
  for i, fire in ipairs(area.fires) do
    local lit = r.lit[fire.id]
    local F = M.fire
    local y = F.y + (i - 1) * F.step
    text(Text.get(fire.name), F.x, y, F.font, lit and gold or muted)
    text(
      Text.get(lit and 'map_fire_lit' or 'map_fire_dark'),
      F.state.x,
      y + F.state.y,
      F.state.font,
      muted
    )
  end
  local sz, ox, oy = M.side / Grid.span(g.world), M.origin[1], M.origin[2]
  for z = 1, Grid.depth(g.world) do
    for x = 1, Grid.width(g.world) do
      if Tiles.walkable[g.world.map[z][x]] then
        rect(ox + x * sz, oy + z * sz, sz - 1, sz - 1, Palette.stone)
      end
    end
  end
  local p = Context.actor(g)
  color(ivory)
  local K = M.knight
  lg.circle('fill', ox + p.x * sz, oy + p.z * sz, K.radius)
  lg.line(
    ox + p.x * sz,
    oy + p.z * sz,
    ox + p.x * sz + math.sin(p.yaw) * K.heading,
    oy + p.z * sz + math.cos(p.yaw) * K.heading
  )
  local mark = M.enemy
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.hp > 0 then
      rect(ox + e.x * sz - mark / 2, oy + e.z * sz - mark / 2, mark, mark, red)
    end
  end
  local cold = Palette.cold
  color(cold)
  lg.setLineWidth(M.line)
  for _, fire in ipairs(area.fires) do
    if r.lit[fire.id] and fire.id ~= area.first then
      lg.circle('line', ox + fire.x * sz, oy + fire.z * sz, M.fireRing)
    end
  end
  local shrine = g.world.ember
  local sx, sy = ox + shrine.x * sz, oy + shrine.z * sz
  color(cold)
  lg.setLineWidth(M.line)
  lg.circle('line', sx, sy, M.ember.radius)
  local icon = M.ember.icon
  Skin.icon('ring', sx - icon / 2, sy - icon / 2, icon)
  if r.echo then
    local e, E = r.echo, M.echo
    color(blue)
    lg.circle('line', ox + e.x * sz, oy + e.z * sz, E.radius)
    text(
      Text.get('map_echo'),
      ox + e.x * sz + E.label.x,
      oy + e.z * sz + E.label.y,
      E.label.font,
      blue
    )
  end
  at(Text.get('map_chapel_legend'), M.legend, muted)
  at(Text.get('map_legend_marks'), M.marks, muted)
  at(Text.get('map_pause'), M.pause, gold)
  Skin.endZone()
end
function D.ending(g)
  local r = Queries.run(g)
  local E = PilgrimScreens.ending
  rect(0, 0, FrameSize.width, FrameSize.height, Palette.veil, E.veil)
  panel(box(E.page))
  Skin.icon('skull', E.skull[1], E.skull[2], E.skull.size)
  Skin.zone('ending writing field', box(E.writing))
  centred(Text.get('pilgrim_died'), E.died, red)
  centred(Text.get('pilgrim_died_kept'), E.kept, muted)
  centred(
    r.echo and Text.get('ending_echo', { amount = r.echo.amount }) or Text.get('ending_no_echo'),
    E.echo,
    blue
  )
  centred(Text.get('ending_echo_warning'), E.warning, muted)
  -- What struck the last blow: what to read better next time.
  local harm = Queries.lastHarm(g)
  if harm then
    centred(
      harm == 'death_by_self' and Text.get(harm) or Text.get('death_by', { name = Text.get(harm) }),
      E.harm,
      red
    )
  end
  centred(
    Text.get('ending_stats', {
      minutes = string.format('%02d', math.floor(g.elapsed / 60)), -- constant: seconds a minute
      seconds = string.format('%02d', math.floor(g.elapsed % 60)), -- constant: seconds a minute
      kills = string.format('%d', Stats.total(g, 'kills')),
      deaths = string.format('%d', r.deaths),
      souls = string.format('%d', r.wallet),
    }),
    E.stats,
    ivory
  )
  if g.saveWarning then
    centred(g.saveWarning, E.saveWarning, red)
  end
  Skin.endZone()
end
function D.confirm(g)
  local C = PilgrimScreens.confirm
  rect(0, 0, FrameSize.width, FrameSize.height, Palette.veil, C.veil)
  panel(box(C.page))
  Skin.zone('confirmation writing field', box(C.writing))
  Skin.inscription('new_run', box(C.inscription))
  centred(Text.get('pilgrim_confirm'), C.question, muted)
  centred(Text.get('confirm_kept'), C.kept, gold)
  Skin.endZone()
end
return D
