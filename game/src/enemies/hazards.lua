-- Timed attack footprints. Telegraph and damage share the same owner clock;
-- pool pulses sample movement at pulse time, independent of frame rate.
local Spawn = require('src.session.spawn')
local MathX = require('src.core.mathx')
local W = require('src.world.arena')
local Ground = require('src.physics.ground')
local Rules = require('src.combat.rules')
local Dodge = require('src.combat.dodge')
local K = require('src.content.combat_defaults').hazards
local Pools = require('src.session.world')
local Bodies = require('src.combat.bodies')
local Hazards = {}
local len = MathX.len
-- Scratch swept points of a creature sampled by a pool pulse.
local sampled, current = {}, {}
function Hazards.add(g, x, z, delay, r, life, spec)
  if not W.solid(g.world, x, z, K.clearance) then
    Spawn.make(g, 'hazard', {
      x = x,
      z = z,
      delay = delay,
      maxDelay = delay,
      radius = r,
      life = life,
      pulse = 0,
      packet = spec and spec.packet,
      interval = spec and spec.pulse,
      condition = spec and spec.condition,
      owner = spec and spec.owner,
      side = spec and spec.side,
    })
  end
end
-- The marked bolt falls once: every body of a hostile side within reach and
-- in sight is struck; a knight who left his afterimage there instead dodges
-- perfectly (knights first, then creatures; plan v10 V2).
local function strike(g, h)
  local effectSource = h.packet and h.packet.effects and { side = h.side or 'demons', id = h.owner }
    or nil
  Bodies.each(g, function(b)
    if not Bodies.harms(g, h.side or 'demons', b, 'hazard') then
      return false
    end
    local reach = h.radius + Bodies.extent(g, b)
    local ghost = Dodge.afterimage(g, b)
    if len(b.x - h.x, b.z - h.z) < reach and W.visible(g.world, h.x, h.z, b.x, b.z) then
      g:damageBody(
        b,
        h.packet and h.packet.base or h.damage,
        h.x,
        h.z,
        h.packet,
        nil,
        effectSource and { effectSource = effectSource }
      )
    elseif
      ghost
      and h.packet
      and len(ghost.x - h.x, ghost.z - h.z) < reach
      and W.visible(g.world, h.x, h.z, ghost.x, ghost.z)
    then
      -- The bolt fell where the dodge began: a perfect dodge.
      Dodge.perfect(g, h.packet, nil, b)
    end
    return false
  end)
end
-- One pulse of a pool at time t of the step: every body of a hostile side
-- standing in it (sampled where it moved to by then; poison does not leak
-- through walls) takes the pulse and its condition.
local function pulse(g, h, t, interval, previousPlayer)
  local effectSource = h.packet and h.packet.effects and { side = h.side or 'demons', id = h.owner }
    or nil
  Bodies.each(g, function(b)
    if not Bodies.harms(g, h.side or 'demons', b, 'hazard') then
      return false
    end
    local before
    if b == Bodies.controlled(g) then
      before = previousPlayer or b
    else
      before = Bodies.sweep(g, Bodies.previous(g, b), sampled)
    end
    local now = Bodies.sweep(g, b, current)
    local x = before.x + (now.x - before.x) * t
    local z = before.z + (now.z - before.z) * t
    local jump = before.jump + (now.jump - before.jump) * t
    if
      len(x - h.x, z - h.z) < h.radius
      and math.abs(Ground.height(g.world, x, z) + jump - Ground.height(g.world, h.x, h.z)) < K.jumpClear
      and W.visible(g.world, h.x, h.z, x, z)
    then
      g:damageBody(
        b,
        h.packet and h.packet.base or K.damage,
        h.x,
        h.z,
        h.packet,
        nil,
        effectSource and { effectSource = effectSource }
      )
      if h.condition then
        Rules.addCondition(b, h.condition, interval + K.linger)
      end
    end
    return false
  end)
end
function Hazards.update(g, dt, previousPlayer)
  local hazards = Pools.of(g, 'hazards')
  for i = #hazards, 1, -1 do
    local h = hazards[i]
    if h.kind == 'lightning' then
      local owner = Pools.get(g, h.owner)
      if owner and owner.hp <= 0 then
        owner = nil
      end
      if not owner or h.cancelled then
        h.life = 0
      elseif h.waitForCast then
        -- A staggered caster cannot deal damage before its windup has finished.
        -- The displayed circle shares the exact same clock as the casting pose.
        if owner.ai ~= 'windup' then
          h.life = 0
          owner.pendingHazard = nil
        else
          h.delay = owner.windup
        end
      else
        local active = h.justReleased and 0 or math.max(0, dt - math.max(0, h.delay))
        h.justReleased = nil
        h.delay = h.delay - dt
        if h.delay <= 0 then
          h.life = h.life - active
          if not h.struck then
            h.struck = true
            strike(g, h)
          end
        end
      end
    else
      local waiting = math.max(0, h.delay)
      local active = math.min(h.life, math.max(0, dt - waiting))
      h.delay = h.delay - dt
      if h.delay <= 0 then
        -- Keep cadence and lifetime independent of delay crossing and frame rate.
        -- Sample the moving player at each pulse; poison does not leak through walls.
        local interval = h.interval or K.pulse
        while h.pulse <= active + 1e-9 and h.pulse < h.life - 1e-9 do
          local t = math.max(0, math.min(1, (waiting + h.pulse) / dt))
          pulse(g, h, t, interval, previousPlayer)
          h.pulse = h.pulse + interval
        end
        h.pulse = h.pulse - active
        h.life = h.life - active
      end
    end
    if h.life <= 0 then
      Pools.removeAt(g, 'hazards', i)
    end
  end
end
return Hazards
