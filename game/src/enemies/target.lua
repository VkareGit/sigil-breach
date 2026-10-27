-- Whom a creature fights (plan v10 V2). e.target holds the id of that body;
-- a strategy chooses among living bodies of a hostile side (the creature's
-- move.targeting, default 'nearest'). The choice is renewed on the sight
-- clock (enemies/ai.lua: perceive) and whenever the target is gone. With no
-- living hostile body left, the first knight stands in, as in 0.32 (a dead
-- knight is still where the demons look until the fight stops).
local Pools = require('src.session.world')
local Bodies = require('src.combat.bodies')
local Archetypes = require('src.content.enemies')
local Target = {}
-- name -> function(g, e): a living hostile body or nil.
Target.strategies = {}
-- The nearest living body of a hostile side (ties: knights first, pool order).
function Target.strategies.nearest(g, e)
  local best, bestD
  Bodies.each(g, function(b)
    if b ~= e and Bodies.hostile(g, e, b) then
      local dx, dz = b.x - e.x, b.z - e.z
      local d = dx * dx + dz * dz
      if not best or d < bestD then
        best, bestD = b, d
      end
    end
  end)
  return best
end
local function strategy(e)
  local def = (e.archetype or e.kind) and Archetypes.of(e)
  local name = def and def.move and def.move.targeting or 'nearest'
  local select = Target.strategies[name]
  assert(type(select) == 'function', 'unknown targeting strategy ' .. tostring(name))
  return select
end
local function standIn(g)
  return Bodies.knights(g)[1]
end
-- Choose anew and remember it.
function Target.choose(g, e)
  local t = strategy(e)(g, e)
  e.target = t and t.id or nil
  return t or standIn(g)
end
-- The body e fights now: its remembered target while that one lives and is
-- hostile, else a new choice.
function Target.of(g, e)
  local id = e.target
  if id ~= nil then
    local t = Pools.get(g, id)
    if t and t.hp > 0 and t ~= e and Bodies.hostile(g, e, t) then
      return t
    end
  end
  return Target.choose(g, e)
end
return Target
