-- Sweep each projectile through the entire tick. Resolve the first event only.
local Signal = require('src.session.signal')
local MathX = require('src.core.mathx')
local B = require('src.combat.ballistics')
local Ground = require('src.physics.ground')
local SphereCast = require('src.physics.sphere_cast')
local floorSurface = require('src.content.tuning').floorSurface
local Dodge = require('src.combat.dodge')
-- The knight's hit volume, the same as for melee (content/enemies.lua).
local knight = require('src.content.enemies').player.body
local Defaults = require('src.content.combat_defaults')
local D = require('src.combat.damage')
local K = Defaults.missiles
local P = {}
local finite = MathX.finite
local function earlier(a, b)
  if a.time == b.time then
    return a.order < b.order
  end
  return a.time < b.time
end
-- Intersect a moving horizontal cylinder and two independently moving vertical
-- bounds. A union of standing/crouching heights hits players who already ducked.
local function playerContact(player, previous, b, dx, dy, dz, fraction, ground)
  local rx = dx - (player.x - previous.x) * fraction
  local rz = dz - (player.z - previous.z) * fraction
  local ox, oz = b.x - previous.x, b.z - previous.z
  -- The knight's radius plus the projectile's own radius (its painted size).
  local own = b.radius or (b.big and Defaults.attacks.bigBoltRadius or Defaults.attacks.boltRadius)
  local radius = knight.radius + own
  local a = rx * rx + rz * rz
  local lo, hi = 0, 1
  if a < 1e-12 then
    if ox * ox + oz * oz > radius * radius then
      return
    end
  else
    local halfB = ox * rx + oz * rz
    local c = ox * ox + oz * oz - radius * radius
    local disc = halfB * halfB - a * c
    if disc < 0 then
      return
    end
    local root = math.sqrt(disc)
    lo = math.max(lo, (-halfB - root) / a)
    hi = math.min(hi, (-halfB + root) / a)
  end
  -- The knight's feet in world height: the ground and his jump.
  local jump = ground + (previous.jump or 0)
  local jumpDelta = ((player.jump or 0) - (previous.jump or 0)) * fraction
  local crouch = previous.crouch or 0
  local crouchDelta = ((player.crouch or 0) - crouch) * fraction
  -- Each inequality value + slope*t >= 0 narrows the same contact interval.
  local lower = b.y + own - (jump + knight.feet)
  local lowerSlope = dy - jumpDelta
  if math.abs(lowerSlope) < 1e-12 then
    if lower < 0 then
      return
    end
  elseif lowerSlope > 0 then
    lo = math.max(lo, -lower / lowerSlope)
  else
    hi = math.min(hi, -lower / lowerSlope)
  end
  local upper = jump + knight.height + own - crouch - b.y
  local upperSlope = jumpDelta - crouchDelta - dy
  if math.abs(upperSlope) < 1e-12 then
    if upper < 0 then
      return
    end
  elseif upperSlope > 0 then
    lo = math.max(lo, -upper / upperSlope)
  else
    hi = math.min(hi, -upper / upperSlope)
  end
  if lo <= hi and hi >= 0 and lo <= 1 then
    return math.max(0, lo)
  end
end
-- A knight's missile meets the first body in its way along its path this tick
-- (the bodies prepared once for the step, as a shot prepares them for its
-- volley: the same painted surfaces and the same rule for falling bodies).
-- Returns the share of the path, the body and the part struck.
local function demonContact(b, dx, dy, dz, limit, bodies, g)
  local length = math.sqrt(dx * dx + dy * dy + dz * dz)
  if length <= 1e-8 then
    return
  end
  local ux, uy, uz = dx / length, dy / length, dz / length
  local best, target, part, surface = limit * length
  local own = b.radius or (b.big and Defaults.attacks.bigBoltRadius or Defaults.attacks.boltRadius)
  for _, entry in ipairs(bodies) do
    local d, segment, contact =
      B.body(g, entry.enemy, b.x, b.y, b.z, ux, uy, uz, best, entry.volumes, entry.surface, own)
    if d and (d < best or (not target and d == best)) then
      best, target, part, surface = d, entry.enemy, segment, contact
    end
  end
  if target then
    return best / length, target, part, surface
  end
end
-- The knight's missile wounds the demon it met (its packet, at full power).
-- A falling body only stops it: the dead take no wound and give no reward.
local function strikeDemon(g, b, e, part, surface)
  if b.shot then
    require('src.combat.combat').projectile(g, b, e, part, surface)
    return
  end
  if e.hp <= 0 then
    return
  end
  local packet = b.packet
  local attack = {}
  for k, v in pairs(K.flat) do
    attack[k] = v
  end
  attack.base, attack.impact, attack.damageType, attack.push =
    packet.base, packet.impact, packet.damageType, packet.push
  local dealt, _, impact
  if surface then
    dealt, _, impact = D.surface(attack, e, 0, surface)
  else
    dealt, _, impact = D.resolve(attack, e, 0, part)
  end
  local health = math.min(e.hp, dealt)
  g:damageEnemy(e, dealt, 'ability')
  local Combat = require('src.combat.combat')
  Combat.react(
    g,
    e,
    impact,
    false,
    { b.x, b.y, b.z },
    nil,
    health,
    nil,
    { value = health, kill = e.hp <= 0, head = part == 'head' }
  )
end
function P.update(g, dt, previous)
  if not finite(dt) or dt <= 0 then
    return
  end
  local player = g.player
  previous = previous or player
  local ground = Ground.height(g.world)
  local bullets = g.bullets
  local events = g._projectileEvents or {}
  g._projectileEvents = events
  local eventCount = 0
  -- The bodies a knight's missile can meet this step, prepared on first need.
  local bodies
  for i = #bullets, 1, -1 do
    local b = bullets[i]
    if
      not (
        finite(b.x)
        and finite(b.y)
        and finite(b.z)
        and finite(b.vx)
        and finite(b.vy)
        and finite(b.vz)
        and finite(b.life)
      )
    then
      table.remove(bullets, i)
    else
      local duration = math.max(0, math.min(dt, b.life))
      local fraction = duration / dt
      local dx, dy, dz = b.vx * duration, b.vy * duration, b.vz * duration
      local length = math.sqrt(dx * dx + dy * dy + dz * dz)
      local worldT, wall = 1, false
      local own = b.radius
        or (b.big and Defaults.attacks.bigBoltRadius or Defaults.attacks.boltRadius)
      if length > 1e-8 then
        local distance, _, kind = SphereCast.world(
          g.world,
          b.x,
          b.y,
          b.z,
          dx / length,
          dy / length,
          dz / length,
          length,
          own,
          floorSurface
        )
        if kind ~= 'range' then
          worldT = distance / length
          wall = true
        end
      else
        local _, _, kind = SphereCast.world(g.world, b.x, b.y, b.z, 0, 0, 0, 0, own, floorSurface)
        if kind ~= 'range' then
          worldT = 0
          wall = true
        end
      end
      local knightSide = b.side == 'knight'
      local hit, target, part, surface
      if knightSide then
        bodies = bodies or B.prepare(g)
        hit, target, part, surface = demonContact(b, dx, dy, dz, worldT, bodies, g)
      else
        hit = playerContact(player, previous, b, dx, dy, dz, fraction, ground)
        -- Through the afterimage of a dodge: a perfect dodge; it flies on.
        local ghost = not hit and b.packet and Dodge.afterimage(g)
        if ghost then
          local through = playerContact(ghost, ghost, b, dx, dy, dz, fraction, ground)
          if through and through <= 1 and (not wall or through < worldT) then
            Dodge.perfect(g, b.packet, nil)
          end
        end
      end
      local playerFirst = duration > 0 and hit and hit <= 1 and (not wall or hit < worldT - 1e-6)
      local t = playerFirst and hit or worldT
      if not knightSide and not playerFirst and not b.whooshed and duration > 0 then
        -- Closest approach of this tick's path to the player's chest: a near miss
        -- is heard and marked, so dodging a shot is felt, not only survived.
        local cx, cy, cz =
          player.x - b.x,
          ground + (player.jump or 0) + K.chest - (player.crouch or 0) - b.y,
          player.z - b.z
        local l2 = (dx * dx + dy * dy + dz * dz) * t * t
        local s = l2 > 1e-9 and math.max(0, math.min(1, (cx * dx + cy * dy + cz * dz) * t / l2))
          or 0
        local ex, ey, ez = cx - dx * t * s, cy - dy * t * s, cz - dz * t * s
        local miss = math.sqrt(ex * ex + ey * ey + ez * ez)
        if miss < K.nearMiss and s < 1 then
          b.whooshed = true
          Signal(g, 'NearMiss', { bullet = b, distance = miss })
        end
      end
      b.x, b.y, b.z = b.x + dx * t, b.y + dy * t, b.z + dz * t
      if b.travelled ~= nil then
        b.travelled = b.travelled + length * t
      end
      b.life = b.life - dt
      if playerFirst or wall or b.life <= 0 then
        table.remove(bullets, i)
        eventCount = eventCount + 1
        local event = events[eventCount] or {}
        events[eventCount] = event
        event.bullet, event.player, event.time, event.order = b, playerFirst, duration * t, i
        event.enemy, event.part = playerFirst and target or nil, part
        event.surface = surface
      end
    end
  end
  for i = #events, eventCount + 1, -1 do
    events[i] = nil
  end
  table.sort(events, earlier)
  for _, event in ipairs(events) do
    local b = event.bullet
    if event.player and event.enemy then
      strikeDemon(g, b, event.enemy, event.part, event.surface)
    elseif event.player then
      g:damagePlayer(
        b.packet and b.packet.base or (b.big and K.bigBoltDamage or K.boltDamage),
        b.x - b.vx,
        b.z - b.vz,
        b.packet
      )
    end
    Signal(g, 'ProjectileBurst', { bullet = b })
    if g.state ~= 'playing' then
      break
    end
  end
end
return P
