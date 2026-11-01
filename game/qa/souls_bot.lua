-- Two knights for the acceptance of the souls plan. They read only what a player
-- sees: the pose of a body, its windup, the marks on the floor, the missiles in
-- the air. Neither is a measure of human difficulty.
local B = require('src.combat.ballistics')
local Pools = require('src.session.world')
local Resources = require('src.combat.resources')
local Rules = require('src.combat.rules')
local World = require('src.world.arena')
local Bot = {}
local function nearest(g)
  local p, best, bestD = g.player, nil, nil
  for _, e in ipairs(g.enemies) do
    -- A body still at its post is no fight yet.
    if e.hp > 0 and (e.awake or not e.post) then
      local d = (e.x - p.x) ^ 2 + (e.z - p.z) ^ 2
      if not bestD or d < bestD then
        best, bestD = e, d
      end
    end
  end
  return best, bestD and math.sqrt(bestD)
end
local function aim(g, e)
  local p = g.player
  p.yaw = math.atan2(e.x - p.x, e.z - p.z)
  p.pitch = 0
end
-- Stands in the open and shoots.
function Bot.careless(g)
  local e = nearest(g)
  if not e then
    return {}
  end
  aim(g, e)
  return { shoot = true }
end
-- One habit for every blow: keep moving, shoot when it can, dodge sideways as each
-- windup ends. This is the knight the fight must not reward.
function Bot.reflex(g, memory)
  local p = g.player
  local e, distance = nearest(g)
  if not e then
    return {}
  end
  aim(g, e)
  memory.clock = (memory.clock or 0) + 1
  memory.side = memory.clock % 240 < 120 and 1 or -1
  local input = { strafe = memory.side }
  input.forward = distance > 5.6 and 1 or (distance < 3.6 and -1 or 0)
  input.shoot = (Resources.share(p, 'stamina') or 1) > 0.36
  if p.hp < 45 and not p.casting then
    g:cast(2)
  end
  for _, body in ipairs(g.enemies) do
    if body.hp > 0 and body.ai == 'windup' and body.windup < 0.1 then
      input.dash, input.forward = true, 0
    end
  end
  return input
end
-- The same habit with one fixed side: remembers a direction, reads nothing.
function Bot.oneSide(g, memory)
  local input = Bot.reflex(g, memory)
  input.strafe = 1
  return input
end
-- How far a committed blow of e can reach, and whether it asks for a jump.
local function threat(e)
  local spec = e.attackSpec
  if not spec then
    return 0
  end
  return (spec.reach or spec.contactRadius and spec.reach or spec.range or 0) + 1.2
end
-- The first floor mark about to go off under the knight: where it lies.
local function underfoot(g)
  local p = g.player
  for _, h in ipairs(Pools.of(g, 'hazards')) do
    local d = math.sqrt((h.x - p.x) ^ 2 + (h.z - p.z) ^ 2)
    if h.kind ~= 'wave' and h.kind ~= 'tempest' and h.kind ~= 'sweepline' then
      if d < h.radius + 0.9 and (h.delay or 0) < 0.8 then
        return h
      end
    end
  end
end
local function missile(g)
  local p = g.player
  for _, b in ipairs(Pools.of(g, 'projectiles')) do
    if b.side ~= 'knight' then
      local dx, dz = p.x - b.x, p.z - b.z
      local d = math.sqrt(dx * dx + dz * dz)
      local speed = math.sqrt(b.vx * b.vx + b.vz * b.vz)
      if d < 4.5 and (dx * b.vx + dz * b.vz) / math.max(1e-6, d * speed) > 0.9 then
        return b
      end
    end
  end
end
local function steer(p, x, z, away)
  -- Forward and strafe that walk toward (x, z), or away from it.
  local dx, dz = x - p.x, z - p.z
  local length = math.max(1e-6, math.sqrt(dx * dx + dz * dz))
  dx, dz = dx / length * (away and -1 or 1), dz / length * (away and -1 or 1)
  local fx, fz = math.sin(p.yaw), math.cos(p.yaw)
  return dx * fx + dz * fz, dx * fz - dz * fx
end
-- Whether nothing is about to land: the moment for a swallow.
local function quiet(g)
  for _, body in ipairs(g.enemies) do
    if body.hp > 0 and (body.ai == 'windup' or body.ai == 'strike') then
      return false
    end
  end
  return not missile(g) and not underfoot(g)
end
-- Learnt the tells: keeps its distance, shoots what is not about to strike, and
-- answers each kind of blow the way the blow can be answered.
function Bot.learning(g, memory)
  local p = g.player
  local e, distance = nearest(g)
  if not e then
    return {}
  end
  aim(g, e)
  -- The gun that has rounds and suits the distance.
  local arsenal = p.arsenal
  if arsenal and arsenal.exorcist and arsenal.judge then
    local near = arsenal.exorcist.mag + arsenal.exorcist.reserve > 0
    local far = arsenal.judge.mag + arsenal.judge.reserve > 0
    local empty = p.weapon == 1 and not near or p.weapon == 2 and not far
    local desired = (distance < 7 and near or not far) and 1 or 2
    memory.held = (memory.held or 0) + 1
    if
      desired ~= p.weapon
      and p.reload == 0
      and p.cooldown == 0
      and (empty or memory.held > 240)
    then
      g:switchWeapon(desired)
      memory.held = 0
    end
  end
  memory.side = memory.side or 1
  memory.clock = (memory.clock or 0) + 1
  if memory.clock % 300 == 0 then
    memory.side = -memory.side
  end
  local input = {}
  -- A broken guard is the moment everything was for.
  if Rules.has(e, 'exposed') and (e.stun or 0) > 0 and Rules.body(e).execution then
    if g:interact() then
      return input
    end
    input.forward, input.strafe = steer(p, e.x, e.z)
    return input
  end
  local effort = Resources.share(p, 'stamina') or 1
  -- Keep room: close enough for the guns, out of the reach of the blade.
  local keep = (e.attackSpec and e.attackSpec.kind == 'bolt') and 5 or 6.5
  if Rules.body(e).personal then
    keep = 4.6
  end
  input.forward = distance > keep + 1 and 1 or (distance < keep - 1 and -1 or 0)
  input.strafe = memory.side
  -- Drink when nothing is coming and the wound is worth it.
  if (p.hp < 40 or (p.hp < 70 and distance > 6)) and not p.casting and quiet(g) then
    g:cast(2)
  end
  -- Rounds and health lying near are worth the walk.
  for _, pickup in ipairs(Pools.of(g, 'pickups')) do
    local d = math.sqrt((pickup.x - p.x) ^ 2 + (pickup.z - p.z) ^ 2)
    if d < 9 and (pickup.kind == 'ammo' or (pickup.kind == 'health' and p.hp < 80)) then
      input.forward, input.strafe = steer(p, pickup.x, pickup.z)
      break
    end
  end
  -- Shoot unless the body is about to answer: the openings are the rest. A dodge
  -- must stay paid for.
  local busy = e.ai == 'windup' and e.windup + (e.holdLeft or 0) < 0.35
  local hardened = Rules.shell(e) < 1 or (e.attackSpec and e.attackSpec.parry and e.ai == 'windup')
  input.shoot = not busy
    and not hardened
    and distance < 11
    and memory.clock % 3 == 0
    and effort > 0.36
  -- Blows of the body: a dodge across the line, at the last moment.
  for _, body in ipairs(g.enemies) do
    if body.hp > 0 and body.ai == 'windup' then
      local left = body.windup + (body.holdLeft or 0)
      local d = math.sqrt((body.x - p.x) ^ 2 + (body.z - p.z) ^ 2)
      local lands = body.attackSpec and body.attackSpec.kind == 'leap'
      if lands then
        d = math.sqrt((body.aimX - p.x) ^ 2 + (body.aimZ - p.z) ^ 2)
      end
      local spec = body.attackSpec
      local trace = spec and spec.trace
      local low = trace and trace[1].height < 0.6 and trace[#trace].height < 0.6
      if spec and spec.parry and left <= spec.parry - 0.04 and d < 5.5 and p.cooldown == 0 then
        -- It can be turned aside: stand and shoot as it opens.
        input.shoot = true
      elseif low then
        input.jump = input.jump or (left < 0.16 and d < threat(body))
      elseif left < 0.1 and d < threat(body) and not (spec.kind == 'wave') then
        input.dash = effort > 0
        input.strafe, input.forward = memory.side, 0
        -- A swing is dodged through its blade, toward the side it comes from.
        if trace and spec.chase then
          local yaw = body.facing + trace[1].angle * (body.swingSide or 1)
          input.forward, input.strafe =
            steer(p, body.x + math.sin(yaw) * d, body.z + math.cos(yaw) * d)
        end
      end
    end
    -- A rush: across its line when it is about to arrive.
    if body.hp > 0 and body.ai == 'strike' and body.rushVX then
      local dx, dz = p.x - body.x, p.z - body.z
      local d = math.sqrt(dx * dx + dz * dz)
      local speed = math.sqrt(body.rushVX ^ 2 + body.rushVZ ^ 2)
      local toward = (dx * body.rushVX + dz * body.rushVZ) / math.max(1e-6, d * speed)
      if d < 3 + speed * 0.1 and toward > 0.7 then
        input.dash, input.forward, input.strafe = true, 0, memory.side
      end
    end
  end
  for _, h in ipairs(Pools.of(g, 'hazards')) do
    local d = math.sqrt((h.x - p.x) ^ 2 + (h.z - p.z) ^ 2)
    if h.kind == 'wave' and h.delay <= 0 then
      local gap = d - h.radius
      input.jump = input.jump or (gap > 0.3 and gap < 1.5)
    elseif h.kind == 'sweepline' then
      local dx, dz = p.x - h.x, p.z - h.z
      local off = math.atan2(dx, dz) - h.angle
      off = math.atan2(math.sin(off), math.cos(off))
      if d < h.radius + 1 and off * (h.spin < 0 and -1 or 1) > 0 then
        local left = off * (h.spin < 0 and -1 or 1) / math.abs(h.spin) + math.max(0, h.delay)
        if left < 0.12 then
          input.dash, input.forward, input.strafe = true, 0, memory.side
        end
      end
    end
  end
  local mark = underfoot(g)
  if mark then
    input.forward, input.strafe = steer(p, mark.x, mark.z, true)
    input.dash = input.dash or (mark.delay or 0) < 0.12
  end
  local bolt = missile(g)
  if bolt then
    input.dash = true
    input.forward, input.strafe = 0, memory.side
  end
  -- A ring closing around the knight: whoever stands still is left alone.
  local closing = 0
  for _, h in ipairs(Pools.of(g, 'hazards')) do
    closing = closing + ((h.delay or 0) > 0 and 1 or 0)
  end
  if closing >= 6 then
    input.forward, input.strafe, input.dash = 0, 0, false
  end
  -- The sky above everything: only the circle is safe.
  for _, h in ipairs(Pools.of(g, 'hazards')) do
    if h.kind == 'tempest' then
      input.forward, input.strafe = steer(p, h.x, h.z)
      input.dash = false
    end
  end
  -- Against stone: the other way along it.
  local moved = math.abs(p.x - (memory.x or 0)) + math.abs(p.z - (memory.z or 0))
  memory.x, memory.z = p.x, p.z
  memory.stuck = moved < 0.004 and (memory.stuck or 0) + 1 or 0
  if memory.stuck > 12 then
    memory.side, memory.stuck = -memory.side, 0
  end
  return input
end
-- A knight who knows the fight and still makes mistakes: with chance miss a blow goes
-- unanswered, the aim wanders about two degrees and a shot in three is lost. The
-- curve of wins over miss is the measure of difficulty (qa/README: souls curve).
function Bot.human(miss, roll)
  local misread, last, clock = false, -1, 0
  return function(g, memory)
    local input = Bot.learning(g, memory)
    local e = nearest(g)
    clock = clock + 1
    if e and e.ai == 'windup' and e.attackCount ~= last then
      last, misread = e.attackCount, roll() < miss
    end
    -- Nothing answers a blow it misread: no dodge, no jump, no shot in the parry's beat.
    if misread then
      input.dash, input.jump = false, false
      if e and e.ai == 'windup' and e.attackSpec and e.attackSpec.parry then
        input.shoot = false
      end
    end
    g.player.yaw = g.player.yaw + math.sin(clock * 0.09) * 0.035
    if input.shoot and roll() < 0.33 then
      input.shoot = false
    end
    return input
  end
end
-- The whole way (qa/README: pilgrim): walks a route of cells to where it is sent and
-- fights like Bot.human whatever turns on it. goal(g) names the next (x, z).
local function field(w, x, z)
  local steps, queue, head = { [z * 1000 + x] = 0 }, { { x, z } }, 1
  while queue[head] do
    local cell = queue[head]
    head = head + 1
    for _, step in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      local nx, nz = cell[1] + step[1], cell[2] + step[2]
      local key = nz * 1000 + nx
      if not steps[key] and not World.solid(w, nx, nz, 0.4) then
        steps[key] = steps[cell[2] * 1000 + cell[1]] + 1
        queue[#queue + 1] = { nx, nz }
      end
    end
  end
  return steps
end
function Bot.walker(fight)
  local routes = {}
  return function(g, memory, x, z)
    if nearest(g) then
      return fight(g, memory)
    end
    local p = g.player
    local key = x .. ':' .. z .. ':' .. g.world.geometryRevision
    routes[key] = routes[key] or field(g.world, math.floor(x + 0.5), math.floor(z + 0.5))
    local steps = routes[key]
    local cx, cz = math.floor(p.x + 0.5), math.floor(p.z + 0.5)
    local best, bx, bz = steps[cz * 1000 + cx] or 1e9, x, z
    for _, step in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      local d = steps[(cz + step[2]) * 1000 + cx + step[1]]
      if d and d < best then
        best, bx, bz = d, cx + step[1], cz + step[2]
      end
    end
    p.yaw, p.pitch = math.atan2(bx - p.x, bz - p.z), 0
    return { forward = 1 }
  end
end
Bot.origin = B.origin
return Bot
