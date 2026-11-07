-- The pads of the proving ground: [E] spawns a demon, takes a weapon or refills, with
-- the normal test-field spawning (src/run/test_field.lua). They are drawn in render/gallery.lua.
local Weapons = require('src.content.weapons')
local Field = require('src.run.test_field')
local Arena = require('src.world.arena')
local Archetypes = require('src.content.enemies')
local Roles = require('src.core.roles')
local Text = require('src.content.text')
local G = {}
local empty = {}
local ProvingPads = require('src.world.proving_pads')
function G.padsFor(world)
  return ProvingPads.forWorld(world) or empty
end
local function dist(a, x, z)
  return math.sqrt((a.x - x) ^ 2 + (a.z - z) ^ 2)
end
local function padLabel(p)
  if p.trial then
    return Text.get(
      'gallery_pad_trial',
      { name = string.upper(Text.get(Archetypes.get(p.spawn).name)) }
    )
  end
  if p.spawn then
    return Text.get(
      'gallery_pad_spawn',
      { name = string.upper(Text.get(Archetypes.get(p.spawn).name)) }
    )
  end
  if p.weapon then
    return Text.get('gallery_pad_take', { name = Text.get(Weapons.get(p.weapon).name) })
  end
  return Text.get('gallery_pad_refill')
end
G.padLabel = padLabel
function G.nearestPad(g)
  local best, d = nil, math.huge
  for _, p in ipairs(G.padsFor(g.world)) do
    local dp = dist(Roles.controlled(g), p.x, p.z)
    if
      dp < (p.reach or 1.05)
      and dp < d
      and Arena.visible(g.world, Roles.controlled(g).x, Roles.controlled(g).z, p.x, p.z)
    then
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
  if p.trial then
    return Field.chamber(g, p.trial, 1)
  end
  if p.spawn then
    return Field.spawn(g, p.spawn, 1) ~= nil
  end
  if p.weapon then
    local slot = Weapons.slotOf(g, p.weapon)
    if slot then
      g:switchWeapon(slot)
    end
    g:notify(Text.get('gallery_in_hand', { name = Text.get(Weapons.get(p.weapon).name) }), 2)
    return true
  end
  return Field.refill(g)
end
return G
