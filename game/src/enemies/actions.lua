-- Data-driven attack lifecycle: selection, commitment, release and the
-- strike state. AI decides WHEN to begin; archetypes describe WHAT; this
-- module runs it. What each kind of attack does when it meets a body is its
-- kind's (enemies/melee_kinds.lua, enemies/ranged_kinds.lua, sharing
-- enemies/attack_contact.lua); a body in the air is enemies/flight.lua's.
local Signal = require('src.session.signal')
local MathX = require('src.core.mathx')
local W = require('src.world.arena')
local Rules = require('src.combat.rules')
local Flight = require('src.enemies.flight')
local Contact = require('src.enemies.attack_contact')
local Attacks = {}
local cos, atan2 = math.cos, math.atan2
local len = MathX.len
local angle = MathX.wrapAngle
local arch = Rules.archetype
local K = require('src.content.combat_defaults').attacks
local function change(e, state)
  e.ai = state
  e.phase = 0
  e.rushVX, e.rushVZ = nil, nil
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
for _, family in ipairs({ require('src.enemies.melee_kinds'), require('src.enemies.ranged_kinds') }) do
  for id, kind in pairs(family) do
    Kinds[id] = kind
  end
end
Attacks.kinds = Kinds
local victimOf = Contact.victim
local function kindOf(atk)
  return Kinds[atk.kind] or error('unknown attack kind: ' .. tostring(atk.kind))
end
local function execute(g, e)
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
  local p = victimOf(g, e)
  -- An attack from outside a knight's view is announced longer (fairness);
  -- a body without a view (a creature) gets no such grace.
  local inView = not p.yaw or cos(angle(atan2(e.x - p.x, e.z - p.z) - p.yaw)) > K.viewCos
  if not inView then
    e.windupDuration = e.windupDuration + K.unseenWindup
  end
  e.windup = e.windupDuration
  e.aimX = p.x
  e.aimZ = p.z
  e.aimLevel = p.level
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
  if not kind.unseen and not Rules.sees(g, e, p, e.aimX, e.aimZ) then
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
end
-- A body in the air and its landing (enemies/flight.lua).
Attacks.land = Flight.land
Attacks.flight = Flight.step
Attacks.kindOf = kindOf
Attacks.choose = choose
Attacks.current = current
Attacks.reach = reach
Attacks.begin = beginAttack
Attacks.execute = execute
Attacks.strike = strike
return Attacks
