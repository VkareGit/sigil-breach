-- What can lie on the floor to be taken: its painted icon and size. What taking
-- it does is an entry of session/interactions.lua, or of the mode that owns it.
local Registry = require('src.core.registry')
local Supplies = Registry:new('supplies')
Supplies:register('health', { icon = 'health', size = 0.48 })
-- A pack for a weapon the creatures drop (run/drops.lua) is painted as its own rounds (Codex,
-- assets/art/pickups): shells and revolver rounds differ by shape, not only by colour.
-- light: how much of the chapel's light a painted pack takes (render/world_art.lua).
Supplies:register('ammo', {
  icon = 'ammo',
  size = 0.48,
  -- Linen and cartridge bases reflect the chapel light; no emission or halo.
  light = 1.25,
  -- Transparent rows below the painted contact shadow, as a share of height.
  footInset = { exorcist = 25 / 256, judge = 12 / 256 },
  images = {
    exorcist = 'assets/art/pickups/ammo_shells.png',
    judge = 'assets/art/pickups/ammo_rounds.png',
  },
})
Supplies:register('soul', { icon = 'soul', size = 0.42 })
-- A draught for the flask lying about (0.42): the flask's painted icon until it has its own.
Supplies:register('flask', {
  icon = 'health',
  size = 0.42,
  light = 0.85,
  image = 'assets/art/icons/flask.png',
})
-- A relic found in the chapel (0.43, D8): a sigil shows its painted seal (assets/art/sigils),
-- an engraving its icon of the shop (by the offer it is), until Codex paints relics of their own.
Supplies:register('relic', {
  icon = 'choke',
  size = 0.46,
  light = 0.95,
  images = {
    sigil_stolas = 'assets/art/sigils/stolas-1904.png',
    sigil_buer = 'assets/art/sigils/buer-1904.png',
    sigil_furfur = 'assets/art/sigils/furfur-1904.png',
  },
  icons = { choke = 'choke', pierce = 'pierce', breaker = 'armor', precision = 'choke' },
})
return Supplies
