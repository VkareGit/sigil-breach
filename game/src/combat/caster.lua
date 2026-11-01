-- Where an action starts from and who answers for it, so one kind of action
-- serves a creature, an actor and a point in the world.
--   body        the body acting, if one is
--   owner, side who answers for it (content/factions.lua)
--   x, y, z     its origin; mx, my, mz: the mouth a missile leaves
--   dx, dy, dz  its aim; rise / run: the climb of that aim
local B = require('src.combat.ballistics')
local Bodies = require('src.combat.bodies')
local Reach = require('src.content.combat_defaults').attacks.muzzle
local Caster = {}
local function along(c, reach)
  c.mx, c.my, c.mz = c.x + c.dx * reach, c.y + c.dy * reach, c.z + c.dz * reach
  c.rise, c.run = c.dy, 1
  return c
end
-- A knight, from the eye along the aim.
function Caster.actor(g, actor)
  local x, y, z = B.origin(g, actor)
  local dx, dy, dz = B.direction(actor.yaw, actor.pitch)
  return along({
    body = actor,
    owner = actor.id,
    side = Bodies.side(g, actor),
    x = x,
    y = y,
    z = z,
    dx = dx,
    dy = dy,
    dz = dz,
  }, Reach)
end
-- A place in the world, on behalf of a body.
function Caster.point(g, body, x, y, z)
  local dx, dy, dz = B.direction(body.yaw or 0, body.pitch or 0)
  return along({
    owner = body.id,
    side = Bodies.side(g, body),
    x = x,
    y = y,
    z = z,
    dx = dx,
    dy = dy,
    dz = dz,
  }, 0)
end
return Caster
