-- The attack kinds that carry the body into its blow (plan v10 V6:
-- enemies/actions.lua split by responsibility): the lunge, the charge and
-- the leap. Each kind's fields and defaults: content/defs/action.lua.
local Signal = require('src.session.signal')
local MathX = require('src.core.mathx')
local W = require('src.world.arena')
local Ground = require('src.physics.ground')
local Melee = require('src.combat.melee')
local Dodge = require('src.combat.dodge')
local Rules = require('src.combat.rules')
local Tuning = require('src.content.tuning')
local Bodies = require('src.combat.bodies')
local Flight = require('src.enemies.flight')
local Contact = require('src.enemies.attack_contact')
local K = require('src.content.combat_defaults').attacks
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
      knightAt(g, t, current, ctx.previous, step, dt)
    )
    if e.didHit then
      return
    end
    if
      Melee.claw(
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
    then
      hurt(g, e, atk, t)
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
    local t = victimOf(g, e)
    local p, previous = pointOf(g, t), previousOf(g, t, ctx.previous)
    local step = math.min(dt, e.chargeTime - ctx.before)
    local current = step < dt and Melee.playerAt(previous or p, p, step / dt, nil, g.world) or p
    rush(g, e, atk.speed, step, ctx.previous, knightAt(g, t, current, ctx.previous, step, dt))
    local r = atk.reach
    local x1, z1 = ctx.oldX + e.lungeX * r, ctx.oldZ + e.lungeZ * r
    local x2, z2 = e.x + e.lungeX * r, e.z + e.lungeZ * r
    local y1 = atk.contactY
      + Ground.height(g.world, ctx.oldX, ctx.oldZ, e.level)
      - Ground.height(g.world)
    local y2 = atk.contactY + Ground.of(g.world, e) - Ground.height(g.world)
    if not e.didHit then
      if Melee.contact(g, x1, z1, x2, z2, y1, atk.contactRadius, previous, current, y2, t) then
        hurt(g, e, atk, t)
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
    return e.chargeTime
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
    local t = victimOf(g, e)
    local p = pointOf(g, t)
    local _, used = Flight.step(g, e, dt, ctx and ctx.previous)
    if not e.leaping and not e.didHit then
      if used and used < dt then
        p = Melee.playerAt(previousOf(g, t, ctx and ctx.previous) or p, p, used / dt, nil, g.world)
      end
      e.didHit = true
      Flight.land(g, e)
      local reachLand = atk.landRadius + Bodies.extent(g, t)
      local ghost = Dodge.afterimage(g, t)
      if
        len(p.x - e.x, p.z - e.z) < reachLand
        and math.abs(Ground.of(g.world, p) + (p.jump or 0) - Ground.of(g.world, e)) < K.jumpClear
      then
        local packet = Rules.packet(e, atk.packet)
        g:damageBody(t, packet.base, e.x, e.z, packet, e)
      elseif
        ghost
        and len(ghost.x - e.x, ghost.z - e.z) < reachLand
        and math.abs(Ground.of(g.world, ghost) + (ghost.jump or 0) - Ground.of(g.world, e))
          < K.jumpClear
      then
        dodged(g, e, atk, t)
      end
    end
  end,
  duration = function(e)
    return e.leaping and math.huge or 0
  end,
}
return Kinds
