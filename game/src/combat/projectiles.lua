-- Sweep each projectile through the entire tick. Resolve the first event only.
local Combat = require('src.combat.combat')
local Entities = require('src.session.entities')
local Signal = require('src.session.signal')
local MathX = require('src.core.mathx')
local Ballistics = require('src.combat.ballistics')
local Ground = require('src.physics.ground')
local SphereCast = require('src.physics.sphere_cast')
local CylinderCast = require('src.physics.cylinder_cast')
local Shape = require('src.combat.projectile_shape')
local Receipt = require('src.combat.contact_receipt')
local floorSurface = require('src.content.tuning').floorSurface
local Dodge = require('src.combat.dodge')
-- The knight's hit volume, the same as for melee (content/enemies.lua).
local Characters = require('src.content.characters')
local Hit = require('src.combat.hit')
local Defaults = require('src.content.combat_defaults')
local Damage = require('src.combat.damage')
local Materials = require('src.content.ballistic_surfaces')
local Pools = require('src.session.world')
local Bodies = require('src.combat.bodies')
local Factions = require('src.content.factions')
local Roles = require('src.core.roles')
local K = Defaults.missiles
local Deposits = require('src.combat.deposits')
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
  local own = Shape.radius(b)
  -- The knight's feet in world height: the ground and his jump.
  local ground = Ground.of(world, previous)
  local jump = ground + (previous.jump or 0)
  local jumpDelta = (Ground.of(world, player) + (player.jump or 0) - jump) * fraction
  local crouch = previous.crouch or 0
  local crouchDelta = ((player.crouch or 0) - crouch) * fraction
  local knight = Characters.of(player).body
  return CylinderCast.sweep(
    ox,
    oz,
    rx,
    rz,
    jump + knight.feet - b.y,
    jumpDelta - dy,
    jump + knight.height - crouch - b.y,
    jumpDelta - crouchDelta - dy,
    knight.radius,
    own
  )
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
-- A weapon's round that pierces goes on through a body it met, by the rule of a
-- traced round (combat/volley.lua: pierce). Returns the power it keeps and the
-- bodies it has passed, or nothing when it stops here.
local function goesOn(b, target, part, surface)
  local pierce = b.shot and b.shot.attack.pierce
  if not pierce or (surface and not Materials[surface.material].penetrable) then
    return
  end
  local retain = (b.retain or 1)
    * math.max(0, pierce.retain - Damage.rating(target, part) * pierce.armorCost)
  local passed = (b.passed or 0) + 1
  if retain >= pierce.minRetain and passed <= pierce.bodies then
    return retain, passed
  end
end
local function demonContact(b, dx, dy, dz, limit, bodies, g, side)
  local length = math.sqrt(dx * dx + dy * dy + dz * dz)
  if length <= 1e-8 then
    return
  end
  local ux, uy, uz = dx / length, dy / length, dz / length
  local best, target, part, surface = limit * length
  local own = Shape.radius(b)
  for _, entry in ipairs(bodies) do
    if
      Ballistics.near(entry, b.x, b.z, ux, uz, best, own)
      and Bodies.harms(g, side, entry.enemy, 'missile')
      and not (b.through and b.through[entry.enemy.id])
    then
      local d, segment, contact = Ballistics.body(
        g,
        entry.enemy,
        b.x,
        b.y,
        b.z,
        ux,
        uy,
        uz,
        best,
        entry.volumes,
        entry.surface,
        own
      )
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
    Combat.projectile(g, b, e, part, surface, P.observer(g, b))
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
  local dealt, _, impact = Hit.measure(attack, e, 0, part, surface)
  Hit.land(g, e, { damage = dealt, impact = impact }, {
    source = sideOf(b) == 'knight' and 'ability' or 'creature',
    payload = packet,
    owner = b.owner,
    strong = false,
    point = { b.x, b.y, b.z },
    extra = { origin = P.observer(g, b) },
    numbered = true,
    head = part == 'head',
  })
end
-- The step of one missile, kept between them: they are swept one at a time, and what they
-- strike is delivered after the sweep.
local s = {}
local function flying(b)
  return finite(b.x)
    and finite(b.y)
    and finite(b.z)
    and finite(b.vx)
    and finite(b.vy)
    and finite(b.vz)
    and finite(b.life)
end
local function before(t)
  return s.duration > 0 and t and t <= 1 and (not s.wall or t < s.worldT - 1e-6)
end
local function stopAtWorld(g, b)
  local length = s.length
  s.worldT, s.wall, s.normal = 1, false, nil
  if length > 1e-8 then
    local distance, normal, kind = SphereCast.world(
      g.world,
      b.x,
      b.y,
      b.z,
      s.dx / length,
      s.dy / length,
      s.dz / length,
      length,
      s.own,
      floorSurface
    )
    if kind ~= 'range' then
      s.worldT, s.wall, s.normal = distance / length, true, normal
    end
  else
    local _, _, kind = SphereCast.world(g.world, b.x, b.y, b.z, 0, 0, 0, 0, s.own, floorSurface)
    if kind ~= 'range' then
      s.worldT, s.wall = 0, true
    end
  end
end
-- A thing in its way stops it like stone.
local function stopAtThing(g, b)
  local length = s.length
  s.thing = nil
  if length > 1e-8 and sideOf(b) == 'knight' then
    local thing, at =
      Entities.ray(g, b.x, b.y, b.z, s.dx / length, s.dy / length, s.dz / length, length * s.worldT)
    if thing then
      s.thing = thing
      s.worldT, s.wall = at / length, true
    end
  end
end
-- What the missile can meet (plan v10 V2): every knight and every
-- creature its side harms (content/factions.lua). Default relations
-- keep 0.32: a knight's missile meets the demons, a demon's the knight.
local function meetCreatures(g, b, player, bodies)
  if harmsCreatures(g, sideOf(b)) then
    -- Bodies prepared once per observer and step.
    local observer = P.observer(g, b)
    local key = observer or b
    if observer == nil or observer == player then
      key = player
    end
    if not bodies[key] then
      bodies[key] = Ballistics.prepare(g, observer, next(bodies) and {} or nil)
    end
    local share, body, segment, contact =
      demonContact(b, s.dx, s.dy, s.dz, s.worldT, bodies[key], g, sideOf(b))
    if before(share) then
      s.hit, s.target, s.part, s.surface = share, body, segment, contact
    end
  end
end
local function meetKnights(g, b, player, previous)
  local dx, dy, dz, fraction = s.dx, s.dy, s.dz, s.fraction
  for _, knight in ipairs(Bodies.knights(g)) do
    if Bodies.harms(g, sideOf(b), knight, 'missile') then
      local from = knight == player and previous or Bodies.previous(g, knight)
      local share = playerContact(knight, from, b, dx, dy, dz, fraction, g.world)
      if before(share) and (not s.hit or share < s.hit) then
        s.hit, s.struck, s.target, s.part, s.surface = share, knight, nil, nil, nil
        s.struckFrom = from
      end
      -- Through the afterimage of a dodge: a perfect dodge; it flies on.
      local ghost = not share and b.packet and Dodge.afterimage(g, knight)
      if ghost then
        local through = playerContact(ghost, ghost, b, dx, dy, dz, fraction, g.world)
        if through and through <= 1 and (not s.wall or through < s.worldT) then
          Dodge.perfect(g, b.packet, nil, knight)
        end
      end
    end
  end
end
-- Closest approach of this tick's path to the player's chest: a near miss
-- is heard and marked, so dodging a shot is felt, not only survived.
local function hearNearMiss(g, b, player, ground, t)
  local dx, dy, dz = s.dx, s.dy, s.dz
  local cx, cy, cz =
    player.x - b.x,
    ground + (player.jump or 0) + K.chest - (player.crouch or 0) - b.y,
    player.z - b.z
  local l2 = (dx * dx + dy * dy + dz * dz) * t * t
  local along = l2 > 1e-9 and math.max(0, math.min(1, (cx * dx + cy * dy + cz * dz) * t / l2)) or 0
  local ex, ey, ez = cx - dx * t * along, cy - dy * t * along, cz - dz * t * along
  local miss = math.sqrt(ex * ex + ey * ey + ez * ez)
  if miss < K.nearMiss and along < 1 then
    b.whooshed = true
    Signal(g, 'NearMiss', { bullet = b, distance = miss })
  end
end
-- Where the missile met the knight, on his interpolated body.
local function contactWith(g, b, t)
  local share, from, struck = s.fraction * t, s.struckFrom, s.struck
  local feetFrom = Ground.of(g.world, from) + (from.jump or 0)
  local feetTo = Ground.of(g.world, struck) + (struck.jump or 0)
  local feet = feetFrom + (feetTo - feetFrom) * share
  local crouch = (from.crouch or 0) + ((struck.crouch or 0) - (from.crouch or 0)) * share
  local knight = Characters.of(struck).body
  local contact = Receipt.sphere(
    b.x,
    b.y,
    b.z,
    s.own,
    from.x + (struck.x - from.x) * share,
    from.z + (struck.z - from.z) * share,
    feet + knight.feet,
    feet + knight.height - crouch,
    knight.radius
  )
  contact.kind, contact.id, contact.owner, contact.target = 'projectile', b.id, b.owner, struck.id
  contact.time, contact.fraction = s.duration * t, share
  return contact
end
-- One missile through this step: returns the event it leaves, in the events kept by the session.
local function sweep(g, b, i, dt, player, previous, ground, bodies, events, count)
  local duration = math.max(0, math.min(dt, b.life))
  s.duration, s.fraction = duration, duration / dt
  s.dx, s.dy, s.dz =
    b.vx * duration, b.vy * duration - (b.gravity or 0) * duration * duration * 0.5, b.vz * duration
  s.length = math.sqrt(s.dx * s.dx + s.dy * s.dy + s.dz * s.dz)
  s.own = Shape.radius(b)
  s.hit, s.target, s.part, s.surface, s.struck, s.struckFrom = nil, nil, nil, nil, nil, nil
  stopAtWorld(g, b)
  stopAtThing(g, b)
  meetCreatures(g, b, player, bodies)
  meetKnights(g, b, player, previous)
  local playerFirst = s.hit ~= nil
  local t = playerFirst and s.hit or s.worldT
  local knightSide = not Bodies.harms(g, sideOf(b), player, 'missile')
  if not knightSide and not playerFirst and not b.whooshed and duration > 0 then
    hearNearMiss(g, b, player, ground, t)
  end
  b.x, b.y, b.z = b.x + s.dx * t, b.y + s.dy * t, b.z + s.dz * t
  if b.gravity then
    b.vy = b.vy - b.gravity * duration * t
  end
  if b.travelled ~= nil then
    b.travelled = b.travelled + s.length * t
  end
  b.life = b.life - dt
  local retain, passed
  if s.target then
    retain, passed = goesOn(b, s.target, s.part, s.surface)
  end
  local over = b.life <= 0 or (not retain and (playerFirst or s.wall))
  if over then
    Pools.removeAt(g, 'projectiles', i)
  end
  if over or retain then
    count = count + 1
    local event = events[count] or {}
    events[count] = event
    event.bullet, event.player, event.time, event.order = b, playerFirst, duration * t, i
    event.enemy, event.part = playerFirst and s.target or nil, s.part
    event.knight = playerFirst and s.struck or nil
    event.surface = s.surface
    event.contact = playerFirst and s.struck and contactWith(g, b, t) or nil
    event.retain, event.passed = not over and retain or nil, passed
    event.wall = s.wall and not playerFirst
    event.normal = event.wall and s.normal or nil
    event.thing = not playerFirst and s.thing or nil
  end
  return count
end
-- What a swept missile did, in the order it happened.
local function deliver(g, event)
  local b = event.bullet
  if event.wall then
    Deposits.land(g, b, event.normal)
  end
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
      {
        effectSource = b.packet and b.packet.effects and { side = sideOf(b), id = b.owner } or nil,
        contact = event.contact,
      }
    )
  end
  if event.thing then
    local packet = b.shot and b.shot.attack or b.packet
    Entities.hurt(g, event.thing, packet.base, b.owner)
  end
  if event.retain then
    -- It flies on from here, never meeting this body again.
    b.retain, b.passed = event.retain, event.passed
    b.through = b.through or {}
    b.through[event.enemy.id] = true
  else
    Signal(g, 'ProjectileBurst', {
      bullet = b,
      struck = event.enemy or event.knight,
      wall = event.wall,
    })
  end
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
    if flying(b) then
      eventCount = sweep(g, b, i, dt, player, previous, ground, bodies, events, eventCount)
    else
      Pools.removeAt(g, 'projectiles', i)
    end
  end
  for i = #events, eventCount + 1, -1 do
    events[i] = nil
  end
  table.sort(events, earlier)
  for _, event in ipairs(events) do
    deliver(g, event)
    if g.state ~= 'playing' then
      break
    end
  end
end
return P
