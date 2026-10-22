-- Conditions: named states with a duration, the same for every body
-- (combat/rules/conditions.lua). Each scales speed and guard recovery while it
-- lasts; a new condition is a new entry.
--  staggered: cannot act (enemies) / slowed and unsteady (player)
--  wounded:   a major wound; slower for a while, the stagger lasts longer
--  poisoned:  standing in plague; the body recovers its guard and breath slower
--  crippled:  a leg blow (hit zones); the body limps for a while
--  exposed:   a boss whose guard broke; half armour (combat/damage.lua)
local define = require('src.content.defs.condition').define
return {
  staggered = define('staggered', { speed = 0.45 }),
  wounded = define('wounded', { speed = 0.72 }),
  poisoned = define('poisoned', { recovery = 0.5 }),
  crippled = define('crippled', { speed = 0.65 }),
  exposed = define('exposed', {}),
}
