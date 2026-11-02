-- What a creature leaves for the knight's guns (owner, D2; content: a creature's ammo). Each
-- family has its own rounds, so a player learns whom to hunt for what. A kill has a chance of a
-- small pack of slightly varying size; an execution, the risk of going in close, always pays a
-- modest one, kill or not; the hardest bodies always leave the rare shells of the strongest gun.
-- The rolls are the session's (g.rng.sim), so a journal replays the same drops.
local Archetypes = require('src.content.enemies')
local Rules = require('src.combat.rules')
local Roles = require('src.core.roles')
local Spawn = require('src.session.spawn')
local Drops = {}
-- A pack on the floor where the knight can take it: at the body's place, or, from one still
-- standing (whose bulk he cannot reach into), at his own feet, a step toward it.
local function lay(g, e, weapon, amount, standing)
  local x, z = e.x, e.z
  if standing then
    local p = Roles.controlled(g)
    local dx, dz = e.x - p.x, e.z - p.z
    local d = math.sqrt(dx * dx + dz * dz)
    local step = math.min(d, Rules.radius(p))
    x, z = p.x + (d > 1e-6 and dx / d * step or 0), p.z + (d > 1e-6 and dz / d * step or 0)
  end
  Spawn.make(g, 'pickup', {
    x = x,
    z = z,
    level = e.level,
    kind = 'ammo',
    weapon = weapon,
    amount = amount,
  })
end
-- A kill (EnemyKilled). An execution pays through Drops.executed, never twice.
function Drops.kill(g, event)
  local rule = Archetypes.of(event.enemy).ammo
  if not rule or event.source == 'execution' then
    return
  end
  local rng = g.rng.sim
  if rng:random() < rule.chance then
    local amount = rule.least + math.floor(rng:random() * (rule.most - rule.least + 1))
    lay(g, event.enemy, rule.weapon, math.min(rule.most, amount))
  end
end
-- An execution (Executed), whether the body falls or rises again.
function Drops.executed(g, event)
  local rule = Archetypes.of(event.enemy).ammo
  if rule then
    lay(g, event.enemy, rule.weapon, rule.executed, event.enemy.hp > 0)
  end
end
return Drops
