-- Body: the physical and combat body under the rules, the same schema for
-- every demon and for the knight (content/defs/knight.lua extends it).
-- Defaults are the common case; a creature states only what differs.
local Schema = require('src.core.schema')
local Body = {}
Body.fields = {
  hp = { type = 'number', required = true, min = 1, desc = 'health' },
  armor = { type = 'number', default = 0, min = 0, desc = 'armour rating (100 halves physical)' },
  soak = { type = 'number', default = 0, min = 0, desc = 'flat reduction per hit (Toughness)' },
  resist = { type = 'table', default = {}, desc = 'per damage type: >0 resist, <0 vulnerable' },
  immune = { type = 'table', desc = 'set of damage types that never wound' },
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
  aimY = { type = 'number', default = 1.1, desc = 'height aimed at by explosives (m)' },
  blood = { type = 'table', default = { 0.26, 0.025, 0.016 }, desc = 'blood colour' },
  struck = { type = 'string', default = 'flesh', values = { 'flesh', 'metal', 'bone' } },
  boss = { type = 'boolean', desc = 'falters instead of being interrupted' },
  microStun = { type = 'number', min = 0, desc = 'boss: brief stun of a heavy unbroken blow' },
}
Body.schema = Schema:new('body', Body.fields)
-- A neutral body for records without an archetype (fixtures, catalogue).
Body.neutral = Body.schema:build({ hp = 1, woundAt = 1 })
return Body
