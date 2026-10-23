-- The proving ground as a gallery of everything in the game (test field only):
--  * statues of every demon in the altar, breathing with their idle cycle;
--  * boards with every active texture atlas, grouped by use (world, weapons,
--    effects, interface, demons), each with a name plate;
--  * pads on the nave floor: [E] spawns a demon, takes a weapon or refills.
-- Statues and boards are pure presentation: no collision, no AI, never hit
-- by shots. Pads use the normal test-field spawning (src/run/test_field.lua).
-- This is the layout; the art and its drawing are render/gallery.lua.
local W = require('src.world.arena')
local Archetypes = require('src.content.enemies')
local G = {}
local function dist(a, x, z)
  return math.sqrt((a.x - x) ^ 2 + (a.z - z) ^ 2)
end
-- Hall slots: west court (world, weapons), east court (effects, interface),
-- altar back row (demon atlases). Slots inside walls, pillars or a seal's
-- circle are skipped when the gallery is laid out.
local halls = {
  WORLD = { xs = { 4.1, 6.5 }, zs = { 11, 12.9, 20.6, 22.4 } },
  WEAPONS = { xs = { 4.1, 6.5 }, zs = { 14.8, 18.8 } },
  EFFECTS = { xs = { 26, 28 }, zs = { 11, 12.9 } },
  INTERFACE = { xs = { 26, 28 }, zs = { 14.8, 18.8, 20.6, 22.4 } },
  DEMONS = { xs = { 9.2, 11.5, 14, 18, 20.5, 22.8 }, zs = { 3.3 } },
}
-- Pad places on the nave floor: the demons' (west column, then east), the
-- weapons' and the refill. What stands on them is the content's: the demons
-- in their proving-ground order (catalog.field), the default loadout.
local demonPads = {
  { 10.2, 20.6 },
  { 10.2, 23.1 },
  { 10.2, 25.8 },
  { 21.8, 20.6 },
  { 21.8, 23.1 },
  { 21.8, 25.8 },
}
local weaponPads = { { 13.4, 28.6 }, { 18.6, 28.6 } }
local refillPad = { 16, 28.9 }
-- One statue per listed demon (id: its creature; kind: its atlas and AI).
G.statues, G.pads = {}, {}
for i, def in ipairs(Archetypes.listed('field')) do
  G.statues[i] = { id = def.id, kind = def.kind }
  local at = demonPads[i]
  if at then
    G.pads[#G.pads + 1] = { x = at[1], z = at[2], spawn = def.id }
  end
end
for i, id in ipairs(require('src.content.weapons').defaultLoadout) do
  local at = weaponPads[i]
  if at then
    G.pads[#G.pads + 1] = { x = at[1], z = at[2], weapon = id }
  end
end
G.pads[#G.pads + 1] = { x = refillPad[1], z = refillPad[2], refill = true }
-- boards: the exhibits to hang (render/gallery.lua owns the art list).
function G.layout(world, boards)
  local placed = {}
  for _, b in ipairs(boards) do
    b.x = nil
  end
  for group, hall in pairs(halls) do
    local slots = {}
    for _, z in ipairs(hall.zs) do
      for _, x in ipairs(hall.xs) do
        local free = not W.solid(world, x, z, 0.32)
        for _, s in ipairs(world.seals) do
          if (s.x - x) ^ 2 + (s.z - z) ^ 2 < 1.6 ^ 2 then
            free = false
          end
        end
        if free then
          slots[#slots + 1] = { x = x, z = z }
        end
      end
    end
    local i = 0
    for _, b in ipairs(boards) do
      if b.group == group then
        i = i + 1
        local s = slots[i]
        if s then
          b.x, b.z = s.x, s.z
          placed[#placed + 1] = b
        end
      end
    end
  end
  for i, s in ipairs(G.statues) do
    s.x = 9.6 + (i - 1) * 2.56
    s.z = 8.4
  end
  return placed
end
local function padLabel(p)
  if p.spawn then
    return '[E] SPAWN ' .. string.upper(Archetypes.get(p.spawn).name)
  end
  if p.weapon then
    return '[E] TAKE ' .. require('src.content.weapons').get(p.weapon).name
  end
  return '[E] REFILL HEALTH, WARD AND AMMO'
end
G.padLabel = padLabel
function G.nearestPad(g)
  local best, d = nil, 1.05
  for _, p in ipairs(G.pads) do
    local dp = dist(g.player, p.x, p.z)
    if dp < d then
      best, d = p, dp
    end
  end
  return best
end
function G.context(g)
  local p = G.nearestPad(g)
  return p and padLabel(p)
end
function G.interact(g)
  local p = G.nearestPad(g)
  if not p then
    return false
  end
  local Field = require('src.run.test_field')
  if p.spawn then
    return Field.spawn(g, p.spawn, 1) ~= nil
  end
  if p.weapon then
    local Weapons = require('src.content.weapons')
    local slot = Weapons.slotOf(g, p.weapon)
    if slot then
      g:switchWeapon(slot)
    end
    g:notify(Weapons.get(p.weapon).name .. ' in hand.', 2)
    return true
  end
  return Field.refill(g)
end
return G
