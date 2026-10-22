-- The Ember's trade (0.24, Strategy): the offers are content (content/shop.lua),
-- each of a kind that says how it is priced, when it is unavailable and what
-- it gives. A new kind of offer (equipment, a relic, a base upgrade) is a new
-- entry in E.kinds; quote, buy and the shop screen do not change.
--   quote(g, offer, def) -> price, reason   (reason: why it cannot be bought)
--   apply(g, offer, def)                     gives the purchase
--   label(g, offer, price) -> text or nil    the button when not a price
--   describe(g, offer, def) -> name, text    optional, else the offer's own
--   done                                     the message after a purchase
local W = require('src.content.weapons')
local Shop = require('src.content.shop')
local Abilities = require('src.content.abilities')
local E = {}
E.offers = Shop.offers
local function missing(g, def)
  return def.maxReserve - W.state(g).reserve
end
local function describeRounds(g, offer, def)
  local n = math.max(0, math.min(def.packSize, missing(g, def)))
  local quantity = n == 0 and 'AMMO PACK' or (n .. (n == 1 and ' ROUND' or ' ROUNDS'))
  return offer.id == 'ammo' and (quantity .. ' / ' .. def.name) or ('REFILL / ' .. def.name),
    def.unitPrice
      .. ' souls per round. Reserve cap: '
      .. def.maxReserve
      .. '. Pay for missing rounds.'
end
local function roundsFull(g)
  local _, reserve = W.ammo(g)
  return reserve >= W.inHand(g).maxReserve and 'RESERVE FULL' or nil
end
-- Rounds for the weapon in hand, by count: a pack, or everything missing.
local function rounds(count, fill)
  return {
    quote = function(g, _, def)
      local n = count(g, def)
      local price = n * def.unitPrice
      if n <= 0 then
        return price, 'Reserve full.'
      end
      return price
    end,
    apply = function(g, _, def)
      local state = W.state(g)
      state.reserve = fill and def.maxReserve
        or math.min(def.maxReserve, state.reserve + def.packSize)
    end,
    label = roundsFull,
    describe = describeRounds,
  }
end
E.kinds = {
  rounds = rounds(function(g, def)
    return math.min(def.packSize, missing(g, def))
  end, false),
  refill = rounds(missing, true),
  ward = {
    quote = function(g, offer)
      local armor = g.player.armor
      local price =
        math.ceil(math.min(offer.amount, Shop.maxWard - armor) * offer.price / offer.amount)
      if armor >= Shop.maxWard then
        return 0, 'Ward full.'
      end
      return price
    end,
    apply = function(g, offer)
      g.player.armor = math.min(Shop.maxWard, g.player.armor + offer.amount)
    end,
    label = function(g)
      return g.player.armor >= Shop.maxWard and 'WARD FULL' or nil
    end,
  },
  charge = {
    quote = function(g, offer)
      local state, def = g.player.abilityState[offer.ability], Abilities:get(offer.ability)
      if state.uses >= def.capacity then
        return 0, 'Charges full.'
      end
      return offer.price
    end,
    apply = function(g, offer)
      local state = g.player.abilityState[offer.ability]
      state.uses = state.uses + 1
    end,
    label = function(g, offer)
      local state = g.player.abilityState[offer.ability]
      return (state.uses or 0) >= Abilities:get(offer.ability).capacity and 'RESERVE FULL' or nil
    end,
  },
  -- An engraving is bought once; owned, it is equipped for free.
  engraving = {
    quote = function(g, offer)
      local r = g.run
      if r.owned[offer.id] then
        return 0, r.glyph == offer.id and 'Equipped.' or nil, true
      end
      return offer.price
    end,
    apply = function(g, offer)
      g.run.owned[offer.id] = true
      g.run.glyph = offer.id
    end,
    label = function(g, offer)
      local r = g.run
      return r.owned[offer.id] and (r.glyph == offer.id and 'EQUIPPED' or 'EQUIP / FREE') or nil
    end,
    done = 'Engraving equipped.',
  },
}
local function find(id)
  for _, offer in ipairs(E.offers) do
    if offer.id == id then
      return offer
    end
  end
end
function E.describe(g, id)
  local offer = find(id)
  if not offer then
    return '', ''
  end
  local kind = E.kinds[offer.kind]
  if kind.describe then
    return kind.describe(g, offer, (W.inHand(g)))
  end
  return offer.name, offer.description
end
-- Every ability's uses are whole and within its capacity.
local function validUses(p)
  for id, state in pairs(p.abilityState) do
    local uses = state.uses
    if
      type(uses) ~= 'number'
      or uses < 0
      or uses > Abilities:get(id).capacity
      or uses ~= math.floor(uses)
    then
      return false
    end
  end
  return true
end
local function validState(g)
  local r, p = g.run, g.player
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
    return nil, 'No expedition.'
  end
  if not validState(g) then
    return nil, 'Invalid resource state.'
  end
  local offer = find(id)
  if not offer then
    return nil, 'Unknown offer.'
  end
  -- final: the kind's answer stands even when the wallet could not pay.
  local price, reason, final = E.kinds[offer.kind].quote(g, offer, (W.inHand(g)))
  if reason or final then
    return price, reason
  end
  if r.wallet < price then
    return price, 'Missing ' .. (price - r.wallet) .. ' souls.'
  end
  return price, nil
end
-- The shop button's text: the kind's state (full, equipped) or the price.
function E.label(g, id)
  local offer = find(id)
  local price = E.quote(g, id)
  local kind = E.kinds[offer.kind]
  return kind.label and kind.label(g, offer, price) or ((price or 0) .. ' SOULS')
end
function E.buy(g, id)
  local r = g.run
  if not r or g.state ~= 'shop' or r.phase ~= 'preparing' then
    return false, 'Purchases are available at the Ember between waves.'
  end
  local price, reason = E.quote(g, id)
  if reason or not price then
    return false, reason
  end
  local offer = find(id)
  local kind = E.kinds[offer.kind]
  r.wallet = r.wallet - price
  kind.apply(g, offer, (W.inHand(g)))
  return true, kind.done or 'Purchased.'
end
return E
