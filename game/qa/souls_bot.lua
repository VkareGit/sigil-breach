-- Two knights for the acceptance of the souls plan. They read only what a player
-- sees: the pose of a body, its windup, the marks on the floor, the missiles in
-- the air. Neither is a measure of human difficulty.
local B = require('src.combat.ballistics')
local Pools = require('src.session.world')
local Bot = {}
local function nearest(g)
  local p, best, bestD = g.player, nil, nil
  for _, e in ipairs(g.enemies) do
    if e.hp > 0 then
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
  -- Keep room: close enough for the guns, out of the reach of the blade.
  local keep = (e.attackSpec and e.attackSpec.kind == 'bolt') and 5 or 6.5
  input.forward = distance > keep + 1 and 1 or (distance < keep - 1 and -1 or 0)
  input.strafe = memory.side
  -- Rounds and health lying near are worth the walk.
  for _, pickup in ipairs(Pools.of(g, 'pickups')) do
    local d = math.sqrt((pickup.x - p.x) ^ 2 + (pickup.z - p.z) ^ 2)
    if d < 9 and (pickup.kind == 'ammo' or (pickup.kind == 'health' and p.hp < 80)) then
      input.forward, input.strafe = steer(p, pickup.x, pickup.z)
      break
    end
  end
  -- Shoot unless the body is about to answer: the openings are the rest.
  local busy = e.ai == 'windup' and e.windup + (e.holdLeft or 0) < 0.35
  input.shoot = not busy and distance < 11 and memory.clock % 3 == 0
  -- Blows of the body: a dodge across the line, at the last moment.
  for _, body in ipairs(g.enemies) do
    if body.hp > 0 and body.ai == 'windup' then
      local left = body.windup + (body.holdLeft or 0)
      local d = math.sqrt((body.x - p.x) ^ 2 + (body.z - p.z) ^ 2)
      local lands = body.attackSpec and body.attackSpec.kind == 'leap'
      if lands then
        d = math.sqrt((body.aimX - p.x) ^ 2 + (body.aimZ - p.z) ^ 2)
      end
      if left < 0.1 and d < threat(body) and not (body.attackSpec.kind == 'wave') then
        input.dash, input.strafe, input.forward = true, memory.side, 0
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
    input.dash = input.dash or (mark.delay or 0) < 0.25
  end
  local bolt = missile(g)
  if bolt then
    input.dash = true
    input.forward, input.strafe = 0, memory.side
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
Bot.origin = B.origin
return Bot
