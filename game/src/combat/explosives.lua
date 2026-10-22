-- Limited physical ordnance: fuse, wall sweep and blast share simulation time.
local Signal = require('src.session.signal')
local Spawn = require('src.session.spawn')
local MathX = require('src.core.mathx')
local B = require('src.combat.ballistics')
local D = require('src.combat.damage')
local Tuning = require('src.content.tuning')
local Collision = require('src.physics.collision')
local Ground = require('src.physics.ground')
local chest = require('src.content.combat_defaults').missiles.chest
local heights = Collision.heights
-- The behaviour of the 'throw' delivery; the powder charge itself is data
-- (content/abilities.lua: powder), in the same format as demon attacks.
local Abilities = require('src.content.abilities')
local function defaultAction()
  return Abilities:get('powder').action
end
local K = Tuning.explosives
-- Legacy inspection values; flight and blast read the action of each charge.
local X = { radius = defaultAction().radius, fuse = defaultAction().fuse }
local function clear(g, b, x, y, z)
  local dx, dy, dz = x - b.x, y - b.y, z - b.z
  local d = math.sqrt(dx * dx + dy * dy + dz * dz)
  if d < 0.001 then
    return true, d
  end
  local hit, _, kind = B.world(g.world, b.x, b.y, b.z, dx / d, dy / d, dz / d, d)
  return kind == 'range' or hit >= d - 1e-5, d
end
-- The 'throw' delivery: a charge leaves the eye along the aim (gates and
-- uses are the caster's: combat/abilities.lua).
function X.launch(g, action)
  action = action or defaultAction()
  -- Every throw uses the same gravity, scaled from its authored reference.
  local throwScale = math.sqrt(Tuning.gravity / action.referenceGravity)
  local throwSpeed, throwLift = action.speed * throwScale, action.lift * throwScale
  local p = g.player
  local x, y, z = B.origin(g)
  local dx, dy, dz = B.direction(p.yaw, p.pitch)
  local spawn = B.world(g.world, x, y, z, dx, dy, dz, K.spawnReach)
  spawn = math.max(0, spawn - K.spawnClearance)
  g.charges = g.charges or {}
  Spawn.make(g, 'charge', {
    action = action,
    x = x + dx * spawn,
    y = y + dy * spawn,
    z = z + dz * spawn,
    vx = dx * throwSpeed,
    vy = dy * throwSpeed + throwLift,
    vz = dz * throwSpeed,
    fuse = action.fuse,
    maxFuse = action.fuse,
    spin = 0,
  })
  Signal(g, 'ChargeThrown', {})
  require('src.enemies.ai').noise(g, p.x, p.z, action.noise)
  return true
end
function X.explode(g, b)
  local action = b.action or defaultAction()
  local report =
    { targets = 0, kills = 0, healthDamage = 0, blocked = 0, impact = 0, selfDamage = 0 }
  local ground = Ground.height(g.world)
  for _, e in ipairs(g.enemies) do
    if e.hp > 0 then
      local y = ground + (require('src.combat.rules').body(e).aimY or Tuning.explosives.aimHeight)
      local visible, d = clear(g, b, e.x, y, e.z)
      if visible and d < action.radius then
        local dealt, blocked, impact = D.resolve(action.blast, e, d)
        local health = math.min(e.hp, dealt)
        g:damageEnemy(e, dealt, 'charge')
        require('src.combat.combat').react(
          g,
          e,
          impact,
          true,
          { e.x, y, e.z },
          nil,
          health,
          nil,
          { value = health, kill = e.hp <= 0 }
        )
        report.targets = report.targets + 1
        report.kills = report.kills + (e.hp <= 0 and 1 or 0)
        report.healthDamage = report.healthDamage + health
        report.blocked = report.blocked + blocked
        report.impact = report.impact + impact
      end
    end
  end
  local p = g.player
  -- The blast meets the knight at his chest, as a missile does (0.25).
  local visible, d = clear(g, b, p.x, ground + chest + p.jump - (p.crouch or 0), p.z)
  if visible and d < action.radius then
    local before = p.hp
    local own = action.selfBlast
    local f = D.falloff(d, own.falloffStart, own.falloffEnd, own.minPower)
    -- source 'self': the knight's own charge is never a perfect dodge.
    g:damagePlayer(
      own.base * f,
      b.x,
      b.z,
      { base = own.base * f, impact = own.impact * f, damageType = own.damageType },
      'self'
    )
    report.selfDamage = math.max(0, before - p.hp)
  end
  g.explosionReport = report
  Signal(g, 'ChargeExploded', { charge = b })
  require('src.enemies.ai').noise(g, b.x, b.z, Tuning.explosives.blastNoise)
end
-- Solve constant-acceleration flight at contact time. End-of-tick velocity
-- shortened throws; resolving only one contact discarded the rest of each tick.
local gravity, floorHeight, skin = Tuning.gravity, Tuning.floorSurface, 1e-5
-- Resistance per second on the floor, never per rendered frame.
local groundDrag = K.groundDrag
local finite = MathX.finite
local function flightY(b, t, acceleration)
  return b.y + b.vy * t - 0.5 * acceleration * t * t
end
local function descendingCrossing(b, height, acceleration)
  if acceleration == 0 then
    return b.vy < 0 and (height - b.y) / b.vy or math.huge
  end
  local d = b.vy * b.vy + 2 * acceleration * (b.y - height)
  if d < 0 then
    return math.huge
  end
  local root = math.sqrt(d)
  if b.vy < 0 and b.y >= height then
    return 2 * (b.y - height) / (root - b.vy)
  end
  return (b.vy + root) / acceleration
end
local function solidAt(w, x, z, y)
  local tile = w.map[z] and w.map[z][x]
  return (not tile and y <= heights.outside) or (tile and tile > 0 and y <= Collision.top(tile))
end
local function sweep(w, b, duration, acceleration)
  local hit, nx, ny, nz = duration, nil, nil, nil
  if not b.grounded then
    local floor = descendingCrossing(b, floorHeight, acceleration)
    if floor >= -1e-9 and floor <= hit then
      hit, nx, ny, nz = math.max(0, floor), 0, 1, 0
    end
  end
  local cx, cz = math.floor(b.x + 0.5), math.floor(b.z + 0.5)
  local sx, sz = b.vx >= 0 and 1 or -1, b.vz >= 0 and 1 or -1
  local deltaX = math.abs(b.vx) > 1e-10 and 1 / math.abs(b.vx) or math.huge
  local deltaZ = math.abs(b.vz) > 1e-10 and 1 / math.abs(b.vz) or math.huge
  local nextX = deltaX < math.huge and (cx + sx * 0.5 - b.x) / b.vx or math.huge
  local nextZ = deltaZ < math.huge and (cz + sz * 0.5 - b.z) / b.vz or math.huge
  local entry, ex, ez = 0, 0, 0
  while entry <= hit do
    local leave = math.min(nextX, nextZ, hit)
    local tile = w.map[cz] and w.map[cz][cx]
    if b.grounded and b.y > floorHeight + skin * 2 then
      local support = (not tile or tile > 0) and Collision.top(tile) or floorHeight
      if support < b.y - skin * 2 then
        return entry, 0, 0, 0, 'edge'
      end
    end
    if not tile or tile > 0 then
      local height = Collision.top(tile)
      if flightY(b, entry, acceleration) <= height then
        return entry, ex, 0, ez
      end
      local top = descendingCrossing(b, height, acceleration)
      if top >= entry and top <= leave then
        return top, 0, 1, 0
      end
    end
    if nextX > hit and nextZ > hit then
      break
    end
    if math.abs(nextX - nextZ) < 1e-10 then
      local y = flightY(b, nextX, acceleration)
      local sideX, sideZ = solidAt(w, cx + sx, cz, y), solidAt(w, cx, cz + sz, y)
      if sideX or sideZ or solidAt(w, cx + sx, cz + sz, y) then
        if sideX and not sideZ then
          return nextX, -sx, 0, 0
        end
        if sideZ and not sideX then
          return nextX, 0, 0, -sz
        end
        return nextX, -sx / math.sqrt(2), 0, -sz / math.sqrt(2)
      end
      entry = nextX
      nextX = nextX + deltaX
      nextZ = nextZ + deltaZ
      cx, cz = cx + sx, cz + sz
      ex, ez = -sx / math.sqrt(2), -sz / math.sqrt(2)
    elseif nextX < nextZ then
      entry = nextX
      nextX = nextX + deltaX
      cx = cx + sx
      ex, ez = -sx, 0
    else
      entry = nextZ
      nextZ = nextZ + deltaZ
      cz = cz + sz
      ex, ez = 0, -sz
    end
  end
  return hit, nx, ny, nz
end
local function advance(w, b, duration)
  local remaining = duration
  local contacts = 0
  while remaining > 1e-9 do
    -- Analytic ground drag preserves a straight horizontal path. Effective travel
    -- time maps its collision time back to elapsed simulation seconds.
    local grounded = b.grounded
    local acceleration = grounded and 0 or gravity
    local travelTime = grounded and (1 - math.exp(-groundDrag * remaining)) / groundDrag
      or remaining
    local hit, nx, ny, nz, kind = sweep(w, b, travelTime, acceleration)
    local used = grounded and -math.log(math.max(1e-12, 1 - groundDrag * hit)) / groundDrag or hit
    used = math.min(remaining, math.max(0, used))
    b.x, b.y, b.z = b.x + b.vx * hit, flightY(b, hit, acceleration), b.z + b.vz * hit
    if grounded then
      local damp = math.exp(-groundDrag * used)
      b.vx, b.vz = b.vx * damp, b.vz * damp
    else
      b.vy = b.vy - gravity * used
    end
    remaining = remaining - used
    if not nx then
      break
    end
    contacts = contacts + 1
    if kind == 'edge' then
      b.grounded = false
      local speed = math.sqrt(b.vx * b.vx + b.vz * b.vz)
      if speed > 1e-10 then
        b.x, b.z = b.x + b.vx / speed * skin, b.z + b.vz / speed * skin
      end
    else
      if nx == 0 and ny == 0 and nz == 0 then
        b.vx, b.vy, b.vz = 0, 0, 0
        break
      end
      b.x, b.y, b.z = b.x + nx * skin, b.y + ny * skin, b.z + nz * skin
      local dot = b.vx * nx + b.vy * ny + b.vz * nz
      local K = Tuning.explosives
      if dot < 0 then
        b.vx = (b.vx - K.bounce * dot * nx) * K.keep
        b.vy = (b.vy - K.bounce * dot * ny) * K.keep
        b.vz = (b.vz - K.bounce * dot * nz) * K.keep
      end
      if ny == 1 and b.vy < K.settle then
        b.grounded = true
        b.vy = 0
      end
    end
    -- Bound pathological coincident-contact loops without tunnelling through walls.
    if contacts >= Tuning.explosives.maxContacts then
      b.vx, b.vy, b.vz = 0, 0, 0
      break
    end
  end
end
function X.update(g, dt)
  if not finite(dt) or dt <= 0 then
    return
  end
  local list = g.charges or {}
  for i = #list, 1, -1 do
    local b = list[i]
    if
      not (
        finite(b.x)
        and finite(b.y)
        and finite(b.z)
        and finite(b.vx)
        and finite(b.vy)
        and finite(b.vz)
        and finite(b.fuse)
      )
    then
      table.remove(list, i)
    else
      -- Its flight is solved in heights above the ground (physics/ground.lua).
      local ground = Ground.height(g.world)
      b.y = b.y - ground
      if b.y < floorHeight then
        b.y = floorHeight
      end
      local step = math.max(0, math.min(dt, b.fuse))
      b.fuse = math.max(0, b.fuse - step)
      b.spin = (b.spin or 0) + step * K.spin
      advance(g.world, b, step)
      b.y = b.y + ground
      if b.fuse <= 1e-9 then
        table.remove(list, i)
        X.explode(g, b)
        if g.state ~= 'playing' then
          break
        end
      end
    end
  end
end
return X
