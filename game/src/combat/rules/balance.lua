-- Balance: guard (poise), its recovery, the two stagger tiers, the lock,
-- interrupting an action and knocking a body down.
-- Part of the rules facade (src/combat/rules.lua); functions are installed
-- on the shared rules table R and call each other through it.
local ActionKinds = require('src.combat.action_kinds')
local Archetypes = require('src.content.enemies')
local defaults = Archetypes.defaults
local sqrt, min, max = math.sqrt, math.min, math.max
return function(R)
  -- Rules may interrupt intent, but never call the AI scheduler. Keeping this
  -- transition here removes the former rules -> AI -> rules dependency cycle.
  function R.interrupt(e)
    if not R.body(e).boss then
      e.windup = 0
      e.ai = 'hurt'
      e.phase = 0
      e.rushVX, e.rushVZ = nil, nil
      e.evadeTime = 0
      e.recover = defaults.interruptRecover
      ActionKinds.abandon(e)
    end
  end
  -- The moment a body lost its balance (a broken guard, a fall, a major
  -- wound), on its own clock: a kill soon after is a break kill. cause:
  -- 'guard', 'wound' or 'knockdown'; one blow may give several (the same
  -- moment keeps them all, a later moment starts a new set).
  function R.markBroken(e, cause)
    local age = e.spawnAge or 0
    if e.brokenAge ~= age or not e.brokenBy then
      e.brokenBy = {}
    end
    e.brokenAge = age
    e.brokenBy[cause] = true
  end
  -- A stun that is not a lost balance (a boss's micro-stun, a boss's charge
  -- tripped short): it counts while it lasts; cause names it.
  function R.stunBriefly(e, t, cause)
    if t > (e.stun or 0) then
      e.stun = t
      e.stunCause = cause
    end
  end
  -- The one decision of a break kill (session/damage_outcomes.lua, at the
  -- moment of death, before the killing blow's own response): whether the
  -- body was off balance, and every cause that held. causes is filled in
  -- (guard, wound, knockdown, micro, trip: booleans; they may overlap).
  -- Off balance: stunned, staggered or exposed now, or broken within the
  -- break-kill window (a major wound counts as broken: combat_defaults).
  function R.offBalance(e, causes)
    local recent = e.brokenAge ~= nil
      and (e.spawnAge or 0) - e.brokenAge <= defaults.breakKill.window
    local stunned = (e.stun or 0) > 0
    local staggered, exposed = R.has(e, 'staggered'), R.has(e, 'exposed')
    local by = recent and e.brokenBy or {}
    causes.guard = (by.guard or exposed) or false
    causes.wound = by.wound or false
    causes.knockdown = (by.knockdown or (stunned and e.knockedDown)) or false
    -- A stun alone, with no lost balance behind it: what set it.
    local brief = stunned and not recent and not staggered and not exposed and not e.knockedDown
    causes.micro = brief and e.stunCause == 'micro' or false
    causes.trip = brief and e.stunCause == 'trip' or false
    return stunned or staggered or exposed or recent or false
  end
  -- Knocked down: out of the attack, on the floor for knockdown / stability.
  function R.knockDown(e)
    local t = defaults.knockdown / R.stability(e)
    R.markBroken(e, 'knockdown')
    R.interrupt(e)
    e.stun = max(e.stun or 0, t)
    e.knockedDown = true
    e.knockTime = e.stun
    R.addCondition(e, 'staggered', t)
    return t
  end
  -- Length of the lock after a broken guard (bosses lock much longer).
  function R.lockTime(e)
    return e and R.body(e).boss and defaults.bossLock or defaults.staggerLock
  end
  -- The current threshold, shared with the guard meter. Hyperarmour belongs
  -- to an attack's active commitment, not to the body's permanent rating.
  function R.guardThreshold(e)
    local guard, spec = R.body(e).poise, e.attackSpec
    if spec and spec.hyper and (e.ai == 'windup' or e.ai == 'strike') then
      guard = guard * spec.hyper
    end
    return guard
  end
  -- Balance time of a broken guard (Doom falter tiers, one formula for every
  -- body): r = (G - P) / P picks a light falter or a heavy stagger, and the
  -- time is divided by the body's stability. body: archetype body (optional;
  -- its own stagger tiers override the defaults). Returns time and heavy.
  function R.staggerTime(accumulated, guard, body)
    local r = max(0, accumulated - guard) / max(1, guard)
    local tiers = body and body.stagger or defaults.stagger
    local light, heavy = tiers.light, tiers.heavy
    local s = body and (body.stability or sqrt(body.mass or 1)) or 1
    if r < heavy.from then
      return (light.base + light.gain * r) / s, false
    end
    return min(heavy.max, heavy.base + heavy.gain * (r - heavy.from)) / s, true
  end
  -- Guard (poise): impact accumulates; crossing the body's guard staggers it
  -- once per lock. Shared by weapon hits, wall slams and collisions. A boss
  -- falters instead: its committed attack is delayed, never cancelled, and its
  -- armour is halved while exposed. opts.closing: the speed of the body's own
  -- rush toward the blow (a counter adds the body's momentum to the guard
  -- damage); opts.counter alone assumes counter.refSpeed. Returns true when
  -- the guard broke now, and whether the stagger is heavy.
  function R.guard(e, impact, opts)
    local b = R.body(e)
    if type(opts) ~= 'table' then
      opts = {}
    end
    local boss = b.boss or e.boss
    local guard = R.guardThreshold(e)
    local C = defaults.counter
    local closing = opts.closing or (opts.counter and C.refSpeed) or 0
    local momentum = 0
    if closing > 0 then
      momentum = min(C.cap * guard, C.guardPerMomentum * b.mass * closing)
    end
    impact = max(0, impact or 0) + momentum
    e.guardQuiet = 0
    -- During the lock after a break the guard takes nothing: otherwise the
    -- blows of the lock would pile up and the first touch after it would
    -- always be a heavy stagger.
    if (e.staggerLock or 0) > 0 then
      return false, false
    end
    e.poise = (e.poise or 0) + impact
    if e.poise < guard then
      return false, false
    end
    local t, heavy = R.staggerTime(e.poise, guard, b)
    if boss then
      ActionKinds.release(e)
      e.stun = max(e.stun or 0, t)
      e.staggerLock = defaults.bossLock
      R.addCondition(e, 'exposed', defaults.bossExposed)
    else
      e.stun = max(e.stun or 0, t)
      e.staggerLock = defaults.staggerLock
      R.addCondition(e, 'staggered', e.stun)
      R.interrupt(e)
      -- A counter that breaks the guard knocks the body down (momentum meets
      -- momentum).
      if closing > 0 then
        R.knockDown(e)
      end
    end
    e.heavyStagger = heavy
    e.poise = 0
    e.breakFlash = defaults.breakFlash
    R.markBroken(e, 'guard')
    return true, heavy
  end
  -- Guard recovery, shared by every body (Souls): nothing for regenDelay s
  -- after the last blow, then regenRate * guard per second; plague halves it.
  -- body: the archetype body (a number keeps the old constant rate).
  function R.recover(target, dt, body)
    if type(body) == 'number' then
      target.poise = max(0, (target.poise or 0) - dt * body * R.recoveryScale(target))
      return
    end
    body = body or R.body(target)
    local delay = body.regenDelay or defaults.regenDelay
    local rate = (body.regenRate or defaults.regenRate) * body.poise
    -- A wounded body recovers its guard slower (Sekiro posture).
    local share = defaults.regenHealthShare or 0
    local maxHp = target.maxHp or body.hp
    if share > 0 and maxHp and maxHp > 0 and target.hp then
      rate = rate * ((1 - share) + share * math.max(0, math.min(1, target.hp / maxHp)))
    end
    local quiet = (target.guardQuiet or delay) + dt
    target.guardQuiet = quiet
    local active = min(dt, max(0, quiet - delay))
    if active > 0 then
      local poise = target.poise or 0
      target.poise = poise > 0 and max(0, poise - active * rate * R.recoveryScale(target)) or 0
    end
  end
end
