-- The rules of the world: one resolution for every body that can be hurt,
-- the player included. Data lives in src/content/enemies.lua; the full written
-- description is game/SYSTEM-SWIATA-0.14.txt. Inspired by tabletop systems:
-- D&D (damage types, resistance/vulnerability/immunity, conditions with a
-- duration), Warhammer (armour points per location, flat Toughness soak,
-- mass), Call of Cthulhu (a single hit taking a large share of the body
-- is a major wound that breaks the creature regardless of its guard).
--
-- Facade (0.24): this table is the only entry point; the rules live in parts
-- by responsibility under src/combat/rules/. Every part installs its
-- functions on R, so callers keep one stable API (Rules.react, Rules.guard...).
local R = {}
require('src.combat.rules.body')(R)
require('src.combat.rules.conditions')(R)
require('src.combat.rules.spawning')(R)
require('src.combat.rules.impulse')(R)
require('src.combat.rules.balance')(R)
require('src.combat.rules.hit_response')(R)
require('src.combat.rules.contact')(R)
require('src.combat.rules.knight')(R)
return R
