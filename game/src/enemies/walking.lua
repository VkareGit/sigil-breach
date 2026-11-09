-- How a creature walks: a physical stride toward a point, and the route to one it cannot
-- see. What it wants to reach is the business of enemies/ai.lua.
local Kinematics = require('src.physics.kinematics')
local Archetypes = require('src.content.enemies')
local MathX = require('src.core.mathx')
local Arena = require('src.world.arena')
local Rules = require('src.combat.rules')
local Ground = require('src.physics.ground')
local WorldNavigation = require('src.world.navigation')
local Walking = {}
local len = MathX.len
-- The velocity a stride hands the walls (reused; read back at once).
local stride = { vx = 0, vz = 0 }
local radius = Rules.radius
local Walk = Archetypes.defaults.walk
local function arch(e)
  return Rules.archetype(e)
end
-- Walking is physical (0.21): the body accelerates toward its walking
-- velocity at accel / sqrt(mass), so heavy demons start and turn later and
-- a knocked body regains its stride. Arrival slows within braking distance.
local function move(g, e, tx, tz, speed, dt)
  local dx, dz = tx - e.x, tz - e.z
  local d = len(dx, dz)
  if d < Walk.arrive then
    return
  end
  dx, dz = dx / d, dz / d
  local defaults = Archetypes.defaults
  local accel = ((arch(e).move or {}).accel or defaults.accel) / math.sqrt(Rules.body(e).mass or 1)
  local stage = Archetypes.phase(e)
  speed = speed * Rules.speedScale(e) * (stage and stage.speed or 1)
  speed = math.min(speed, math.sqrt(2 * accel * defaults.brake * d))
  -- A body that stopped walking (attack, stagger, idle) starts again at rest.
  local now = g.elapsed or 0
  local vx, vz = e.walkVX or 0, e.walkVZ or 0
  if not e.walkAt or now - e.walkAt > dt * Walk.resume then
    vx, vz = 0, 0
  end
  e.walkAt = now
  local rate = accel * ((vx * dx + vz * dz) < 0 and defaults.brake or 1)
  local fromX, fromZ = vx, vz
  local active
  vx, vz, active = Kinematics.steer(vx, vz, dx * speed, dz * speed, rate, dt)
  local mx, mz = Kinematics.travel(fromX, fromZ, vx, vz, active, dt)
  local ox, oz = e.x, e.z
  -- The stride's own velocity, projected by the walls as the knight's is
  -- (world/arena.lua: move): what it travelled is not what it moves at.
  stride.vx, stride.vz = vx, vz
  Arena.move(g.world, e, mx, mz, radius(e), stride, Rules.tall(g, e))
  e.walkVX, e.walkVZ = stride.vx, stride.vz
  local moved = len(e.x - ox, e.z - oz)
  e.walk = e.walk + moved
  e.walkSpeed = moved / math.max(dt, 1e-3)
  if moved < speed * dt * Walk.stuckShare then
    e.blocked = (e.blocked or 0) + dt
  else
    e.blocked = 0
  end
  if (e.blocked or 0) > Walk.stuckTime then
    e.side = -e.side
    e.decision = Walk.sideHold
    e.blocked = 0
  end
end
-- The four neighbouring cells a route may step to, in the order they are tried.
local steps = { { 0, -1 }, { 0, 1 }, { 1, 0 }, { -1, 0 } }
-- level (optional): the surface of the goal on a world with decks; the route
-- runs over the walk graph's nodes (cells, and decks above them).
local function route(g, e, tx, tz, dt, level)
  local w = g.world
  local tall = Rules.tall(g, e)
  -- A straight walk is tried only toward a near goal, and asked again only every lineCheck s:
  -- the trial moves a probe through every cell on the way, and many bodies going home at once
  -- made a single step cost whole seconds (0.42). A far goal is reached down the field, whose
  -- lookahead still cuts straight across.
  e.lineTimer = (e.lineTimer or 0) - dt
  if len(tx - e.x, tz - e.z) > Walk.straight then
    e.lineClear, e.lineTimer = false, 0
  elseif e.lineTimer <= 0 then
    e.lineTimer = Walk.lineCheck
    e.lineClear = Arena.visible(w, e.x, e.z, tx, tz, nil, nil, e.level, level)
      and (not w.elevations or Arena.clear(w, e.x, e.z, tx, tz, radius(e), e.level, tall, level))
  end
  if e.lineClear then
    move(g, e, tx, tz, e.speed, dt)
    return
  end
  local class = Arena.class(radius(e), tall)
  e.pathTimer = (e.pathTimer or 0) - dt
  if e.pathTimer <= 0 or not e.path then
    e.path = Arena.flow(w, tx, tz, class, level)
    e.pathTimer = Walk.replan
  end
  -- The next node down the distance field from a node (nil at the goal).
  local function downhill(x, z, layer)
    local here = w.decks and Arena.level(w, x, z, layer)
    local best, bx, bz, bl = e.path[Arena.node(w, x, z, layer)] or 1e9, nil, nil, nil
    for _, o in ipairs(steps) do
      local nx, nz = x + o[1], z + o[2]
      local nl = 0
      if here then
        nl = Arena.step(w, nx, nz, here, class)
      end
      local d = nl and e.path[Arena.node(w, nx, nz, nl)]
      if d and d < best and not Arena.solid(w, nx, nz, radius(e)) then
        best = d
        bx, bz, bl = nx, nz, nl
      end
    end
    return bx, bz, bl
  end
  -- Walk toward the furthest cell of the route the body can reach in a
  -- straight line (0.25): no zigzag from cell centre to cell centre.
  local x, z = math.floor(e.x + 0.5), math.floor(e.z + 0.5)
  local layer = w.decks and Arena.layer(w, x, z, Ground.of(w, e) - (w.floor or 0)) or 0
  local bx, bz, bl = downhill(x, z, layer)
  if not bx then
    -- Beyond the exact field around the goal (plan v10 V3): cross region by
    -- region toward it (world/navigation.lua).
    if WorldNavigation.beyond(e.x, e.z, tx, tz) then
      local wx, wz = WorldNavigation.waypoint(w, e.x, e.z, tx, tz, class, e.level, level)
      if wx then
        move(g, e, wx, wz, e.speed, dt)
      end
    end
    return
  end
  local cx, cz, cl = bx, bz, bl
  for _ = 2, Walk.lookahead do
    cx, cz, cl = downhill(cx, cz, cl)
    if
      not cx
      or not Arena.clear(
        w,
        e.x,
        e.z,
        cx,
        cz,
        radius(e),
        e.level,
        tall,
        w.decks and Arena.level(w, cx, cz, cl) + (w.floor or 0)
      )
    then
      break
    end
    bx, bz = cx, cz
  end
  move(g, e, bx, bz, e.speed, dt)
end
Walking.move, Walking.route = move, route
return Walking
