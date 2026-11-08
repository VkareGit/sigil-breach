-- A fire's three work places. The painting is assembled from the existing skin
-- and unchanged weapon art; the same offer owns its quote and preview.
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
  local list = {}
  for i, id in ipairs(stations) do
    list[#list + 1] = {
      id = 'shop_station_' .. id,
      label = Text.get('shop_station_' .. id),
      x = 128 + (i - 1) * 344,
      y = 141,
      w = 328,
      h = 44,
      active = station(g) == id,
    }
  end
  if station(g) == 'arsenal' then
    for i, id in ipairs(Weapons.onShop()) do
      list[#list + 1] = {
        id = 'shop_card_' .. id,
        label = Text.get(Weapons.get(id).hud.tab),
        x = 128 + (i - 1) * 202,
        y = 204,
        w = 190,
        h = 42,
        active = weapon(g) == id,
      }
    end
  end
  for i, o in ipairs(Shop.offers(g)) do
    local _, reason = Economy.quote(g, o.id)
    local y = 212 + (i - 1) * 86
    list[#list + 1] = {
      id = 'buy_' .. o.id,
      label = Economy.label(g, o.id),
      x = 944,
      y = y,
      w = 208,
      h = 38,
      disabled = reason ~= nil,
    }
    if o.kind == 'sigil' then
      local r = Queries.run(g)
      list[#list + 1] = {
        id = 'remove_' .. o.id,
        label = Text.get('shop_sigil_remove'),
        x = 944,
        y = y + 42,
        w = 208,
        h = 38,
        disabled = not Economy.wearing(r, o),
      }
    end
  end
  list[#list + 1] =
    { id = 'shop_back', label = Text.get('shop_leave'), x = 128, y = 593, w = 310, h = 48 }
  list[#list + 1] = {
    id = 'ready',
    label = Text.get('shop_travel'),
    x = 824,
    y = 593,
    w = 328,
    h = 48,
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
    26,
    U.fonts[size],
    color or C.ivory
  )
end
function Shop.draw(g, U)
  local lg = love.graphics
  local r = Queries.run(g)
  lg.setColor(0.025, 0.018, 0.016, 0.94)
  lg.rectangle('fill', 0, 0, 1280, 720)
  Skin.panel(96, 44, 1088, 628, 5, 14)
  Skin.inscription('merchant', 128, 79, 490, 48)
  write(U, Text.get('souls_amount', { amount = r.wallet }), 844, 87, 308, 24, C.gold)
  if station(g) == 'arsenal' then
    local id = weapon(g)
    Skin.weaponCard(id, 128, 258, 392, 262)
    write(U, Text.get(Weapons.get(id).name), 150, 454, 348, 22, C.gold)
    write(
      U,
      Text.get(Weapons.slotOf(g, id) and 'shop_weapon_owned' or 'shop_weapon_unowned'),
      150,
      486,
      348,
      16,
      C.muted
    )
  else
    Skin.panel(128, 204, 392, 316, 2, 12)
    if station(g) == 'sigils' then
      for i, id in ipairs(SigilRules.order) do
        local x, y = 185 + (i - 1) % 2 * 152, 218 + math.floor((i - 1) / 2) * 68
        GoeticSigils.draw(id:gsub('sigil_', ''), x, y, 60, C.sepia)
      end
    else
      Skin.icon('vow_flask', 260, 235, 128)
    end
    if station(g) == 'sigils' then
      write(
        U,
        Text.get('shop_sigil_capacity', { used = Economy.sigilsWorn(r), max = SigilRules.capacity }),
        150,
        360,
        342,
        20,
        C.gold
      )
    end
    local description =
      Text.get(station(g) == 'sigils' and 'shop_collection_tip' or 'shop_vows_tip')
    local n = 0
    for line in TextFit.wrap(U.fonts[18], description, 342, 5):gmatch('[^\n]+') do
      write(U, line, 150, 385 + n * 24, 342, 18, C.ivory)
      n = n + 1
    end
  end
  for i, o in ipairs(Shop.offers(g)) do
    local y = 208 + (i - 1) * 86
    local name = Economy.describe(g, o.id)
    write(U, name, 550, y, 380, 18, C.gold)
    write(U, Economy.preview(g, o.id), 550, y + 25, 380, 14, C.ivory)
    local _, reason = Economy.quote(g, o.id)
    if o.kind == 'sigil' then
      local n = 0
      for line in TextFit.wrap(U.fonts[12], Text.get(o.description), 380, 2):gmatch('[^\n]+') do
        write(U, line, 550, y + 44 + n * 18, 380, 12, C.muted)
        n = n + 1
      end
    else
      write(U, reason or Text.get(o.description), 550, y + 48, 600, 12, reason and C.red or C.muted)
    end
  end
  write(U, g.shopMessage or Text.get('shop_fire_tip'), 128, 553, 1024, 16, C.ivory)
end
return Shop
