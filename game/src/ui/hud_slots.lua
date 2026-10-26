-- What the HUD shows of the knight's kit, as slot declarations (plan v10
-- V6): the drawing lists the slots, it never counts weapons or names keys.
-- The arsenal shows N weapons in a well of rows, scrolling around the one in
-- hand; the equipment shows every slot the bindings give a key to
-- (app/bindings.lua: Q, F, C...). The shipped kit (two guns, the powder
-- charge on Q) gives the 0.30 layout.
local Weapons = require('src.content.weapons')
local Abilities = require('src.content.abilities')
local Bindings = require('src.app.bindings')
local Slots = {}
-- The weapons a well of rows shows: the one in hand and its neighbours
-- ({ slot, def, selected }), and how many the knight carries.
function Slots.weapons(g, rows)
  local count = Weapons.count(g)
  local inHand = Weapons.slot(g)
  local first = math.max(1, math.min(inHand - 1, count - rows + 1))
  local list = {}
  for row = 0, math.min(rows, count) - 1 do
    local slot = first + row
    list[#list + 1] = { slot = slot, def = Weapons.profile(slot, g), selected = inHand == slot }
  end
  return list, count
end
-- Every equipment slot with a key: { slot, key, def, uses } (def nil when the
-- slot is empty). The first is always listed, so an empty kit still shows
-- its key.
function Slots.equipment(g)
  local list = {}
  for slot, key in ipairs(Bindings.abilities) do
    local def, state = Abilities.slot(g, slot)
    if def or slot == 1 then
      list[#list + 1] = {
        slot = slot,
        key = string.upper(key),
        def = def,
        uses = state and state.uses or 0,
        capacity = def and def.capacity or 1,
      }
    end
  end
  return list
end
return Slots
