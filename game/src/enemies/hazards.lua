-- Timed attack footprints. Telegraph and damage share the same owner clock;
-- pool pulses sample movement at pulse time, independent of frame rate.
local Spawn = require('src.session.spawn')
local MathX = require('src.core.mathx')
local W = require('src.world.arena')
local Rules = require('src.combat.rules')
local Dodge = require('src.combat.dodge')
local K = require('src.content.combat_defaults').hazards
local Hazards = {}
local len = MathX.len
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
    })
  end
end
function Hazards.update(g, dt, previousPlayer)
  local p = g.player
  for i = #g.hazards, 1, -1 do
    local h = g.hazards[i]
    if h.kind == 'lightning' then
      local owner
      for _, e in ipairs(g.enemies) do
        if e.id == h.owner and e.hp > 0 then
          owner = e
          break
        end
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
            local reach = h.radius + Rules.playerBody().radius
            local ghost = Dodge.afterimage(g)
            if len(p.x - h.x, p.z - h.z) < reach and W.visible(g.world, h.x, h.z, p.x, p.z) then
              g:damagePlayer(h.packet and h.packet.base or h.damage, h.x, h.z, h.packet)
            elseif
              ghost
              and h.packet
              and len(ghost.x - h.x, ghost.z - h.z) < reach
              and W.visible(g.world, h.x, h.z, ghost.x, ghost.z)
            then
              -- The bolt fell where the dodge began: a perfect dodge.
              Dodge.perfect(g, h.packet, nil)
            end
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
          local before = previousPlayer or p
          local x = before.x + (p.x - before.x) * t
          local z = before.z + (p.z - before.z) * t
          local jump = before.jump + (p.jump - before.jump) * t
          if
            len(x - h.x, z - h.z) < h.radius
            and jump < K.jumpClear
            and W.visible(g.world, h.x, h.z, x, z)
          then
            g:damagePlayer(h.packet and h.packet.base or K.damage, h.x, h.z, h.packet)
            if h.condition then
              Rules.addCondition(p, h.condition, interval + K.linger)
            end
          end
          h.pulse = h.pulse + interval
        end
        h.pulse = h.pulse - active
        h.life = h.life - active
      end
    end
    if h.life <= 0 then
      table.remove(g.hazards, i)
    end
  end
end
return Hazards
