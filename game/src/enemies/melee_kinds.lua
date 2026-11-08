-- The attack kinds that carry the body into its blow (plan v10 V6:
-- enemies/actions.lua split by responsibility): the lunge, the charge and
-- the leap. Each kind's fields and defaults: content/defs/action.lua.
local Signal = require('src.session.signal')
local MathX = require('src.core.mathx')
local Arena = require('src.world.arena')
local Ground = require('src.physics.ground')
local Melee = require('src.combat.melee')
local Dodge = require('src.combat.dodge')
local Rules = require('src.combat.rules')
local Tuning = require('src.content.tuning')
local Flight = require('src.enemies.flight')
local Contact = require('src.enemies.attack_contact')
local Area = require('src.combat.area_contact')
local Volumes = require('src.content.defs.area')
local Pattern = require('src.enemies.ground_pattern')
local ActionKinds = require('src.combat.action_kinds')
local act = ActionKinds.act
local Pools = require('src.session.world')
local Defaults = require('src.content.combat_defaults')
local K = Defaults.attacks
local sin, cos = math.sin, math.cos
local len = MathX.len
local victimOf, pointOf, previousOf = Contact.victim, Contact.point, Contact.previous
local knightAt, hurt, dodged, rush, face =
  Contact.knightAt, Contact.hurt, Contact.dodged, Contact.rush, Contact.face
local Kinds = {}
Kinds.lunge = {
  execute = face,
  strike = function(g, e, atk, dt, ctx)
    if ctx.before >= atk.lungeTime then
      return
    end
    local step = math.min(dt, atk.lungeTime - ctx.before)
    local t = victimOf(g, e)
    local p, previous = pointOf(g, t), previousOf(g, t, ctx.previous)
    local current = step < dt and Melee.playerAt(previous or p, p, step / dt, nil, g.world) or p
    -- A crippled or wounded body lunges shorter (the same speed conditions).
    rush(
      g,
      e,
      atk.lungeSpeed * Rules.speedScale(e),
      step,
      ctx.previous,
      knightAt(g, t, current, ctx.previous, step, dt),
      dt
    )
    if e.didHit then
      return
    end
    local hit, _, contact = Melee.claw(
      g,
      e,
      ctx.oldX,
      ctx.oldZ,
      previous or p,
      ctx.before,
      e.phase,
      atk.lungeTime,
      atk.active,
      p,
      atk,
      t
    )
    if hit then
      hurt(g, e, atk, t, contact)
      return
    end
    local ghost = Dodge.afterimage(g, t)
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
        atk,
        t
      )
    then
      dodged(g, e, atk, t)
    end
  end,
}
-- How long a rush at (x, z) takes.
local function rushTime(e, atk)
  return math.min(
    atk.maxTime,
    math.max(atk.minTime, len(e.aimX - e.x, e.aimZ - e.z) / atk.speed + K.chargeMargin)
  )
end
Kinds.charge = {
  state = {
    turnsLeft = 'new rushes left in this charge',
    turnAt = 'when the next rush begins, on the strike clock',
    turnStart = 'start of a planted return on the strike clock',
  },
  execute = function(g, e, atk, a)
    face(g, e, atk, a)
    e.chargeTime = rushTime(e, atk)
    act(e).turnsLeft, act(e).turnAt, act(e).turnStart = atk.turns, nil, nil
  end,
  strike = function(g, e, atk, dt, ctx)
    -- A rush with turns stops, looks at the target again and goes.
    if act(e).turnAt then
      if atk.returnTurn then
        local off = MathX.wrapAngle(math.atan2(e.aimX - e.x, e.aimZ - e.z) - e.facing)
        local most = atk.returnTurn * dt
        e.facing = e.facing + math.max(-most, math.min(most, off))
      end
      if e.phase < act(e).turnAt then
        return
      end
      local t = victimOf(g, e)
      if not atk.returnTurn then
        e.aimX, e.aimZ, e.aimLevel = t.x, t.z, t.level
      end
      act(e).turnAt, act(e).turnStart = nil, nil
      face(g, e, atk, math.atan2(e.aimX - e.x, e.aimZ - e.z))
      e.chargeTime = e.phase + rushTime(e, atk)
      return
    end
    if ctx.before >= e.chargeTime then
      if (act(e).turnsLeft or 0) > 0 and not e.didHit then
        act(e).turnsLeft = act(e).turnsLeft - 1
        act(e).turnAt = e.phase + atk.turnPause
        if atk.returnTurn then
          -- Looking at this position is part of the planted turn, not a hidden
          -- retarget on release. A later sidestep can avoid the returning rush.
          local t = victimOf(g, e)
          e.aimX, e.aimZ, e.aimLevel = t.x, t.z, t.level
          local off = MathX.wrapAngle(math.atan2(e.aimX - e.x, e.aimZ - e.z) - e.facing)
          act(e).turnStart = e.phase
          act(e).turnAt = e.phase + math.max(atk.turnPause, math.abs(off) / atk.returnTurn)
        end
        e.chargeTime = act(e).turnAt + atk.maxTime
      end
      return
    end
    local t = victimOf(g, e)
    local p, previous = pointOf(g, t), previousOf(g, t, ctx.previous)
    local step = math.min(dt, e.chargeTime - ctx.before)
    local current = step < dt and Melee.playerAt(previous or p, p, step / dt, nil, g.world) or p
    if atk.bend then
      -- The rush leans after the knight: stepping aside early is followed, late is not.
      local way = math.atan2(e.lungeX, e.lungeZ)
      local off = math.atan2(t.x - e.x, t.z - e.z) - way
      off = math.atan2(math.sin(off), math.cos(off))
      local most = atk.bend * step
      face(g, e, atk, way + math.max(-most, math.min(most, off)))
    end
    rush(g, e, atk.speed, step, ctx.previous, knightAt(g, t, current, ctx.previous, step, dt), dt)
    local r = atk.reach
    local x1, z1 = ctx.oldX + e.lungeX * r, ctx.oldZ + e.lungeZ * r
    local x2, z2 = e.x + e.lungeX * r, e.z + e.lungeZ * r
    local y1 = atk.contactY
      + Ground.height(g.world, ctx.oldX, ctx.oldZ, e.level)
      - Ground.height(g.world)
    local y2 = atk.contactY + Ground.of(g.world, e) - Ground.height(g.world)
    if not e.didHit then
      local hit, share, contact =
        Melee.contact(g, x1, z1, x2, z2, y1, atk.contactRadius, previous, current, y2, t)
      if hit then
        contact.time, contact.fraction = share * step, share * step / dt
        hurt(g, e, atk, t, contact)
      else
        local ghost = Dodge.afterimage(g, t)
        if
          ghost and Melee.contact(g, x1, z1, x2, z2, y1, atk.contactRadius, ghost, ghost, y2, t)
        then
          dodged(g, e, atk, t)
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
    return (act(e).turnsLeft or 0) > 0 and not e.didHit and math.huge or e.chargeTime
  end,
}
-- Whether a point lies in the blow's arc, along the way the body faces.
local function inArc(e, p, arc)
  local dx, dz = p.x - e.x, p.z - e.z
  local d = len(dx, dz)
  return d < 1e-6 or (dx * e.lungeX + dz * e.lungeZ) / d >= cos(arc * 0.5)
end
-- The body's step into a blow.
local function lean(g, e, atk, dt, ctx)
  if ctx.before >= atk.lungeTime or atk.lungeSpeed <= 0 then
    return
  end
  local step = math.min(dt, atk.lungeTime - ctx.before)
  local t = victimOf(g, e)
  local p, previous = pointOf(g, t), previousOf(g, t, ctx.previous)
  local current = step < dt and Melee.playerAt(previous or p, p, step / dt, nil, g.world) or p
  local speed = atk.lungeSpeed * Rules.speedScale(e)
  if atk.closing then
    -- Backing away is no answer: the step is as long as the gap, up to its speed.
    local gap = len(t.x - e.x, t.z - e.z) - atk.reach * atk.closing
    speed = math.min(speed, math.max(0, gap) / math.max(dt, atk.lungeTime - ctx.before))
  end
  rush(g, e, speed, step, ctx.previous, knightAt(g, t, current, ctx.previous, step, dt), dt)
end
-- A blow's reach and arc in its active window. Returns the body caught and its
-- receipt; a dodge that left its afterimage in the arc spends the blow.
local source = {}
-- A blow with a path: it meets what its path crosses, when it crosses it.
local function traced(g, e, atk, ctx, t, p)
  local previous = previousOf(g, t, ctx.previous)
  local hit, _, contact = Melee.claw(
    g,
    e,
    ctx.oldX,
    ctx.oldZ,
    previous or p,
    ctx.before,
    e.phase,
    atk.lungeTime,
    atk.active,
    p,
    atk,
    t
  )
  if hit then
    return t, contact
  end
  local ghost = Dodge.afterimage(g, t)
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
      atk,
      t
    )
  then
    dodged(g, e, atk, t)
  end
end
local function swing(g, e, atk, ctx)
  if e.didHit or e.phase < atk.active[1] or ctx.before > atk.active[2] then
    return
  end
  local t = victimOf(g, e)
  local p = pointOf(g, t)
  if atk.trace then
    return traced(g, e, atk, ctx, t, p)
  end
  source.x, source.z, source.level, source.radius = e.x, e.z, e.level, atk.reach
  local hit, contact = Area.test(g, source, atk.volume, t, p)
  if hit and inArc(e, p, atk.arc) then
    return t, contact
  end
  local ghost = Dodge.afterimage(g, t)
  if ghost and Area.test(g, source, atk.volume, t, ghost) and inArc(e, ghost, atk.arc) then
    dodged(g, e, atk, t)
  end
end
-- In the blow the body keeps after who goes the way the blade goes; who goes against
-- it is left behind. That is the difference between a dodge and the right dodge.
local function chase(g, e, atk, dt)
  if not atk.chase or not atk.trace or e.phase > atk.active[2] then
    return
  end
  local t = victimOf(g, e)
  local yaw = math.atan2(e.lungeX, e.lungeZ)
  local off = MathX.wrapAngle(math.atan2(t.x - e.x, t.z - e.z) - yaw)
  local swing = (atk.trace[#atk.trace].angle - atk.trace[1].angle) * (e.swingSide or 1)
  if off * swing > 0 then
    local most = atk.chase * dt
    face(g, e, atk, yaw + math.max(-most, math.min(most, off)))
  end
end
Kinds.sweep = {
  state = { trailed = 'its cut already left its trail' },
  execute = function(g, e, atk, a)
    face(g, e, atk, a)
    act(e).trailed = nil
  end,
  strike = function(g, e, atk, dt, ctx)
    lean(g, e, atk, dt, ctx)
    chase(g, e, atk, dt)
    if atk.trail and not act(e).trailed and e.phase >= atk.active[1] then
      act(e).trailed = true
      Pattern.release(g, e, atk.trail, math.atan2(e.lungeX, e.lungeZ))
    end
    local t, contact = swing(g, e, atk, ctx)
    if t then
      hurt(g, e, atk, t, contact)
    end
  end,
}
Kinds.seize = {
  state = {
    holding = 'id of the body in its grip',
    holdUntil = 'when that grip closes, on the strike clock',
  },
  release = function(e)
    act(e).holding, act(e).holdUntil = nil, nil
  end,
  execute = face,
  strike = function(g, e, atk, dt, ctx)
    if act(e).holding then
      local t = Pools.get(g, act(e).holding)
      if not t or t.hp <= 0 then
        ActionKinds.release(e)
      elseif e.phase >= act(e).holdUntil then
        ActionKinds.release(e)
        hurt(g, e, atk, t)
      else
        Rules.addCondition(t, 'seized', Defaults.gripHold)
      end
      return
    end
    lean(g, e, atk, dt, ctx)
    local t = swing(g, e, atk, ctx)
    if t then
      e.didHit = true
      -- A dodge on its way through: the grip closes on nothing.
      if (t.invuln or 0) > 0 then
        Dodge.perfect(g, atk.packet, e, t)
      else
        act(e).holding, act(e).holdUntil = t.id, e.phase + atk.grip
        Rules.addCondition(t, 'seized', Defaults.gripHold)
        Signal(g, 'Seized', { enemy = e, target = t.id })
      end
    end
  end,
  duration = function(e, atk)
    return act(e).holding and math.huge or atk.duration
  end,
}
-- The body springs back from its target; nothing lands.
Kinds.hop = {
  unseen = true,
  execute = function(g, e, atk, a)
    face(g, e, atk, a + math.pi)
  end,
  strike = function(g, e, atk, dt, ctx)
    if ctx.before < atk.lungeTime then
      rush(g, e, atk.speed, math.min(dt, atk.lungeTime - ctx.before), ctx.previous, nil, dt)
    end
  end,
}
Kinds.leap = {
  -- A leap predicts where the player will be when it lands (crouch + flight).
  aim = function(g, e, atk)
    if not atk.leadShare then
      return
    end
    local p = victimOf(g, e)
    local gravity = Tuning.gravity
    local flight = 2 * math.sqrt(2 * gravity * atk.height) / gravity
    local t = (e.windup + flight) * atk.leadShare
    for _ = 1, K.aimTries do
      local x, z = p.x + (p.vx or 0) * t, p.z + (p.vz or 0) * t
      if not Arena.solid(g.world, x, z, K.aimClearance) then
        e.aimX, e.aimZ = x, z
        break
      end
      t = t * 0.5
    end
  end,
  -- Ballistic leap under world gravity: apex 'height', flight time
  -- T = 2 vy / g, horizontal speed = distance / T (capped at 11 m/s).
  execute = function(g, e, atk, a)
    Contact.face(g, e, atk, a)
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
    local t = victimOf(g, e)
    local p = pointOf(g, t)
    local _, used = Flight.step(g, e, dt, ctx and ctx.previous)
    if not e.leaping and not e.didHit then
      if used and used < dt then
        p = Melee.playerAt(previousOf(g, t, ctx and ctx.previous) or p, p, used / dt, nil, g.world)
      end
      e.didHit = true
      Flight.land(g, e, nil, atk)
      local source = { x = e.x, z = e.z, level = e.level, radius = atk.landRadius }
      local volume = atk.landVolume or Volumes.defaults.landing
      local hit, contact = Area.test(g, source, volume, t, p)
      local ghost = Dodge.afterimage(g, t)
      if hit then
        local packet = atk.packet
        contact.kind, contact.id, contact.owner, contact.target = 'melee', atk.id, e.id, t.id
        contact.geometry, contact.time, contact.fraction =
          'landing-radius', used, used and used / dt
        g:damageBody(t, packet.base, e.x, e.z, packet, e, {
          contact = contact,
        })
      elseif ghost and Area.test(g, source, volume, t, ghost) then
        dodged(g, e, atk, t)
      end
    end
  end,
  duration = function(e)
    return e.leaping and math.huge or 0
  end,
}
return Kinds
