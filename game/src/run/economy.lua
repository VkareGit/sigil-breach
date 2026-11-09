local Modes = require('src.session.modes')
local Way = require('src.content.pilgrimage')
local Tuning = require('src.content.tuning')
local SigilRules = require('src.content.sigils')
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
local Weapons = require('src.content.weapons')
local Ammo = require('src.content.ammo.index')
local Shop = require('src.content.shop')
local Abilities = require('src.content.abilities')
local Roles = require('src.core.roles')
local Text = require('src.content.text')
local Signal = require('src.session.signal')
local E = {}
E.offers = Shop.offers
function E.preview(g, id)
  local offer = Shop.get(id)
  local r = g.run
  if offer.kind == 'weapon' then
    return Text.get('shop_weapon_change')
  elseif offer.kind == 'vow' then
    local rank = r.vows[offer.id] or 0
    if offer.weapon then
      local base = Weapons.get(offer.weapon).attack.base
      local factor = Tuning.temperDamage
      return Text.get('shop_temper_change', {
        before = string.format('%.1f', base * factor ^ rank),
        after = string.format('%.1f', base * factor ^ math.min(offer.limit, rank + 1)),
      })
    end
    local p = Roles.controlled(g)
    local before = offer.stat and p[offer.stat]
      or Abilities.capacity(offer.ability, p.abilityState[offer.ability])
    return Text.get(
      'shop_vow_change',
      { before = before, after = before + (rank < offer.limit and offer.amount or 0) }
    )
  elseif offer.kind == 'sigil' then
    local before = r.sigils and r.sigils[id] or 0
    return Text.get('shop_sigil_change', {
      before = before,
      after = math.min(offer.limit, before + 1),
      found = r.vows[id] or 0,
      cost = E.sigilCost(id, math.min(offer.limit, before + 1)),
    })
  elseif offer.kind == 'engraving' then
    local current = r.worn and r.worn[offer.weapon]
    return Text.get('shop_engraving_change', {
      before = current and Text.get(Shop.get(current).name) or Text.get('shop_plain'),
      after = Text.get(offer.name),
    })
  end
  return Text.get(offer.description)
end
-- Whether an engraving is the one worn: on its weapon when the run keeps one per weapon.
function E.worn(r, offer)
  if r.worn and offer.weapon then
    return r.worn[offer.weapon] == offer.id
  end
  return r.glyph == offer.id
end
-- Equipped copies, never the collection's rank. A missing set wears nothing.
function E.wearing(r, offer)
  return (r.sigils and r.sigils[offer.id] or 0) > 0
end
function E.sigilCost(id, copies)
  local def = SigilRules[id]
  return copies > 0 and def.costs[copies] or 0
end
function E.sigilsWorn(r)
  local count = 0
  for id, copies in pairs(r.sigils or {}) do
    count = count + E.sigilCost(id, copies)
  end
  return count
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
  return Weapons.room(def, Weapons.state(g))
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
  return missing(g, Weapons.inHand(g)) <= 0 and Text.get('shop_reserve_full') or nil
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
      Weapons.refill(def, Weapons.state(g), fill and missing(g, def) or pack)
    end,
    label = roundsFull,
    describe = describeRounds,
  }
end
E.kinds = {
  weapon = {
    quote = function(g, offer)
      if Weapons.slotOf(g, offer.weapon) then
        return 0, Text.get('shop_weapon_owned'), true
      end
      return offer.price
    end,
    apply = function(g, offer)
      Weapons.give(g, offer.weapon)
      Weapons.stock(g, offer.weapon, Way.carried[offer.weapon])
    end,
    label = function(g, offer)
      return Weapons.slotOf(g, offer.weapon) and Text.get('shop_weapon_owned') or nil
    end,
  },
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
      -- Souls are whole, including the price of a later rank.
      return math.ceil(offer.price * offer.growth ^ rank)
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
  -- Each click equips one collected copy. Removing has its own explicit action.
  sigil = {
    quote = function(g, offer)
      local r = g.run
      local copies = r.sigils and r.sigils[offer.id] or 0
      if (r.vows[offer.id] or 0) <= copies then
        return 0, Text.get('shop_sigil_no_copy'), true
      end
      local capacity = E.sigilsWorn(r)
        - E.sigilCost(offer.id, copies)
        + E.sigilCost(offer.id, copies + 1)
      if capacity > Shop.sigilSlots then
        return 0, Text.get('shop_sigil_slots_reason', { slots = Shop.sigilSlots }), true
      end
      return 0, nil, true
    end,
    apply = function(g, offer)
      g.run.sigils = g.run.sigils or {}
      g.run.sigils[offer.id] = (g.run.sigils[offer.id] or 0) + 1
    end,
    label = function(g, offer)
      local copies = g.run.sigils and g.run.sigils[offer.id] or 0
      if copies >= (g.run.vows[offer.id] or 0) then
        return Text.get('shop_sigil_no_spare')
      end
      local _, reason = E.kinds.sigil.quote(g, offer)
      if reason then
        return Text.get('shop_sigil_full')
      end
      return Text.get('shop_sigil_add')
    end,
    done = 'shop_sigil_done',
  },
}
-- What is on sale here. A fire and the field fill a knight differently, so they sell
-- different things; an offer that names no market is sold in both.
-- 0.43 (D8): at a fire what is found in the chapel shows only once it was found.
local function found(r, offer)
  if offer.kind == 'sigil' then
    return (r.vows[offer.id] or 0) > 0
  end
  return r.owned[offer.id] == true
end
function E.offersFor(g)
  local market, list = g.run and g.run.market or 'field', {}
  for _, offer in ipairs(E.offers) do
    if
      (not offer.sold or offer.sold == market)
      and not (
        market ~= 'field'
        and offer.found
        and offer.kind ~= 'sigil'
        and not found(g.run, offer)
      )
    then
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
    return kind.describe(g, offer, (Weapons.inHand(g)))
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
  return Weapons.validAmmo(g)
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
  local price, reason, final = E.kinds[offer.kind].quote(g, offer, (Weapons.inHand(g)))
  if offer.weapon and offer.kind ~= 'weapon' and not Weapons.slotOf(g, offer.weapon) then
    return price,
      Text.get('shop_weapon_needed', { weapon = Text.get(Weapons.get(offer.weapon).hud.tab) })
  end
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
  if r.market == Shop.markets.fire and not Modes.act(g, 'canTrade') then
    return false, Text.get('shop_closed')
  end
  local price, reason = E.quote(g, id)
  if reason or not price then
    return false, reason
  end
  local offer = find(g, id)
  local kind = E.kinds[offer.kind]
  r.wallet = r.wallet - price
  kind.apply(g, offer, (Weapons.inHand(g)))
  return true, Text.get(kind.done or 'shop_bought')
end
-- A purchase and its notice (any mode with a wallet).
function E.trade(g, id)
  local ok, reason = E.buy(g, id)
  if ok then
    Signal(g, 'Bought', { offer = id })
    g.shopMessage = Text.get('run_bought', { souls = g.run.wallet })
  else
    g.shopMessage = reason
  end
  return ok
end
function E.unequip(g, id)
  local r, offer = g.run, Shop.find(id)
  if
    not r
    or g.state ~= 'shop'
    or r.market ~= Shop.markets.fire
    or not Modes.act(g, 'canTrade')
    or not offer
    or offer.kind ~= 'sigil'
    or not E.wearing(r, offer)
  then
    return false
  end
  local copies = r.sigils[id] - 1
  r.sigils[id] = copies > 0 and copies or nil
  return true
end
return E
