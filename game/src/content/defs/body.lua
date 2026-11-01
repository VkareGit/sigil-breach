-- Body: the physical and combat body under the rules, the same schema for
-- every demon and for the knight (content/defs/knight.lua extends it).
-- Defaults are the common case; a creature states only what differs.
local Schema = require('src.core.schema')
local Types = require('src.content.damage_types')
local Body = {}
Body.fields = {
  hp = { type = 'number', required = true, min = 1, desc = 'health' },
  armor = { type = 'number', default = 0, min = 0, desc = 'armour rating (100 halves physical)' },
  soak = { type = 'number', default = 0, min = 0, desc = 'flat reduction per hit (Toughness)' },
  resist = {
    type = 'table',
    default = {},
    check = Types.keysProblem,
    desc = 'per damage type: >0 resist, <0 vulnerable',
  },
  immune = {
    type = 'table',
    check = Types.keysProblem,
    desc = 'set of damage types that never wound',
  },
  locationArmor = { type = 'table', desc = 'armour per hit zone (weak points)' },
  zones = { type = 'table', desc = 'own hit-zone multipliers (default: combat_defaults.zones)' },
  mass = { type = 'number', default = 1, min = 0.05, desc = 'kg-like mass for impulses' },
  poise = { type = 'number', default = 36, min = 1, desc = 'guard: impact to break the stance' },
  woundAt = {
    type = 'number',
    default = 0.45,
    min = 0,
    max = 1,
    desc = 'share of max HP one hit must take for a major wound',
  },
  stability = { type = 'number', min = 0.05, desc = 'balance-time divisor (default sqrt(mass))' },
  brace = { type = 'number', min = 0, max = 1, desc = 'share of a shove kept in a light falter' },
  stagger = { type = 'table', desc = 'own light/heavy stagger tiers' },
  regenDelay = { type = 'number', min = 0, desc = 'own guard regeneration delay' },
  regenRate = { type = 'number', min = 0, desc = 'own guard regeneration rate (share/s)' },
  drag = { type = 'number', min = 0, desc = 'own friction against a shove (1/s)' },
  radius = { type = 'number', default = 0.25, min = 0.05, desc = 'collision footprint (m)' },
  height = {
    type = 'number',
    min = 0.05,
    desc = 'coarse movement separation height (m); else its painted body as posed',
  },
  aimY = { type = 'number', default = 1.1, desc = 'height aimed at by explosives (m)' },
  eye = {
    type = 'number',
    min = 0,
    desc = 'where its sight starts above its feet (m); else its painted head as posed',
  },
  blood = { type = 'table', default = { 0.26, 0.025, 0.016 }, desc = 'blood colour' },
  struck = { type = 'string', default = 'flesh', values = { 'flesh', 'metal', 'bone' } },
  boss = { type = 'boolean', desc = 'falters instead of being interrupted' },
  -- A killed body (plan v11 E1): its own numbers, not its painting's.
  corpse = {
    type = 'table',
    default = {},
    schema = Schema:new('corpse', {
      settle = {
        type = 'number',
        default = 0.33,
        min = 0,
        desc = 'shortest settling (s): a falling body shields until then and on the floor',
      },
      landing = {
        type = 'number',
        default = 0.14,
        min = 0,
        desc = 'when a collapsing body strikes the floor (s after death)',
      },
    }),
    desc = 'how its killed body settles (enemies/corpse.lua)',
  },
  microStun = { type = 'number', min = 0, desc = 'boss: brief stun of a heavy unbroken blow' },
}
Body.schema = Schema:new('body', Body.fields)
-- A neutral body for records without an archetype (fixtures, catalogue). It
-- has no painting to stand in, so it states its movement height.
Body.neutral = Body.schema:build({ hp = 1, woundAt = 1, height = 2.2 })
return Body
