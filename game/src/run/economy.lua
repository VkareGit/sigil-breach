-- The Ember's trade (0.24, Strategy): the offers are content (content/shop.lua),
-- each of a kind that says how it is priced, when it is unavailable and what
-- it gives. A new kind of offer (equipment, a relic, a base upgrade) is a new
-- entry in E.kinds; quote, buy and the shop screen do not change.
--   quote(g, offer, def) -> price, reason   (reason: why it cannot be bought)
--   apply(g, offer, def)                     gives the purchase
--   label(g, offer, price) -> text or nil    the button when not a price
--   describe(g, offer, def) -> name, text    optional, else the offer's own
--   done                                     the message after a purchase (a
--                                            text key)
local W = require('src.content.weapons')
local Ammo = require('src.content.ammo.index')
local Shop = require('src.content.shop')
local Abilities = require('src.content.abilities')
local Roles = require('src.core.roles')
local Text = require('src.content.text')
local Presentation = require('src.session.presentation')
local E = {}
E.offers = Shop.offers
-- Whether an engraving is the one worn: on its weapon when the run keeps one per weapon.
function E.worn(r, offer)
  if r.worn and offer.weapon then
    return r.worn[offer.weapon] == offer.id
  end
  return r.glyph == offer.id
end
-- What changes the guns of a run that keeps one engraving per weapon: those worn and a
-- glyph for every rank of a vow that names one (tempering), in the order of the offers.
function E.modifiers(r)
  local list = {}
  for _, offer in ipairs(Shop.offers) do
    if offer.kind == 'engraving' and E.worn(r, offer) and offer.weapon then
      list[#list + 1] = offer.id
    elseif offer.kind == 'vow' and offer.glyph then
      for _ = 1, r.vows and r.vows[offer.id] or 0 do
        list[#list + 1] = offer.glyph
      end
    end
  end
  return list
end
local function missing(g, def)
  return W.room(def, W.state(g))
end
local function terms(def)
  return Ammo.of(def).offer(def.ammo)
end
local function describeRounds(g, offer, def)
  local pack, unit, cap = terms(def)
  local n = math.max(0, math.min(pack, missing(g, def)))
  local quantity = n == 0 and Text.get('shop_pack')
    or Text.get(n == 1 and 'shop_round' or 'shop_rounds', { count = n })
  local weapon = Text.get(def.name)
  return offer.id == 'ammo' and Text.get('shop_ammo_name', { quantity = quantity, weapon = weapon })
    or Text.get('shop_refill_name', { weapon = weapon }),
    Text.get('shop_rounds_text', { price = unit, cap = cap })
end
local function roundsFull(g)
  return missing(g, W.inHand(g)) <= 0 and Text.get('shop_reserve_full') or nil
end
-- Rounds for the weapon in hand, by count: a pack, or everything missing.
local function rounds(count, fill)
  return {
    quote = function(g, _, def)
      local n = count(g, def)
      local _, unit = terms(def)
      local price = n * unit
      if n <= 0 then
        return price, Text.get('shop_reserve_full_reason')
      end
      return price
    end,
    apply = function(g, _, def)
      local pack = terms(def)
      W.refill(def, W.state(g), fill and missing(g, def) or pack)
    end,
    label = roundsFull,
    describe = describeRounds,
  }
end
E.kinds = {
  rounds = rounds(function(g, def)
    return math.min((terms(def)), missing(g, def))
  end, false),
  refill = rounds(missing, true),
  ward = {
    quote = function(g, offer)
      local armor = Roles.controlled(g).armor
      local price =
        math.ceil(math.min(offer.amount, Shop.maxWard - armor) * offer.price / offer.amount)
      if armor >= Shop.maxWard then
        return 0, Text.get('shop_ward_full_reason')
      end
      return price
    end,
    apply = function(g, offer)
      Roles.controlled(g).armor = math.min(Shop.maxWard, Roles.controlled(g).armor + offer.amount)
    end,
    label = function(g)
      return Roles.controlled(g).armor >= Shop.maxWard and Text.get('shop_ward_full') or nil
    end,
  },
  charge = {
    quote = function(g, offer)
      local state, def =
        Roles.controlled(g).abilityState[offer.ability], Abilities:get(offer.ability)
      if state.uses >= def.capacity then
        return 0, Text.get('shop_charges_full_reason')
      end
      return offer.price
    end,
    apply = function(g, offer)
      local state = Roles.controlled(g).abilityState[offer.ability]
      state.uses = state.uses + 1
    end,
    label = function(g, offer)
      local state = Roles.controlled(g).abilityState[offer.ability]
      return (state.uses or 0) >= Abilities:get(offer.ability).capacity
          and Text.get('shop_reserve_full')
        or nil
    end,
  },
  -- An engraving is bought once; owned, it is equipped for free. A run that keeps one per
  -- weapon (worn: weapon id -> engraving) changes only the one on that engraving's weapon.
  engraving = {
    quote = function(g, offer)
      local r = g.run
      if r.owned[offer.id] then
        return 0, E.worn(r, offer) and Text.get('shop_equipped_reason') or nil, true
      end
      return offer.price
    end,
    apply = function(g, offer)
      local r = g.run
      r.owned[offer.id] = true
      r.glyph = offer.id
      if r.worn and offer.weapon then
        r.worn[offer.weapon] = offer.id
      end
    end,
    label = function(g, offer)
      local r = g.run
      return r.owned[offer.id]
          and Text.get(E.worn(r, offer) and 'shop_equipped' or 'shop_equip_free')
        or nil
    end,
    done = 'shop_engraving_done',
  },
  -- A vow rises by ranks; what it gives is the mode's to keep (run/pilgrimage.lua).
  vow = {
    quote = function(g, offer)
      local rank = g.run.vows[offer.id] or 0
      if rank >= offer.limit then
        return 0, Text.get('shop_vow_full_reason'), true
      end
      return offer.price * offer.growth ^ rank
    end,
    apply = function(g, offer)
      g.run.vows[offer.id] = (g.run.vows[offer.id] or 0) + 1
    end,
    label = function(g, offer)
      return (g.run.vows[offer.id] or 0) >= offer.limit and Text.get('shop_vow_full') or nil
    end,
    describe = function(g, offer)
      return Text.get(offer.name),
        Text.get('shop_vow_text', {
          text = Text.get(offer.description),
          rank = g.run.vows[offer.id] or 0,
          limit = offer.limit,
        })
    end,
    done = 'shop_vow_done',
  },
}
-- What is on sale here. A fire and the field fill a knight differently, so they sell
-- different things; an offer that names no market is sold in both.
function E.offersFor(g)
  local market, list = g.run and g.run.market or 'field', {}
  for _, offer in ipairs(E.offers) do
    if not offer.sold or offer.sold == market then
      list[#list + 1] = offer
    end
  end
  return list
end
local function find(g, id)
  for _, offer in ipairs(E.offersFor(g)) do
    if offer.id == id then
      return offer
    end
  end
end
function E.describe(g, id)
  local offer = find(g, id)
  if not offer then
    return '', ''
  end
  local kind = E.kinds[offer.kind]
  if kind.describe then
    return kind.describe(g, offer, (W.inHand(g)))
  end
  return Text.get(offer.name), Text.get(offer.description)
end
-- Every ability's uses are whole and within its capacity.
local function validUses(p)
  for id, state in pairs(p.abilityState) do
    local uses = state.uses
    if
      type(uses) ~= 'number'
      or uses < 0
      or uses > Abilities.capacity(id, state)
      or uses ~= math.floor(uses)
    then
      return false
    end
  end
  return true
end
local function validState(g)
  local r, p = g.run, Roles.controlled(g)
  return W.validAmmo(g)
    and type(r.wallet) == 'number'
    and r.wallet >= 0
    and r.wallet <= Shop.maxWallet
    and r.wallet == math.floor(r.wallet)
    and type(p.armor) == 'number'
    and p.armor == p.armor
    and p.armor >= 0
    and p.armor <= Shop.maxWard
    and validUses(p)
end
function E.quote(g, id)
  local r = g.run
  if not r then
    return nil, Text.get('shop_no_run')
  end
  if not validState(g) then
    return nil, Text.get('shop_invalid')
  end
  local offer = find(g, id)
  if not offer then
    return nil, Text.get('shop_unknown')
  end
  -- final: the kind's answer stands even when the wallet could not pay.
  local price, reason, final = E.kinds[offer.kind].quote(g, offer, (W.inHand(g)))
  if reason or final then
    return price, reason
  end
  if r.wallet < price then
    return price, Text.get('shop_missing', { souls = price - r.wallet })
  end
  return price, nil
end
-- The shop button's text: the kind's state (full, equipped) or the price.
function E.label(g, id)
  local offer = find(g, id)
  local price = E.quote(g, id)
  local kind = E.kinds[offer.kind]
  return kind.label and kind.label(g, offer, price)
    or Text.get('shop_price', { price = price or 0 })
end
function E.buy(g, id)
  local r = g.run
  if not r or g.state ~= 'shop' then
    return false, Text.get('shop_closed')
  end
  local price, reason = E.quote(g, id)
  if reason or not price then
    return false, reason
  end
  local offer = find(g, id)
  local kind = E.kinds[offer.kind]
  r.wallet = r.wallet - price
  kind.apply(g, offer, (W.inHand(g)))
  return true, Text.get(kind.done or 'shop_bought')
end
-- A purchase and its notice (any mode with a wallet).
function E.trade(g, id)
  local ok, reason = E.buy(g, id)
  if ok then
    Presentation.cue(g, 'pickup', Shop.boughtCue)
    g.shopMessage = Text.get('run_bought', { souls = g.run.wallet })
  else
    g.shopMessage = reason
  end
  return ok
end
return E
