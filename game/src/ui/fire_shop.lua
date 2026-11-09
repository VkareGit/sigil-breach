-- A fire's three work places. The painting is assembled from the existing skin
-- and unchanged weapon art; the same offer owns its quote and preview.
local ShopPage = require('src.content.screens.fire_shop')
local FrameSize = require('src.content.ui_layout')
local Skin = require('src.ui.skin')
local Text = require('src.content.text')
local TextFit = require('src.ui.text_fit')
local Economy = require('src.run.economy')
local Weapons = require('src.content.weapons')
local Queries = require('src.session.queries')
local GoeticSigils = require('src.ui.goetic_sigils')
local SigilRules = require('src.content.sigils')
local C = Skin.colors
local Shop = {}
local stations = { 'arsenal', 'vows', 'sigils' }
require('src.session.fields').declareView('ui.fire_shop', { 'shopStation', 'shopSelection' })
function Shop.select(g, station, weapon)
  g.view.shopStation = station or g.view.shopStation
  g.view.shopSelection = weapon or g.view.shopSelection
  g.view.shopPage = 1
end
local function station(g)
  return g.view.shopStation or 'arsenal'
end
local function weapon(g)
  return g.view.shopSelection or Weapons.onShop()[1]
end
function Shop.offers(g)
  local out, current = {}, station(g)
  for _, offer in ipairs(Economy.offersFor(g)) do
    if
      (current == 'arsenal' and offer.weapon == weapon(g) and offer.kind ~= 'sigil')
      or (current == 'vows' and offer.kind == 'vow' and not offer.weapon)
      or (current == 'sigils' and offer.kind == 'sigil')
    then
      out[#out + 1] = offer
    end
  end
  return out
end
function Shop.controls(g, elsewhere)
  local L = ShopPage
  local list = {}
  for i, id in ipairs(stations) do
    local T = L.station
    list[#list + 1] = {
      id = 'shop_station_' .. id,
      label = Text.get('shop_station_' .. id),
      x = T.x + (i - 1) * T.step,
      y = T.y,
      w = T.w,
      h = T.h,
      active = station(g) == id,
    }
  end
  if station(g) == 'arsenal' then
    local T = L.card
    for i, id in ipairs(Weapons.onShop()) do
      list[#list + 1] = {
        id = 'shop_card_' .. id,
        label = Text.get(Weapons.get(id).hud.tab),
        x = T.x + (i - 1) * T.step,
        y = T.y,
        w = T.w,
        h = T.h,
        active = weapon(g) == id,
      }
    end
  end
  local B = L.buy
  for i, o in ipairs(Shop.offers(g)) do
    local _, reason = Economy.quote(g, o.id)
    local y = L.offerRows.y + (i - 1) * L.offerRows.step
    list[#list + 1] = {
      id = 'buy_' .. o.id,
      label = Economy.label(g, o.id),
      x = B.x,
      y = y,
      w = B.w,
      h = B.h,
      disabled = reason ~= nil,
    }
    if o.kind == 'sigil' then
      local r = Queries.run(g)
      list[#list + 1] = {
        id = 'remove_' .. o.id,
        label = Text.get('shop_sigil_remove'),
        x = B.x,
        y = y + B.below,
        w = B.w,
        h = B.h,
        disabled = not Economy.wearing(r, o),
      }
    end
  end
  local back, travel = L.back, L.travel
  list[#list + 1] = {
    id = 'shop_back',
    label = Text.get('shop_leave'),
    x = back.x,
    y = back.y,
    w = back.w,
    h = back.h,
  }
  list[#list + 1] = {
    id = 'ready',
    label = Text.get('shop_travel'),
    x = travel.x,
    y = travel.y,
    w = travel.w,
    h = travel.h,
    disabled = not elsewhere,
  }
  return list
end
local function write(U, value, x, y, width, size, color)
  Skin.boxText(
    TextFit.ellipsis(U.fonts[size], value, width),
    x,
    y,
    width,
    ShopPage.lineHeight,
    U.fonts[size],
    color or C.ivory
  )
end
-- A text on its line (content/screens/fire_shop.lua), dy lower.
local function put(U, value, line, dy, color)
  write(U, value, line[1], line[2] + (dy or 0), line[3], line.font, color)
end
function Shop.draw(g, U)
  local lg = love.graphics
  local L = ShopPage
  local r = Queries.run(g)
  lg.setColor(L.veil[1], L.veil[2], L.veil[3], L.veil[4])
  lg.rectangle('fill', 0, 0, FrameSize.width, FrameSize.height)
  Skin.panel(L.page[1], L.page[2], L.page[3], L.page[4], 5, L.page.corner)
  Skin.inscription('merchant', L.merchant[1], L.merchant[2], L.merchant[3], L.merchant[4])
  put(U, Text.get('souls_amount', { amount = r.wallet }), L.wallet, 0, C.gold)
  if station(g) == 'arsenal' then
    local id = weapon(g)
    local W = L.weaponCard
    Skin.weaponCard(id, W[1], W[2], W[3], W[4])
    put(U, Text.get(Weapons.get(id).name), L.weaponName, 0, C.gold)
    put(
      U,
      Text.get(Weapons.slotOf(g, id) and 'shop_weapon_owned' or 'shop_weapon_unowned'),
      L.owned,
      0,
      C.muted
    )
  else
    local P = L.plate
    Skin.panel(P[1], P[2], P[3], P[4], 2, P.corner)
    if station(g) == 'sigils' then
      local S = L.seals
      for i, id in ipairs(SigilRules.order) do
        local x, y = S.x + (i - 1) % 2 * S.column, S.y + math.floor((i - 1) / 2) * S.row
        GoeticSigils.draw(id:gsub('sigil_', ''), x, y, S.side, C.sepia)
      end
    else
      Skin.icon('vow_flask', L.flask[1], L.flask[2], L.flask.size)
    end
    if station(g) == 'sigils' then
      put(
        U,
        Text.get('shop_sigil_capacity', { used = Economy.sigilsWorn(r), max = SigilRules.capacity }),
        L.capacity,
        0,
        C.gold
      )
    end
    local description =
      Text.get(station(g) == 'sigils' and 'shop_collection_tip' or 'shop_vows_tip')
    local n = 0
    local T = L.tip
    for line in TextFit.wrap(U.fonts[T.font], description, T[3], T.lines):gmatch('[^\n]+') do
      put(U, line, T, n * T.step, C.ivory)
      n = n + 1
    end
  end
  local O = L.offer
  for i, o in ipairs(Shop.offers(g)) do
    local y = O.y + (i - 1) * O.step
    local name = Economy.describe(g, o.id)
    put(U, name, O.name, y, C.gold)
    put(U, Economy.preview(g, o.id), O.preview, y, C.ivory)
    local _, reason = Economy.quote(g, o.id)
    if o.kind == 'sigil' then
      local n = 0
      local S = O.sigil
      for line in
        TextFit.wrap(U.fonts[S.font], Text.get(o.description), S[3], S.lines):gmatch('[^\n]+')
      do
        put(U, line, S, y + n * S.step, C.muted)
        n = n + 1
      end
    else
      put(U, reason or Text.get(o.description), O.other, y, reason and C.red or C.muted)
    end
  end
  put(U, g.shopMessage or Text.get('shop_fire_tip'), L.message, 0, C.ivory)
end
return Shop
