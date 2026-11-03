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
  -- How many sigils a knight wears at once (0.43, D8: found in the chapel, worn at a fire).
  sigilSlots = 2,
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
    -- An engraving belongs to one weapon (weapon: its id; its effect is that weapon's glyph,
    -- content/weapons.lua). Each weapon wears one at a time; owned ones change hands for free.
    {
      id = 'choke',
      -- 0.43 (owner, D8): found in the chapel, never sold at a fire (the proving ground sells it).
      found = true,
      icon = 'choke',
      short = 'offer_choke_short',
      kind = 'engraving',
      weapon = 'exorcist',
      name = 'offer_choke',
      price = 180,
      description = 'offer_choke_text',
    },
    {
      id = 'pierce',
      -- 0.43 (owner, D8): found in the chapel, never sold at a fire (the proving ground sells it).
      found = true,
      icon = 'pierce',
      short = 'offer_pierce_short',
      kind = 'engraving',
      weapon = 'exorcist',
      name = 'offer_pierce',
      price = 220,
      description = 'offer_pierce_text',
    },
    -- 0.42 (owner and Astra: the basic gun grows too): the Judge's own engravings.
    {
      id = 'breaker',
      -- 0.43 (owner, D8): found in the chapel, never sold at a fire (the proving ground sells it).
      found = true,
      icon = 'armor',
      short = 'offer_breaker_short',
      kind = 'engraving',
      weapon = 'judge',
      name = 'offer_breaker',
      price = 180,
      description = 'offer_breaker_text',
    },
    {
      id = 'precision',
      -- 0.43 (owner, D8): found in the chapel, never sold at a fire (the proving ground sells it).
      found = true,
      icon = 'choke',
      short = 'offer_precision_short',
      kind = 'engraving',
      weapon = 'judge',
      name = 'offer_precision',
      price = 220,
      description = 'offer_precision_text',
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
    -- 0.42 (Astra's fire plan): fewer ranks that each change a fight; the vow of the ward is
    -- gone (it doubled vigour and was not felt), a save that kept it drops it.
    {
      id = 'vow_flask',
      icon = 'vow_flask',
      sold = 'fire',
      kind = 'vow',
      name = 'offer_vow_flask',
      description = 'offer_vow_flask_text',
      -- 0.43 (D8): souls buy the vows only, priced for one way through the chapel (1420).
      price = 150,
      growth = 2.25,
      limit = 2,
      ability = 'flask',
      amount = 1,
    },
    {
      id = 'vow_vigor',
      icon = 'vow_vigour',
      sold = 'fire',
      kind = 'vow',
      name = 'offer_vow_vigor',
      description = 'offer_vow_vigor_text',
      price = 120,
      growth = 2.25,
      limit = 2,
      stat = 'maxHp',
      amount = 15,
    },
    -- Sigils of the Goetia (0.42, a first three to try the kind; docs/WIZJA.md,
    -- Kierunek hybrydy): up to three copies each, each copy stronger. A sigil
    -- names a glyph of one gun (as tempering does) or a trait of the knight with its value at
    -- each rank (ranks), which a rest and a purchase set (run/pilgrimage.lua: swear).
    {
      id = 'sigil_stolas',
      icon = 'sigil_stolas',
      sold = 'fire',
      kind = 'sigil',
      found = true,
      name = 'offer_sigil_stolas',
      description = 'offer_sigil_stolas_text',
      limit = 3,
      weapon = 'judge',
      glyph = 'sigil_stolas',
    },
    {
      id = 'sigil_buer',
      icon = 'sigil_buer',
      sold = 'fire',
      kind = 'sigil',
      found = true,
      name = 'offer_sigil_buer',
      description = 'offer_sigil_buer_text',
      limit = 3,
      trait = 'rallyRate',
      ranks = { 0.08, 0.10, 0.12 },
    },
    {
      id = 'sigil_furfur',
      icon = 'sigil_furfur',
      sold = 'fire',
      kind = 'sigil',
      found = true,
      name = 'offer_sigil_furfur',
      description = 'offer_sigil_furfur_text',
      limit = 3,
      trait = 'dodgeEdge',
      ranks = { 0.35, 0.5, 0.65 },
    },
    -- Tempering: each rank is the weapon's glyph once more (glyph: its id in that weapon's
    -- glyphs, and in no other's), so the gun hits harder for good; From's reinforced weapons.
    {
      id = 'temper_judge',
      icon = 'ammo',
      sold = 'fire',
      kind = 'vow',
      name = 'offer_temper_judge',
      description = 'offer_temper_text',
      price = 250,
      growth = 2,
      limit = 1,
      weapon = 'judge',
      glyph = 'temper_judge',
    },
    {
      id = 'temper_exorcist',
      icon = 'ammo',
      sold = 'fire',
      kind = 'vow',
      name = 'offer_temper_exorcist',
      description = 'offer_temper_text',
      price = 250,
      growth = 2,
      limit = 1,
      weapon = 'exorcist',
      glyph = 'temper_exorcist',
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
