-- The Ember's offers between waves. Each offer names a kind (run/economy.lua
-- E.kinds: how it is priced, what it gives); a new offer of a known kind is
-- a new entry here, a new kind of offer is a new entry there. name,
-- description, short: text keys (content/text.lua).
local Shop = {
  -- A wallet beyond this is a corrupted save, not a purchase.
  maxWallet = 1000000,
  -- The ward (consumable shield) is mended up to maxWard.
  maxWard = 100,
  -- How loud a purchase is.
  boughtCue = 0.35,
  offers = {
    {
      id = 'ammo',
      icon = 'ammo',
      kind = 'rounds',
      name = 'offer_ammo',
      price = 12,
      description = 'offer_ammo_text',
    },
    {
      id = 'fill',
      icon = 'ammo',
      kind = 'refill',
      name = 'offer_fill',
      description = 'offer_fill_text',
    },
    {
      id = 'armor',
      icon = 'armor',
      kind = 'ward',
      name = 'offer_armor',
      -- amount of ward for price; a partial mend costs its share (rounded up).
      amount = 25,
      price = 35,
      description = 'offer_armor_text',
    },
    {
      id = 'choke',
      icon = 'choke',
      short = 'offer_choke_short',
      kind = 'engraving',
      name = 'offer_choke',
      price = 100,
      description = 'offer_choke_text',
    },
    {
      id = 'pierce',
      icon = 'pierce',
      short = 'offer_pierce_short',
      kind = 'engraving',
      name = 'offer_pierce',
      price = 100,
      description = 'offer_pierce_text',
    },
    {
      id = 'charge',
      icon = 'ammo',
      kind = 'charge',
      ability = 'powder',
      name = 'offer_charge',
      price = 30,
      description = 'offer_charge_text',
    },
  },
}
-- A new offer, and one leaving with the mod that brought it.
function Shop.define(offer)
  Shop.offers[#Shop.offers + 1] = offer
  return offer
end
function Shop.undefine(id)
  for index, offer in ipairs(Shop.offers) do
    if offer.id == id then
      return table.remove(Shop.offers, index)
    end
  end
end
function Shop.get(id)
  for _, offer in ipairs(Shop.offers) do
    if offer.id == id then
      return offer
    end
  end
  error('unknown shop offer: ' .. tostring(id), 2)
end
return Shop
