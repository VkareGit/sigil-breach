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
local Pools = require('src.session.world')
local Bodies = require('src.combat.bodies')
local Factions = require('src.content.factions')
local Roles = require('src.core.roles')
local K = Defaults.missiles
local P = {}
local finite = MathX.finite
-- Whether a missile of this side can harm any creature: its hostile sides
-- include one that is not the knights'.
-- A missile made by hand (fixtures) without a side is a demon's, as in 0.32.
local function sideOf(b)
  return b.side or 'demons'
end
local function harmsCreatures(_, side)
  for other in pairs(Factions:get(side).hostile) do
    if other ~= 'knight' then
      return true
    end
  end
  return false
end
local function earlier(a, b)
  if a.time == b.time then
    return a.order < b.order
  end
  return a.time < b.time
end
-- Intersect a moving horizontal cylinder and two independently moving vertical
-- bounds. A union of standing/crouching heights hits players who already ducked.
local function playerContact(player, previous, b, dx, dy, dz, fraction, world)
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
  local ground = Ground.of(world, previous)
  local jump = ground + (previous.jump or 0)
  local jumpDelta = (Ground.of(world, player) + (player.jump or 0) - jump) * fraction
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
-- side: the missile's; only creatures of a side it harms are met (a falling
-- body of such a side still shields what is behind it).
-- Whose eyes a missile's targets are seen from (plan v11 E4): its owner while
-- he stands and is present; a fallen or departed owner leaves the point it was
-- fired from. (A compromise named in the plan: a painted body turns to that
-- point; two observers would see two silhouettes.)
function P.observer(g, b)
  local owner = b.shot and b.shot.shooter
  if not owner and b.owner ~= nil then
    owner = Pools.get(g, b.owner)
  end
  local present = owner
    and (owner == Roles.controlled(g) or (owner.id ~= nil and Pools.get(g, owner.id) == owner))
  if present and (owner.hp or 1) > 0 then
    return owner
  end
  local from = b.shot and b.shot.origin or b.from
  if from then
    return { x = from[1], z = from[3] }
  end
end
local function demonContact(b, dx, dy, dz, limit, bodies, g, side)
  local length = math.sqrt(dx * dx + dy * dy + dz * dz)
  if length <= 1e-8 then
    return
  end
  local ux, uy, uz = dx / length, dy / length, dz / length
  local best, target, part, surface = limit * length
  local own = b.radius or (b.big and Defaults.attacks.bigBoltRadius or Defaults.attacks.boltRadius)
  for _, entry in ipairs(bodies) do
    if
      Bodies.harms(g, side, entry.enemy, 'missile')
      and B.near(entry, b.x, b.z, ux, uz, best, own)
    then
      local d, segment, contact =
        B.body(g, entry.enemy, b.x, b.y, b.z, ux, uy, uz, best, entry.volumes, entry.surface, own)
      if d and (d < best or (not target and d == best)) then
        best, target, part, surface = d, entry.enemy, segment, contact
      end
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
  g:damageEnemy(e, dealt, sideOf(b) == 'knight' and 'ability' or 'creature', packet, b.owner)
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
  local player = Roles.controlled(g)
  previous = previous or player
  local ground = Ground.of(g.world, player)
  local bullets = Pools.of(g, 'projectiles')
  local events = g._projectileEvents or {}
  g._projectileEvents = events
  local eventCount = 0
  -- The bodies a knight's missile can meet this step, prepared on first need.
  -- Prepared bodies by observer (one table per observer of the step).
  local bodies = {}
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
      Pools.removeAt(g, 'projectiles', i)
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
      -- What the missile can meet (plan v10 V2): every knight and every
      -- creature its side harms (content/factions.lua). Default relations
      -- keep 0.32: a knight's missile meets the demons, a demon's the knight.
      local hit, target, part, surface, struck
      local function before(t)
        return duration > 0 and t and t <= 1 and (not wall or t < worldT - 1e-6)
      end
      if harmsCreatures(g, sideOf(b)) then
        -- Bodies prepared once per observer and step.
        local observer = P.observer(g, b)
        local key = observer or b
        if observer == nil or observer == player then
          key = player
        end
        if not bodies[key] then
          bodies[key] = B.prepare(g, observer, next(bodies) and {} or nil)
        end
        local share, body, segment, contact =
          demonContact(b, dx, dy, dz, worldT, bodies[key], g, sideOf(b))
        if before(share) then
          hit, target, part, surface = share, body, segment, contact
        end
      end
      for _, knight in ipairs(Bodies.knights(g)) do
        if Bodies.harms(g, sideOf(b), knight, 'missile') then
          local from = knight == player and previous or Bodies.previous(g, knight)
          local share = playerContact(knight, from, b, dx, dy, dz, fraction, g.world)
          if before(share) and (not hit or share < hit) then
            hit, struck, target, part, surface = share, knight, nil, nil, nil
          end
          -- Through the afterimage of a dodge: a perfect dodge; it flies on.
          local ghost = not share and b.packet and Dodge.afterimage(g, knight)
          if ghost then
            local through = playerContact(ghost, ghost, b, dx, dy, dz, fraction, g.world)
            if through and through <= 1 and (not wall or through < worldT) then
              Dodge.perfect(g, b.packet, nil, knight)
            end
          end
        end
      end
      local playerFirst = hit ~= nil
      local t = playerFirst and hit or worldT
      local knightSide = not Bodies.harms(g, sideOf(b), player, 'missile')
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
        Pools.removeAt(g, 'projectiles', i)
        eventCount = eventCount + 1
        local event = events[eventCount] or {}
        events[eventCount] = event
        event.bullet, event.player, event.time, event.order = b, playerFirst, duration * t, i
        event.enemy, event.part = playerFirst and target or nil, part
        event.knight = playerFirst and struck or nil
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
      g:damageBody(
        event.knight,
        b.packet and b.packet.base or (b.big and K.bigBoltDamage or K.boltDamage),
        b.x - b.vx,
        b.z - b.vz,
        b.packet,
        nil,
        b.packet and b.packet.effects and { effectSource = { side = sideOf(b), id = b.owner } }
      )
    end
    Signal(g, 'ProjectileBurst', { bullet = b })
    if g.state ~= 'playing' then
      break
    end
  end
end
return P
