-- Timed attack footprints. Telegraph and damage share the same owner clock;
-- pool pulses sample movement at pulse time, independent of frame rate.
local Spawn = require('src.session.spawn')
local W = require('src.world.arena')
local Area = require('src.combat.area_contact')
local Volumes = require('src.content.defs.area')
local Schema = require('src.core.schema')
local Rules = require('src.combat.rules')
local Dodge = require('src.combat.dodge')
local K = require('src.content.combat_defaults').hazards
local Pools = require('src.session.world')
local Bodies = require('src.combat.bodies')
local Definitions = require('src.content.hazards')
local Registry = require('src.core.registry')
local Hazards = {}
-- Scratch swept points of a creature sampled by a pool pulse.
local sampled = {}
function Hazards.add(g, x, z, delay, r, life, spec)
  if not W.solid(g.world, x, z, K.clearance) then
    Spawn.make(g, 'hazard', {
      kind = spec and spec.kind,
      x = x,
      z = z,
      delay = delay,
      maxDelay = delay,
      radius = r,
      volume = Schema.copy(spec and spec.volume or Volumes.defaults.pool),
      life = life,
      pulse = 0,
      packet = spec and spec.packet,
      interval = spec and spec.pulse,
      condition = spec and spec.condition,
      level = spec and spec.level,
      owner = spec and spec.owner,
      side = spec and spec.side,
    })
  end
end
-- The marked bolt falls once: every body of a hostile side within reach and
-- in sight is struck; a knight who left his afterimage there instead dodges
-- perfectly (knights first, then creatures; plan v10 V2).
local function strike(g, h, t, previousPlayer, dt)
  local effectSource = h.packet and h.packet.effects and { side = h.side or 'demons', id = h.owner }
    or nil
  Bodies.each(g, function(b)
    if not Bodies.harms(g, h.side or 'demons', b, 'hazard') then
      return false
    end
    local previous = b == Bodies.controlled(g) and previousPlayer or Bodies.previous(g, b)
    local point = Area.sample(g, b, previous, t, sampled)
    local volume = h.volume or Volumes.defaults.lightning
    local hit, contact = Area.test(g, h, volume, b, point)
    local ghost = Dodge.afterimage(g, b)
    if hit then
      contact.kind, contact.id, contact.owner, contact.target = 'hazard', h.id, h.owner, b.id
      contact.delivery, contact.time, contact.fraction = 'lightning', t * dt, t
      g:damageBody(b, h.packet and h.packet.base or h.damage, h.x, h.z, h.packet, nil, {
        effectSource = effectSource,
        contact = contact,
      })
    elseif ghost and h.packet and Area.test(g, h, volume, b, ghost) then
      -- The bolt fell where the dodge began: a perfect dodge.
      Dodge.perfect(g, h.packet, nil, b)
    end
    return false
  end)
end
-- One pulse of a pool at time t of the step: every body of a hostile side
-- standing in it (sampled where it moved to by then; poison does not leak
-- through walls) takes the pulse and its condition.
local function pulse(g, h, t, interval, previousPlayer, dt)
  local effectSource = h.packet and h.packet.effects and { side = h.side or 'demons', id = h.owner }
    or nil
  Bodies.each(g, function(b)
    if not Bodies.harms(g, h.side or 'demons', b, 'hazard') then
      return false
    end
    local previous = b == Bodies.controlled(g) and previousPlayer or Bodies.previous(g, b)
    local point = Area.sample(g, b, previous, t, sampled)
    local hit, contact = Area.test(g, h, h.volume or Volumes.defaults.pool, b, point)
    if hit then
      contact.kind, contact.id, contact.owner, contact.target = 'hazard', h.id, h.owner, b.id
      contact.delivery, contact.fraction, contact.time = 'pool', t, t * dt
      g:damageBody(b, h.packet and h.packet.base or K.damage, h.x, h.z, h.packet, nil, {
        effectSource = effectSource,
        contact = contact,
      })
      if h.condition then
        Rules.addCondition(b, h.condition, interval + K.linger)
      end
    end
    return false
  end)
end
-- What each kind does (content/hazards.lua): step(g, h, dt, previousPlayer).
Hazards.kinds = Registry:new('hazard executors', function(entry, id)
  Definitions:get(id)
  assert(type(entry.step) == 'function', 'hazard executor ' .. id .. ' needs step')
end)
Hazards.kinds:register('lightning', {
  step = function(g, h, dt, previousPlayer)
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
      local released = h.justReleased
      local waiting = math.max(0, h.delay)
      local active = released and 0 or math.max(0, dt - waiting)
      h.justReleased = nil
      h.delay = h.delay - dt
      if h.delay <= 0 then
        h.life = h.life - active
        if not h.struck then
          h.struck = true
          -- A just-released cast executes after movement in this step.
          -- A previously placed mark expires at its own point within the step.
          strike(g, h, released and 1 or math.min(1, waiting / dt), previousPlayer, dt)
        end
      end
    end
  end,
})
Hazards.kinds:register('pool', {
  step = function(g, h, dt, previousPlayer)
    local waiting = math.max(0, h.delay)
    local active = math.min(h.life, math.max(0, dt - waiting))
    h.delay = h.delay - dt
    if h.delay <= 0 then
      -- Keep cadence and lifetime independent of delay crossing and frame rate.
      -- Sample the moving player at each pulse; poison does not leak through walls.
      local interval = h.interval or K.pulse
      while h.pulse <= active + 1e-9 and h.pulse < h.life - 1e-9 do
        local t = math.max(0, math.min(1, (waiting + h.pulse) / dt))
        pulse(g, h, t, interval, previousPlayer, dt)
        h.pulse = h.pulse + interval
      end
      h.pulse = h.pulse - active
      h.life = h.life - active
    end
  end,
})
function Hazards.update(g, dt, previousPlayer)
  if not require('src.core.mathx').finite(dt) or dt <= 0 then
    return
  end
  local hazards = Pools.of(g, 'hazards')
  for i = #hazards, 1, -1 do
    local h = hazards[i]
    Hazards.kinds:get(h.kind or Definitions.default).step(g, h, dt, previousPlayer)
    if h.life <= 0 then
      Pools.removeAt(g, 'hazards', i)
    end
  end
end
return Hazards
