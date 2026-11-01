-- The offers at a fire. Each offer names a kind (run/economy.lua
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
      sold = 'field',
      kind = 'rounds',
      name = 'offer_ammo',
      price = 12,
      description = 'offer_ammo_text',
    },
    {
      id = 'fill',
      icon = 'ammo',
      sold = 'field',
      kind = 'refill',
      name = 'offer_fill',
      description = 'offer_fill_text',
    },
    {
      id = 'armor',
      icon = 'armor',
      sold = 'field',
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
      sold = 'field',
      kind = 'charge',
      ability = 'powder',
      name = 'offer_charge',
      price = 30,
      description = 'offer_charge_text',
    },
    -- A vow is kept for good, in ranks: each costs growth times the one before. A rest fills
    -- what a fire can fill, so a fire sells nothing else that a rest would take back.
    {
      id = 'vow_flask',
      icon = 'ammo',
      sold = 'fire',
      kind = 'vow',
      name = 'offer_vow_flask',
      description = 'offer_vow_flask_text',
      price = 150,
      growth = 2,
      limit = 3,
      ability = 'flask',
      amount = 1,
    },
    {
      id = 'vow_ward',
      icon = 'armor',
      sold = 'fire',
      kind = 'vow',
      name = 'offer_vow_ward',
      description = 'offer_vow_ward_text',
      price = 120,
      growth = 2,
      limit = 3,
      stat = 'maxArmor',
      amount = 10,
    },
    {
      id = 'vow_vigor',
      icon = 'armor',
      sold = 'fire',
      kind = 'vow',
      name = 'offer_vow_vigor',
      description = 'offer_vow_vigor_text',
      price = 120,
      growth = 2,
      limit = 3,
      stat = 'maxHp',
      amount = 10,
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
function Shop.find(id)
  for _, offer in ipairs(Shop.offers) do
    if offer.id == id then
      return offer
    end
  end
end
function Shop.get(id)
  return Shop.find(id) or error('unknown shop offer: ' .. tostring(id), 2)
end
return Shop
