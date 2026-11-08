-- Archetypes of the world: every creature is DATA read by one set of rules
-- (src/combat/rules.lua). Nothing in the simulation asks "is this an imp?"; it asks
-- the body, the movement style and the attack list. Full description:
-- docs/WIZJA.md (System świata 0.14).
--
-- Registry (0.24): one package per creature in src/content/creatures/<id>/
-- (PLAN F4; its definition is the package's init.lua), the
-- knight's body in content/knight.lua, the shared rule constants in
-- content/combat_defaults.lua and the conditions in content/conditions.lua.
-- This module gathers them under one stable API (A.register, A.defaults,
-- A.conditions, A.get, A.each). A new demon is a creature package and its
-- A.register.
--
-- body:   hp, armor (rating, Warhammer-style armour points), soak (flat
--         reduction per hit, Warhammer Toughness), resist (D&D: >0 resist,
--         <0 vulnerable), immune (set of damage types), mass, poise (stagger
--         threshold), woundAt (Call of Cthulhu "major wound": one hit taking
--         at least this fraction of max HP breaks the creature), radius,
--         blood colour, struck material, explosive aim height, boss flag,
--         optional stability, locationArmor, stagger tiers and brace.
-- move:   speed, acceleration and style (enemies/styles.lua).
-- attacks: ordered list; the first whose range and cadence fit is used.
--          kind: a registered attack kind (combat/action_kinds.lua).
--          packet: the damage the attack delivers (same rules as the player).
local A = {}
-- Every creature a session can spawn, in catalogue order: the ids registered.
A.creatures = {}
-- A new creature enters here, from a file of its own or from a mod.
function A.register(def)
  assert(A[def.id] == nil, 'creature already registered or reserved: ' .. tostring(def.id))
  A[def.id] = def
  A.creatures[#A.creatures + 1] = def.id
  return def
end
function A.unregister(id)
  A[id] = nil
  for i, known in ipairs(A.creatures) do
    if known == id then
      table.remove(A.creatures, i)
      break
    end
  end
end
A.register(require('src.content.creatures.imp'))
A.register(require('src.content.creatures.stolas'))
A.register(require('src.content.creatures.buer'))
A.register(require('src.content.creatures.armored'))
A.register(require('src.content.creatures.boss'))
A.register(require('src.content.creatures.furfur'))
A.defaults = require('src.content.combat_defaults')
A.conditions = require('src.content.conditions')
function A.each()
  local i = 0
  return function()
    i = i + 1
    local id = A.creatures[i]
    if id then
      return id, A[id]
    end
  end
end
-- The creatures listed under a catalog key ('field', 'bestiary'), in the
-- order their definitions give (content/defs/creature.lua: catalog). Every
-- screen and place that lists demons asks here; two at one place is an error.
function A.listed(key)
  local out, taken = {}, {}
  local function place(def)
    local entry = def.catalog[key]
    return type(entry) == 'table' and entry.order or entry
  end
  for _, def in A.each() do
    local at = place(def)
    if at then
      assert(not taken[at], 'two creatures listed at ' .. key .. ' ' .. at)
      taken[at] = true
      out[#out + 1] = def
    end
  end
  table.sort(out, function(a, b)
    return place(a) < place(b)
  end)
  return out
end
-- The definition of a body in play (its own, else by kind and variant).
function A.of(e)
  return e.archetype or A.get(e.kind, e.variant)
end
function A.phase(e)
  local def = A.of(e)
  return def and def.phases and def.phases[e.phaseIndex or 1]
end
function A.furious(e)
  return (e.phaseIndex or 1) > 1 or e.hp < e.maxHp * A.defaults.attacks.rageAt
end
-- How a body in play looks (its creature's appearance; a neutral look for a
-- record of no known creature, e.g. a hand-made test body).
A.neutralLook = require('src.content.defs.creature').appearance:build({ portal = { 0.65, 0.4, 1 } })
function A.look(e)
  local def = A.of(e)
  return def and def.appearance or A.neutralLook
end
function A.get(kind, variant)
  if variant and A[variant] then
    return A[variant]
  end
  return A[kind]
end
return A
