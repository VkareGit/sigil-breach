-- The Ember's offers between waves. Each offer names a kind (run/economy.lua
-- E.kinds: how it is priced, what it gives); a new offer of a known kind is
-- a new entry here, a new kind of offer is a new entry there.
local Shop = {
  -- A wallet beyond this is a corrupted save, not a purchase.
  maxWallet = 1000000,
  -- The ward (consumable shield) is mended up to maxWard.
  maxWard = 100,
  offers = {
    {
      id = 'ammo',
      icon = 'ammo',
      kind = 'rounds',
      name = '4 SHELLS',
      price = 12,
      description = 'Two full Exorcist volleys. Reserve up to 72.',
    },
    {
      id = 'fill',
      icon = 'ammo',
      kind = 'refill',
      name = 'REFILL AMMO',
      description = 'Full reserve. You only pay for missing rounds.',
    },
    {
      id = 'armor',
      icon = 'armor',
      kind = 'ward',
      name = 'MEND +25 WARD',
      -- amount of ward for price; a partial mend costs its share (rounded up).
      amount = 25,
      price = 35,
      description = 'The ward absorbs 55% of a blow until spent.',
    },
    {
      id = 'choke',
      icon = 'choke',
      short = 'FOCUS',
      kind = 'engraving',
      name = 'ENGRAVING: FOCUS',
      price = 100,
      description = 'Spread 28% tighter. Fewer targets side by side.',
    },
    {
      id = 'pierce',
      icon = 'pierce',
      short = 'PIERCE',
      kind = 'engraving',
      name = 'ENGRAVING: PIERCE',
      price = 100,
      description = 'Ignores 60% of armour. 35% less impact.',
    },
    {
      id = 'charge',
      icon = 'ammo',
      kind = 'charge',
      ability = 'powder',
      name = 'POWDER CHARGE',
      price = 30,
      description = 'One charge. Throw [Q], 1 s fuse. Room for 3.',
    },
  },
}
function Shop.get(id)
  for _, offer in ipairs(Shop.offers) do
    if offer.id == id then
      return offer
    end
  end
  error('unknown shop offer: ' .. tostring(id), 2)
end
return Shop
