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
local MathX = require('src.core.mathx')
local Hazards = {}
local Signal = require('src.session.signal')
local Garden = require('src.combat.garden')
-- Scratch swept points of a creature sampled by a pool pulse.
local sampled = {}
function Hazards.add(g, x, z, delay, r, life, spec)
  if not W.solid(g.world, x, z, K.clearance) then
    Spawn.make(g, 'hazard', {
      kind = spec and spec.kind,
      art = spec and spec.art,
      impactSound = spec and spec.impactSound,
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
          Signal(g, 'GroundStruck', { hazard = h, at = g.elapsed })
        end
      end
    end
  end,
})
Hazards.kinds:register('pool', {
  step = function(g, h, dt, previousPlayer)
    Garden.watch(g, h)
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
-- One blow of a moving hazard, once per body: the same receipt and the same dodge
-- as any contact. test(b, point): whether it reaches that point now.
local function passing(g, h, previousPlayer, delivery, dt, test)
  local effectSource = h.packet and h.packet.effects and { side = h.side or 'demons', id = h.owner }
    or nil
  Bodies.each(g, function(b)
    -- A hand-made knight has no id; it is the only one then.
    local key = b.id or 'knight'
    if (h.hits and h.hits[key]) or not Bodies.harms(g, h.side or 'demons', b, 'hazard') then
      return false
    end
    local previous = b == Bodies.controlled(g) and previousPlayer or Bodies.previous(g, b)
    local point = Area.sample(g, b, previous, 1, sampled)
    local hit, contact = test(b, point)
    local ghost = not hit and Dodge.afterimage(g, b)
    if hit or (ghost and test(b, ghost)) then
      h.hits = h.hits or {}
      h.hits[key] = true
    end
    if hit then
      contact.kind, contact.id, contact.owner, contact.target = 'hazard', h.id, h.owner, b.id
      contact.delivery, contact.time, contact.fraction = delivery, dt, 1
      g:damageBody(b, h.packet.base, h.x, h.z, h.packet, nil, {
        effectSource = effectSource,
        contact = contact,
      })
    elseif ghost and test(b, ghost) then
      Dodge.perfect(g, h.packet, nil, b)
    end
    return false
  end)
end
-- A ring: it strikes what it reaches, never what it already left behind.
Hazards.kinds:register('wave', {
  step = function(g, h, dt, previousPlayer)
    local waiting = math.max(0, h.delay)
    h.delay = h.delay - dt
    if h.delay > 0 then
      return
    end
    local inner = h.radius
    h.radius = math.min(h.reach, h.radius + h.spread * math.max(0, dt - waiting))
    passing(g, h, previousPlayer, 'wave', dt, function(b, point)
      local radius = Bodies.extent(g, b)
      if MathX.len(point.x - h.x, point.z - h.z) + radius < inner - h.width then
        return false
      end
      return Area.test(g, h, h.volume, b, point)
    end)
    h.life = h.radius >= h.reach and 0 or h.life
  end,
})
-- A ray turning about its origin: it strikes what it crossed in this step, and
-- stone stands in its way (combat/area_contact.lua).
Hazards.kinds:register('sweepline', {
  step = function(g, h, dt, previousPlayer)
    local waiting = math.max(0, h.delay)
    h.delay = h.delay - dt
    if h.delay > 0 then
      return
    end
    local active = math.min(h.life, math.max(0, dt - waiting))
    local from, turn = h.angle, h.spin * active
    h.angle, h.life = from + turn, h.life - active
    local sign = h.spin < 0 and -1 or 1
    passing(g, h, previousPlayer, 'sweepline', dt, function(b, point)
      local dx, dz = point.x - h.x, point.z - h.z
      local d = math.max(1e-6, MathX.len(dx, dz))
      local radius = Bodies.extent(g, b)
      local off = MathX.wrapAngle(math.atan2(dx, dz) - from) * sign
      local margin = math.atan2(radius + (h.width or 0) / 2, d)
      if off < -margin or off > math.abs(turn) + margin then
        return false
      end
      return Area.test(g, h, h.volume, b, point)
    end)
  end,
})
-- The room strikes in pulses; only the circle that wanders is safe.
Hazards.kinds:register('tempest', {
  step = function(g, h, dt)
    local waiting = math.max(0, h.delay)
    h.delay = h.delay - dt
    local active = math.min(h.life, math.max(0, dt - waiting))
    h.angle = h.angle + h.spin * dt
    h.x = h.centerX + math.sin(h.angle) * h.orbit
    h.z = h.centerZ + math.cos(h.angle) * h.orbit
    if h.delay > 0 then
      return
    end
    h.life = h.life - active
    h.pulse = h.pulse - active
    if h.pulse > 1e-9 then
      return
    end
    h.pulse = h.pulse + h.interval
    Bodies.each(g, function(b)
      if
        Bodies.harms(g, h.side or 'demons', b, 'hazard')
        and MathX.len(b.x - h.x, b.z - h.z) > h.radius
      then
        g:damageBody(b, h.packet.base, h.centerX, h.centerZ, h.packet, nil, {
          contact = {
            kind = 'hazard',
            id = h.id,
            owner = h.owner,
            target = b.id,
            delivery = 'tempest',
            geometry = 'outside-safe-circle',
          },
        })
      end
      return false
    end)
  end,
})
function Hazards.update(g, dt, previousPlayer)
  if not MathX.finite(dt) or dt <= 0 then
    return
  end
  local hazards = Pools.of(g, 'hazards')
  for i = #hazards, 1, -1 do
    local h = hazards[i]
    Hazards.kinds:get(h.kind or Definitions.default).step(g, h, dt, previousPlayer)
    if h.life <= 0 then
      if h.art then
        Signal(g, 'HazardEnded', { hazard = h, at = g.elapsed })
      end
      Pools.removeAt(g, 'hazards', i)
    end
  end
end
return Hazards
