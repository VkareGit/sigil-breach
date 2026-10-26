-- Every body of a fight under one set of questions (plan v10 V2): knights
-- and creatures, whatever their side. Which side a body is on, who is
-- hostile to whom, which bodies a means of harm reaches, where a body stood
-- when the step began (continuous contact) and its vertical extent.
-- Order is deterministic: knights (pool order), then creatures (pool order).
local Pools = require('src.session.world')
local Archetypes = require('src.content.enemies')
local Factions = require('src.content.factions')
local Rules = require('src.combat.rules')
local Roles = require('src.core.roles')
local Bodies = {}
local knightBody = Archetypes.player.body
-- The knight this session's player controls (core/roles.lua).
Bodies.controlled = Roles.controlled
function Bodies.isKnight(g, b)
  return b == Roles.controlled(g) or b.prefab == 'knight'
end
function Bodies.side(g, b)
  if b.faction then
    return b.faction
  end
  if Bodies.isKnight(g, b) then
    return 'knight'
  end
  local def = (b.archetype or b.kind) and Archetypes.of(b)
  return def and def.faction or 'demons'
end
function Bodies.hostile(g, a, b)
  return Factions.hostile(Bodies.side(g, a), Bodies.side(g, b))
end
-- Whether harm by means from side reaches body b (content/factions.lua).
function Bodies.harms(g, side, b, means)
  return Factions.harms(side, Bodies.side(g, b), means)
end
-- Every knight: the pool, which always holds the controlled one. A session
-- whose g.player was replaced outside the pool (a hand-made fixture) has
-- only him.
local alone = {}
function Bodies.knights(g)
  local list = Pools.of(g, 'knights')
  for i = 1, #list do
    if list[i] == Roles.controlled(g) then
      return list
    end
  end
  alone[1] = Roles.controlled(g)
  return alone
end
-- visit(b) for every living body, knights first; stops when visit returns
-- true and returns that body.
function Bodies.each(g, visit)
  for _, k in ipairs(Bodies.knights(g)) do
    -- A hand-made knight without health counts as standing.
    if (k.hp or 1) > 0 and visit(k) then
      return k
    end
  end
  for _, e in ipairs(Pools.of(g, 'enemies')) do
    if e.hp > 0 and visit(e) then
      return e
    end
  end
end
-- Where body b stood when this step began (sweeps interpolate from it): the
-- knights' step snapshot (systems/knight.lua), else the body as it is now.
function Bodies.previous(g, b)
  local frame = g.frame
  if not frame then
    return b
  end
  if b == Roles.controlled(g) then
    return frame.previousPlayer or b
  end
  local knights = frame.previousKnights
  return knights and knights[b.id] or b
end
-- The swept point of body b for a contact test: x, z, height above its
-- floor (jump) and crouch. A knight is its own record; a creature's leap
-- is its jump.
function Bodies.sweep(g, b, out)
  if b.jump ~= nil or Bodies.isKnight(g, b) then
    return b
  end
  out = out or {}
  out.x, out.z, out.jump, out.crouch, out.level = b.x, b.z, b.leapY or 0, 0, b.level
  return out
end
-- Radius, feet clearance and standing height of body b's contact volume.
function Bodies.extent(g, b)
  if Bodies.isKnight(g, b) then
    return knightBody.radius, knightBody.feet, knightBody.height
  end
  local low, high = Rules.interval(g, b)
  return Rules.radius(b), 0, high - low
end
return Bodies
