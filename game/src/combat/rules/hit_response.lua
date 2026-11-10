-- Hit response: everything a resolved weapon hit does to an enemy body
-- (shove, counter, guard, cripple, trip, major wound, hit-stop, flinch).
-- Part of the rules facade (src/combat/rules.lua); functions are installed
-- on the shared rules table R and call each other through it.
local Archetypes = require('src.content.enemies')
local Roles = require('src.core.roles')
local Flinch = require('src.enemies.flinch')
local defaults = Archetypes.defaults
local sqrt, min, max = math.sqrt, math.min, math.max
return function(R)
  -- Response of an enemy body to a resolved hit. impact is the guard damage of
  -- the whole volley, health the HP it actually removed (may be nil for legacy
  -- callers), point the mean contact point. extra (optional): push (physical
  -- impulse, defaults to impact), lower (guard impact landed on the legs),
  -- direction {dx, dz} (incoming horizontal impulse, independent of the viewer),
  -- counter (the blow met the body's own lunge or charge). strong is kept for
  -- older callers and no longer chooses a formula.
  -- The wound alone, the one way health leaves a creature. source: who or what
  -- did it; payload: effects it carries; owner: the id at the head of its chain;
  -- weapon: the weapon id behind it.
  function R.wound(g, target, damage, source, payload, owner, weapon)
    return g:damageEnemy(target, damage, source, payload, owner, weapon)
  end
  function R.react(g, e, impact, strong, point, health, extra)
    local p = Roles.controlled(g)
    local b = R.body(e)
    extra = extra or {}
    local dx, dz = e.x - p.x, e.z - p.z
    if extra.direction then
      dx, dz = extra.direction[1], extra.direction[2]
    end
    local len = sqrt(dx * dx + dz * dz)
    local elite = R.elite(e)
    local mass = b.mass or e.mass or 1
    local push = extra.push or impact
    local force, n = R.shove(push, mass)
    local nx, nz = 0, 0
    if len > defaults.sameSpot then
      nx, nz = dx / len, dz / len
    end
    -- Counter: the body's own rush toward the shooter (closing speed u).
    local rx, rz = R.rush(e)
    local closing = rx and max(0, -(rx * nx + rz * nz)) or 0
    local counter = closing >= defaults.counter.minSpeed or extra.counter or nil
    if counter and closing < defaults.counter.minSpeed then
      closing = defaults.counter.refSpeed
    end
    local parried = R.parries(e, impact, sqrt((e.x - p.x) ^ 2 + (e.z - p.z) ^ 2))
    local broke, heavy = parried, false
    if parried then
      R.parried(e)
    else
      broke, heavy = R.guard(e, impact, { closing = counter and closing or 0 })
    end
    local result = { staggered = broke, heavy = heavy, counter = counter, parried = parried }
    if len > defaults.sameSpot then
      if e.hp <= 0 and not elite then
        -- A killing blow carries the body further: overkill becomes visible weight.
        local throw = force * (defaults.killThrow.base + defaults.killThrow.gain * n)
        R.addPush(e, nx, nz, throw, mass)
        -- A throw fast enough lifts the killed body off its feet (see AI fall).
        local fall = defaults.fall
        if throw > fall.liftFrom and not e.fallLanded then
          e.fallVY = max(e.fallVY or 0, min(fall.maxLift, throw * fall.lift))
          e.fallY = e.fallY or 0
        end
      elseif rx and e.hp > 0 then
        result.stopped = R.meetRush(e, rx, rz, nx * force, nz * force, mass)
      else
        -- Braced feet keep part of the shove unless the balance is lost.
        local brace = heavy and 1 or (b.brace or defaults.brace)
        R.addPush(e, nx, nz, force * brace, mass)
      end
    end
    -- A rush reversed by the blow stops dead: the body is knocked down.
    if result.stopped and not elite then
      R.knockDown(e)
    end
    result.falter = elite and result.staggered or nil
    if elite and not b.steadfast and not result.staggered and n > 0.5 then
      R.stunBriefly(e, b.microStun or 0, 'micro') -- microStun: bosses only
    end
    -- Legs: a leg blow worth part of the guard cripples the body for a while.
    local lower = defaults.zones.lower
    if not elite and e.hp > 0 and (extra.lower or 0) >= lower.cripple * b.poise then
      R.addCondition(e, 'crippled', defaults.crippleTime)
      result.crippled = true
    end
    -- Trip (Call of Duty leg shot / Gemini review): a leg blow of tripImpact
    -- guard damage on a body that is lunging, leaping or charging takes its
    -- legs away. A demon falls out of its attack; a boss's charge stops short.
    -- Any attack that moves the body counts (its rush velocity), whatever its kind.
    local rushing = rx ~= nil
    if rushing and e.hp > 0 and (extra.lower or 0) >= defaults.tripImpact then
      if elite then
        e.chargeTime = math.min(e.chargeTime or 0, e.phase or 0)
        R.stunBriefly(e, defaults.knockdown / R.stability(e), 'trip')
      else
        R.knockDown(e)
      end
      result.tripped = true
    end
    -- Major wound: one hit removing a large share of the body breaks the guard
    -- even under a stagger lock. Bosses use woundAt=1 (never from one hit).
    if health and e.hp > 0 and not elite and health >= b.woundAt * (e.maxHp or b.hp) then
      local spec = e.attackSpec
      if spec and spec.steady and (e.ai == 'windup' or e.ai == 'strike') then
        -- Fire takes no blow away (owner, D24): a steady blow is not stopped by a wound
        -- either. The body reels when it has struck (enemies/actions.lua).
        e.woundFalling = true
      else
        R.reel(e)
      end
      R.addCondition(e, 'wounded', defaults.woundFor)
      R.markBroken(e, 'wound')
      e.woundFlash = defaults.woundFlash
      result.wounded = true
    end
    -- A killing blow always holds the body before it falls; only the body stops, never the knight.
    if e.hp <= 0 then
      e.hitPause = defaults.killPause
    elseif push >= defaults.hitPausePush and not b.steadfast then
      e.hitPause = defaults.hitPause
    end
    -- A major wound holds the struck body a beat longer (victim-only hit-stop).
    if result.wounded then
      e.hitPause = max(e.hitPause or 0, defaults.woundPause)
    end
    -- The hit's source defines the painted reaction, not the controlled view.
    -- Drawing projects this basis for each observer without changing the body.
    -- Heavier bodies give way less: flinch = impact / (scale * sqrt(mass)).
    local spring = defaults.flinch
    local f = min(1, impact / (spring.scale * sqrt(b.mass)))
    e.flinch = max(e.flinch or 0, f)
    if point then
      local sideX, sideZ = Flinch.begin(g, e, extra.origin or p)
      local side = (point[1] - e.x) * sideX + (point[3] - e.z) * sideZ
      e.flinchSide = side > defaults.flinchSide and 1 or (side < -defaults.flinchSide and -1 or 0)
      e.flinchLeanV = (e.flinchLeanV or 0) - spring.impulse * f * e.flinchSide
    end
    return result
  end
end
