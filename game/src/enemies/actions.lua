-- Data-driven attack lifecycle: selection, commitment, release and contact.
-- AI decides WHEN to begin; archetypes describe WHAT; this module executes it.
local Signal = require('src.session.signal')
local Spawn = require('src.session.spawn')
local MathX = require('src.core.mathx')
local W = require('src.world.arena')
local Ground = require('src.physics.ground')
local Melee = require('src.combat.melee')
local BodyContact = require('src.combat.body_contact')
local Dodge = require('src.combat.dodge')
local Rules = require('src.combat.rules')
local Hazards = require('src.enemies.hazards')
local Tuning = require('src.content.tuning')
local Kinematics = require('src.physics.kinematics')
local Attacks = {}
local sin, cos, sqrt, atan2 = math.sin, math.cos, math.sqrt, math.atan2
local len = MathX.len
local angle = MathX.wrapAngle
local arch, radius = Rules.archetype, Rules.radius
local K = require('src.content.combat_defaults').attacks
local function change(e, state)
  e.ai = state
  e.phase = 0
  e.rushVX, e.rushVZ = nil, nil
end
-- A bolt carries its archetype's damage packet to the projectile system.
local function projectile(g, e, a, speed, spec)
  -- Launched and aimed at heights above the ground (physics/ground.lua).
  local ground = Ground.height(g.world, e.x, e.z)
  local y = ground + spec.height
  local d = len(e.aimX - e.x, e.aimZ - e.z)
  -- radius: the projectile's own collision radius, also its painted size.
  Spawn.make(g, 'projectile', {
    x = e.x + sin(a) * K.muzzle,
    y = y,
    z = e.z + cos(a) * K.muzzle,
    vx = sin(a) * speed,
    vz = cos(a) * speed,
    vy = (Ground.height(g.world, e.aimX, e.aimZ) + K.aimHeight - y) * speed / math.max(1, d),
    life = K.boltLife,
    big = spec.big or false,
    color = spec.color,
    owner = e.id,
    packet = Rules.packet(e, spec.packet),
    radius = spec.radius or (spec.big and K.bigBoltRadius or K.boltRadius),
  })
end
-- An attack is usable at distance d when it is in range, beyond its minimum
-- range (minRange) and its own skill cooldown (rest) has elapsed.
local function usable(e, atk, d, now)
  if not atk or d > atk.range or d < atk.minRange then
    return false
  end
  local until_ = e.restUntil and e.restUntil[atk.id]
  return not (until_ and now and now < until_)
end
-- Choose the first usable attack in the archetype list whose preference fits:
-- 'maxRange' = only closer than that (it outranks 'every'); 'every=n' = only
-- when the attack counter is a multiple of n (0 fits every n: the counter
-- grows when an attack starts). When no attack fits its preference, the LAST
-- attack of the list is the fallback: it still obeys range, minRange and
-- rest, but not its own maxRange or every. A list puts last the attack meant
-- for that; 'every' on the last attack is a preference, not a hard limit.
-- Returns nil when nothing is usable (the body keeps moving instead).
local function choose(e, d, now)
  local list = arch(e).attacks
  for _, atk in ipairs(list) do
    if usable(e, atk, d, now) then
      if atk.maxRange then
        if d < atk.maxRange then
          return atk
        end
      elseif not atk.every or (e.attackCount % atk.every) == 0 then
        return atk
      end
    end
  end
  local last = list[#list]
  return usable(e, last, d, now) and last or nil
end
-- The decision alone, without beginning the attack (contract tests, tools).
Attacks.choose = choose
-- The attack in progress; records prepared by hand (tests, catalogue poses)
-- may name it only by attackKind, so look it up by id.
local function current(e)
  if e.attackSpec and (e.attackKind == nil or e.attackSpec.id == e.attackKind) then
    return e.attackSpec
  end
  local list = arch(e).attacks
  for _, atk in ipairs(list) do
    if atk.id == e.attackKind then
      e.attackSpec = atk
      return atk
    end
  end
  e.attackSpec = list[1]
  return list[1]
end
local function reach(e)
  local r = 0
  for _, atk in ipairs(arch(e).attacks) do
    r = math.max(r, atk.range)
  end
  return r
end
-- Attack kinds (0.24 registry): everything a kind of attack does lives in one
-- entry, so a new kind is one entry here plus data in content/enemies.lua.
--   commit(g, e, atk)            at commitment, after the aim is taken
--   aim(g, e, atk)               target prediction at commitment
--   execute(g, e, atk, a)        at release; a = aim angle
--   strike(g, e, atk, dt, ctx)   each step of the strike state
--   duration(e, atk)             length of the strike state (default data)
--   (the fields of each kind and their defaults: content/defs/action.lua)
-- A kind that moves the body writes the velocity it moves with to
-- e.rushVX / e.rushVZ; the shared rules read it (counter-hits, trips)
-- without knowing which kind it is.
local Kinds = {}
Attacks.kinds = Kinds
local function hurtPlayer(g, e, atk)
  local packet = Rules.packet(e, atk.packet)
  g:damagePlayer(packet.base, e.x, e.z, packet, e)
  e.didHit = true
end
-- A blow that missed the dodging knight but met his afterimage (where the
-- dodge began) is spent on it: a perfect dodge (session/damage_outcomes.lua).
local function dodged(g, e, atk)
  e.didHit = true
  Dodge.perfect(g, Rules.packet(e, atk.packet), e)
end
-- Move the body along its rush; a blow that met the rush scales it.
local function rush(g, e, speed, step, previous, current)
  local s = speed * (e.rushScale or 1)
  e.rushVX, e.rushVZ = e.lungeX * s, e.lungeZ * s
  BodyContact.moveEnemy(g, e, e.rushVX * step, e.rushVZ * step, previous, current)
end
local function face(_, e, _, a)
  e.lungeX, e.lungeZ = sin(a), cos(a)
end
Kinds.lunge = {
  execute = face,
  strike = function(g, e, atk, dt, ctx)
    if ctx.before >= atk.lungeTime then
      return
    end
    local step = math.min(dt, atk.lungeTime - ctx.before)
    local p = g.player
    local current = step < dt and Melee.playerAt(ctx.previous or p, p, step / dt, nil, g.world) or p
    -- A crippled or wounded body lunges shorter (the same speed conditions).
    rush(g, e, atk.lungeSpeed * Rules.speedScale(e), step, ctx.previous, current)
    if e.didHit then
      return
    end
    if
      Melee.claw(
        g,
        e,
        ctx.oldX,
        ctx.oldZ,
        ctx.previous,
        ctx.before,
        e.phase,
        atk.lungeTime,
        atk.active,
        nil,
        atk
      )
    then
      hurtPlayer(g, e, atk)
      return
    end
    local ghost = Dodge.afterimage(g)
    if
      ghost
      and Melee.claw(
        g,
        e,
        ctx.oldX,
        ctx.oldZ,
        ghost,
        ctx.before,
        e.phase,
        atk.lungeTime,
        atk.active,
        ghost,
        atk
      )
    then
      dodged(g, e, atk)
    end
  end,
}
Kinds.charge = {
  execute = function(g, e, atk, a)
    face(g, e, atk, a)
    e.chargeTime = math.min(
      atk.maxTime,
      math.max(atk.minTime, len(e.aimX - e.x, e.aimZ - e.z) / atk.speed + K.chargeMargin)
    )
  end,
  strike = function(g, e, atk, dt, ctx)
    if ctx.before >= e.chargeTime then
      return
    end
    local p = g.player
    local step = math.min(dt, e.chargeTime - ctx.before)
    local current = step < dt and Melee.playerAt(ctx.previous or p, p, step / dt, nil, g.world) or p
    rush(g, e, atk.speed, step, ctx.previous, current)
    local r = atk.reach
    local x1, z1 = ctx.oldX + e.lungeX * r, ctx.oldZ + e.lungeZ * r
    local x2, z2 = e.x + e.lungeX * r, e.z + e.lungeZ * r
    local y1 = atk.contactY + Ground.height(g.world, ctx.oldX, ctx.oldZ) - Ground.height(g.world)
    local y2 = atk.contactY + Ground.height(g.world, e.x, e.z) - Ground.height(g.world)
    if not e.didHit then
      if Melee.contact(g, x1, z1, x2, z2, y1, atk.contactRadius, ctx.previous, current, y2) then
        hurtPlayer(g, e, atk)
      else
        local ghost = Dodge.afterimage(g)
        if ghost and Melee.contact(g, x1, z1, x2, z2, y1, atk.contactRadius, ghost, ghost, y2) then
          dodged(g, e, atk)
        end
      end
    end
    if len(e.x - ctx.oldX, e.z - ctx.oldZ) < step * 4 then
      -- A charge stopped by stone is heard: the body meets the wall.
      if e.phase < e.chargeTime then
        Signal(g, 'ChargeBlocked', { enemy = e })
      end
      e.chargeTime = e.phase
    end
  end,
  duration = function(e)
    return e.chargeTime
  end,
}
Kinds.strike = {
  -- A strike falls on a marked place: its mark never moves (no retargeting
  -- at commitment or release). A wall between caster and mark at release
  -- still cancels it (v10 rule).
  unseen = true,
  -- The thunderbolt is marked during the windup and released at execution.
  commit = function(g, e, atk)
    local packet = Rules.packet(e, atk.packet)
    e.pendingHazard = Spawn.make(g, 'hazard', {
      kind = 'lightning',
      owner = e.id,
      x = e.aimX,
      z = e.aimZ,
      radius = atk.radius,
      delay = e.windupDuration,
      maxDelay = e.windupDuration,
      life = atk.life,
      pulse = 0,
      damage = packet.base,
      packet = packet,
      waitForCast = true,
    })
  end,
  execute = face,
}
Kinds.leap = {
  -- A leap predicts where the player will be when it lands (crouch + flight).
  aim = function(g, e, atk)
    if not atk.leadShare then
      return
    end
    local p = g.player
    local gravity = Tuning.gravity
    local flight = 2 * math.sqrt(2 * gravity * atk.height) / gravity
    local share = atk.leadShare + (1 - atk.leadShare) * (e.tierLead or 0)
    local t = (e.windup + flight) * share
    for _ = 1, K.aimTries do
      local x, z = p.x + (p.vx or 0) * t, p.z + (p.vz or 0) * t
      if not W.solid(g.world, x, z, K.aimClearance) then
        e.aimX, e.aimZ = x, z
        break
      end
      t = t * 0.5
    end
  end,
  -- Ballistic leap under world gravity: apex 'height', flight time
  -- T = 2 vy / g, horizontal speed = distance / T (capped at 11 m/s).
  execute = function(_, e, atk, a)
    local gravity = Tuning.gravity
    local vy = math.sqrt(2 * gravity * atk.height)
    local flight = 2 * vy / gravity
    local distance = len(e.aimX - e.x, e.aimZ - e.z)
    local horizontal = math.min(K.leapSpeed, distance / flight)
    e.leapVX, e.leapVZ = sin(a) * horizontal, cos(a) * horizontal
    e.leapY, e.leapVY, e.leapFlight, e.leaping = 0, vy, flight, true
  end,
  -- The landing strikes: the player within reach of the landing point.
  strike = function(g, e, atk, dt, ctx)
    local p = g.player
    local _, used = Attacks.flight(g, e, dt, ctx and ctx.previous)
    if not e.leaping and not e.didHit then
      if used and used < dt then
        p = Melee.playerAt(ctx and ctx.previous or p, p, used / dt, nil, g.world)
      end
      e.didHit = true
      Attacks.land(g, e)
      local reachLand = atk.landRadius + Rules.playerBody().radius
      local ghost = Dodge.afterimage(g)
      if
        len(p.x - e.x, p.z - e.z) < reachLand
        and math.abs(
            Ground.height(g.world, p.x, p.z) + (p.jump or 0) - Ground.height(g.world, e.x, e.z)
          )
          < K.jumpClear
      then
        local packet = Rules.packet(e, atk.packet)
        g:damagePlayer(packet.base, e.x, e.z, packet, e)
      elseif
        ghost
        and len(ghost.x - e.x, ghost.z - e.z) < reachLand
        and math.abs(
            Ground.height(g.world, ghost.x, ghost.z)
              + (ghost.jump or 0)
              - Ground.height(g.world, e.x, e.z)
          )
          < K.jumpClear
      then
        dodged(g, e, atk)
      end
    end
  end,
  duration = function(e)
    return e.leaping and math.huge or 0
  end,
}
Kinds.pool = {
  execute = function(g, e, atk, a)
    local pool = atk.pool
    Hazards.add(g, e.aimX, e.aimZ, pool.delay, pool.radius, pool.life, {
      packet = Rules.packet(e, pool.packet),
      pulse = pool.pulse,
      condition = pool.condition,
      owner = pool.packet.effects and e.id or nil,
    })
    projectile(g, e, a, atk.bolt.speed, atk.bolt)
  end,
}
Kinds.fan = {
  execute = function(g, e, atk, a)
    local rage = e.hp < e.maxHp * K.rageAt
    local n = rage and atk.rageCount or atk.count
    for j = 1, n do
      projectile(g, e, a + (j - (n + 1) / 2) * atk.spread, rage and atk.rageSpeed or atk.speed, atk)
    end
    local line = atk.line
    if line and e.attackCount % line.every == 0 then
      for j = 1, line.count do
        local d = j * line.step
        Hazards.add(
          g,
          e.aimX + cos(a) * d - 3 * cos(a),
          e.aimZ - sin(a) * d + 3 * sin(a),
          line.delay,
          line.radius,
          line.life,
          {
            packet = Rules.packet(e, line.packet),
            pulse = line.pulse,
            owner = line.packet.effects and e.id or nil,
          }
        )
      end
    end
  end,
}
Kinds.bolt = {
  execute = function(g, e, atk, a)
    projectile(g, e, a, atk.speed, atk)
  end,
}
local function kindOf(atk)
  return Kinds[atk.kind] or error('unknown attack kind: ' .. tostring(atk.kind))
end
local function execute(g, e)
  local p = g.player
  local a = atan2(e.aimX - e.x, e.aimZ - e.z)
  local atk = current(e)
  e.attackCount = e.attackCount + 1
  e.didHit = false
  e.rushScale = 1
  kindOf(atk).execute(g, e, atk, a)
  -- Furfur's thunderbolt was marked during the windup; release it now.
  if e.pendingHazard then
    e.pendingHazard.waitForCast = false
    e.pendingHazard.delay = 0
    e.pendingHazard.justReleased = true
    e.pendingHazard = nil
  end
  Signal(g, 'AttackReleased', { enemy = e, attack = atk })
end
local function beginAttack(g, e, d, chosen)
  local atk = chosen or choose(e, d, g.elapsed)
  if not atk then
    return false
  end
  -- Session tallies for balance reports (qa/scenarios/playtest.lua).
  g.attackStarts = (g.attackStarts or 0) + 1
  if atk.kind == 'leap' then
    g.leapStarts = (g.leapStarts or 0) + 1
  end
  if atk.rest then
    e.restUntil = e.restUntil or {}
    e.restUntil[atk.id] = (g.elapsed or 0) + atk.rest / (e.tierPace or 1)
  end
  e.attackSpec = atk
  e.attackKind = atk.id
  change(e, 'windup')
  e.windupDuration = atk.windup
  local p = g.player
  -- An attack from outside the player's view is announced longer (fairness).
  local inView = cos(angle(atan2(e.x - p.x, e.z - p.z) - p.yaw)) > K.viewCos
  if not inView then
    e.windupDuration = e.windupDuration + K.unseenWindup
  end
  e.windup = e.windupDuration
  e.aimX = p.x
  e.aimZ = p.z
  local kind = kindOf(atk)
  if kind.commit then
    kind.commit(g, e, atk)
  end
  -- Only a small lead at commitment; after this, targets are frozen and dodgeable.
  if atk.lead then
    local x, z = p.x + (p.vx or 0) * atk.lead, p.z + (p.vz or 0) * atk.lead
    if not W.solid(g.world, x, z, K.aimClearance) then
      e.aimX, e.aimZ = x, z
    end
  end
  if kind.aim then
    kind.aim(g, e, atk)
  end
  -- Predictive aim for bolts and fans (tier-unlocked): intercept the
  -- player's velocity at commitment. Then the target is frozen: a change of
  -- direction after the windup starts still dodges the shot.
  local lead = atk.aimLead * (e.tierLead or 0)
  local speed = atk.speed or (atk.bolt and atk.bolt.speed)
  if lead > 0 and speed and speed > 0 then
    local vx, vz = (p.vx or 0) * lead, (p.vz or 0) * lead
    local t = len(p.x - e.x, p.z - e.z) / speed + e.windup
    for _ = 1, K.leadPasses do
      t = len(p.x + vx * t - e.x, p.z + vz * t - e.z) / speed + e.windup
    end
    -- A prediction inside a wall is pulled back toward the player by halves.
    for _ = 1, K.aimTries do
      local x, z = p.x + vx * t, p.z + vz * t
      if not W.solid(g.world, x, z, K.aimClearance) then
        e.aimX, e.aimZ = x, z
        break
      end
      t = t * 0.5
    end
  end
  -- Commit only to a target in sight: a prediction behind cover falls back to
  -- the player's present position (the release check would otherwise cancel).
  if not kind.unseen and not Rules.seesKnight(g, e, e.aimX, e.aimZ) then
    e.aimX, e.aimZ = p.x, p.z
  end
  Signal(g, 'AttackTelegraphed', { enemy = e, attack = atk })
  return true
end
-- The strike state, by kind: the kind moves the body and resolves contact.
local function strike(g, e, dt, previousPlayer)
  local atk = current(e)
  local kind = kindOf(atk)
  local ctx = { before = e.phase - dt, oldX = e.x, oldZ = e.z, previous = previousPlayer }
  e.rushVX, e.rushVZ = nil, nil
  if kind.strike then
    kind.strike(g, e, atk, dt, ctx)
  end
  local duration = kind.duration and kind.duration(e, atk) or atk.duration
  if e.phase > duration then
    change(e, 'recover')
    e.recover = atk.recover
    -- Tier aggression shortens the pause between attacks, never a windup.
    e.attack = atk.cooldown / (e.tierPace or 1)
  end
end -- A body meets the floor after a leap: low dust, a thud, a short tremor
-- felt only near the landing (presentation; the strike is resolved above).
function Attacks.land(g, e, heavy)
  e.landings = (e.landings or 0) + 1
  Signal(g, 'Landed', { enemy = e, heavy = heavy })
end
-- Integrate a body in the air (a leap, or one knocked out of it): world
-- gravity, horizontal motion stopped by walls, landing at y = 0.
function Attacks.flight(g, e, dt, previous)
  if e.leapY == nil then
    e.leaping = false
    return
  end
  local gravity = Tuning.gravity
  if g.world.elevations then
    local elapsed = 0
    local p = g.player
    previous = previous or p
    while elapsed < dt do
      local landing = Kinematics.fallTime(e.leapY, e.leapVY, gravity)
      local step = math.min(dt - elapsed, landing)
      local from = Melee.playerAt(previous, p, elapsed / dt, nil, g.world)
      local current = Melee.playerAt(previous, p, (elapsed + step) / dt, nil, g.world)
      local vx, vz =
        BodyContact.moveEnemy(g, e, (e.leapVX or 0) * step, (e.leapVZ or 0) * step, from, current)
      if step > 0 then
        e.leapVX, e.leapVZ = (vx or 0) / step, (vz or 0) / step
      end
      local y = e.leapY + e.leapVY * step - 0.5 * gravity * step * step
      e.leapVY = e.leapVY - gravity * step
      elapsed = elapsed + step
      if y <= 0 then
        e.leapY, e.leapVY, e.leapVX, e.leapVZ, e.leaping = nil, 0, 0, 0, false
        return true, elapsed
      end
      e.leapY, e.leaping = y, true
      -- A former floor's landing time is only an integration boundary.
      -- Leaving its ledge rebased leapY; consume the remaining time over
      -- the new support instead of slowing the whole trajectory by a tick.
    end
    return false, elapsed
  end
  local landing = (e.leapVY + math.sqrt(e.leapVY * e.leapVY + 2 * gravity * e.leapY)) / gravity
  local step = math.min(dt, landing)
  local p = g.player
  local current = step < dt and Melee.playerAt(previous or p, p, step / dt) or p
  local vx, vz =
    BodyContact.moveEnemy(g, e, (e.leapVX or 0) * step, (e.leapVZ or 0) * step, previous, current)
  if step > 0 then
    e.leapVX, e.leapVZ = (vx or 0) / step, (vz or 0) / step
  end
  local y = e.leapY + e.leapVY * step - 0.5 * gravity * step * step
  e.leapVY = e.leapVY - gravity * step
  if (not g.world.elevations and dt >= landing) or y <= 0 then
    e.leapY, e.leapVY, e.leapVX, e.leapVZ, e.leaping = nil, 0, 0, 0, false
    return true, step
  end
  e.leapY, e.leaping = y, true
  return false, step
end
Attacks.kindOf = kindOf
Attacks.choose = choose
Attacks.current = current
Attacks.reach = reach
Attacks.begin = beginAttack
Attacks.execute = execute
Attacks.strike = strike
return Attacks
