-- Archetypes of the world: every creature is DATA read by one set of rules
-- (src/combat/rules.lua). Nothing in the simulation asks "is this an imp?"; it asks
-- the body, the movement style and the attack list. Full description:
-- game/docs/SYSTEM-SWIATA-0.14.txt.
--
-- Registry (0.24): one file per creature in src/content/creatures/, the
-- knight's body in content/knight.lua, the shared rule constants in
-- content/combat_defaults.lua and the conditions in content/conditions.lua.
-- This module gathers them under one stable API (A.imp, A.player,
-- A.defaults, A.conditions, A.get, A.each). A new demon is a creature file,
-- its id in A.creatures and its atlas.
--
-- body:   hp, armor (rating, Warhammer-style armour points), soak (flat
--         reduction per hit, Warhammer Toughness), resist (D&D: >0 resist,
--         <0 vulnerable), immune (set of damage types), mass, poise (stagger
--         threshold), woundAt (Call of Cthulhu "major wound": one hit taking
--         at least this fraction of max HP breaks the creature), radius,
--         blood colour, struck material, explosive aim height, boss flag,
--         optional stability, locationArmor, stagger tiers and brace.
-- move:   speed, acceleration and style (enemies/ai.lua: AI.styles).
-- attacks: ordered list; the first whose range and cadence fit is used.
--          kind: a registered attack kind (enemies/actions.lua: Attacks.kinds).
--          packet: the damage the attack delivers (same rules as the player).
local A = {}
-- Every creature a session can spawn, in catalogue order. The content schema
-- test fails if a creature file is missing from this list.
A.creatures = { 'imp', 'stolas', 'buer', 'armored', 'boss', 'furfur' }
A.imp = require('src.content.creatures.imp')
A.stolas = require('src.content.creatures.stolas')
A.buer = require('src.content.creatures.buer')
A.armored = require('src.content.creatures.armored')
A.boss = require('src.content.creatures.boss')
A.furfur = require('src.content.creatures.furfur')
-- The player is a body under the same rules.
A.player = require('src.content.knight')
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
