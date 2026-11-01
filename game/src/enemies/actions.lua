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
local Selection = require('src.enemies.attack_selection')
local ActionKinds = require('src.combat.action_kinds')
local Action = require('src.content.defs.action')
local Attacks = {}
local sin, cos, atan2 = math.sin, math.cos, math.atan2
local len = MathX.len
local angle = MathX.wrapAngle
local arch = Rules.archetype
local K = require('src.content.combat_defaults').attacks
local function change(e, state)
  e.ai = state
  e.phase = 0
  e.rushVX, e.rushVZ = nil, nil
end
local choose = Selection.choose
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
-- Everything a kind of attack does lives in one entry of combat/action_kinds.lua,
-- so a new kind is one entry plus data in content/enemies.lua (the fields of
-- each kind and their defaults: content/defs/action.lua).
-- A kind that moves the body writes the velocity it moves with to
-- e.rushVX / e.rushVZ; the shared rules read it (counter-hits, trips)
-- without knowing which kind it is.
for _, family in ipairs({ require('src.enemies.melee_kinds'), require('src.enemies.ranged_kinds') }) do
  for id, kind in pairs(family) do
    ActionKinds:register(id, kind)
  end
end
local Kinds = ActionKinds:view()
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
  Signal(g, 'AttackReleased', { enemy = e, attack = atk })
end
local function beginAttack(g, e, d, chosen)
  local atk = chosen or choose(e, d, g.elapsed, g.rng and g.rng.sim)
  if not atk then
    return false
  end
  -- Session tallies for balance reports (qa/scenarios/playtest.lua).
  g.attackStarts = (g.attackStarts or 0) + 1
  if Action.trait(atk, 'airborne') then
    g.leapStarts = (g.leapStarts or 0) + 1
  end
  if atk.rest then
    e.restUntil = e.restUntil or {}
    e.restUntil[atk.id] = (g.elapsed or 0) + atk.rest / Selection.pace(e)
  end
  e.attackSpec = atk
  e.attackKind = atk.id
  change(e, 'windup')
  e.windupDuration = atk.windup
  local p = victimOf(g, e)
  Selection.committed(e, atk, p.id)
  -- An attack from outside a knight's view is announced longer (fairness);
  -- a body without a view (a creature) gets no such grace.
  local inView = not p.yaw or cos(angle(atan2(e.x - p.x, e.z - p.z) - p.yaw)) > K.viewCos
  if not inView then
    e.windupDuration = e.windupDuration + K.unseenWindup
  end
  e.windup = e.windupDuration
  local rng = g.rng and g.rng.sim
  e.holdLeft = atk.hold and atk.hold[e.attackCount % #atk.hold + 1] or nil
  if atk.hold and atk.shuffle and rng then
    e.holdLeft = atk.hold[math.floor(rng:random() * #atk.hold) + 1]
  end
  -- The side a mirrored blow comes from is rolled here and shown by the body.
  e.swingSide = atk.mirror and rng and (rng:random() < 0.5 and -1 or 1) or nil
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
  local lead = atk.aimLead * (atk.leadFloor or 0)
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
-- What a blow goes on with: its one next blow, or a roll among its branches, one of
-- which may be to stop. Nothing about the first blow says which.
local function nextOf(g, flow)
  if not flow.branches then
    return flow.into
  end
  local total = 0
  for _, branch in ipairs(flow.branches) do
    total = total + branch.weight
  end
  local roll = (g.rng and g.rng.sim:random() or 0) * total
  for _, branch in ipairs(flow.branches) do
    roll = roll - branch.weight
    if roll < 0 then
      return branch.into
    end
  end
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
    Selection.finished(e, atk, g.elapsed)
    change(e, 'recover')
    local flow = atk.string
    local into = flow and (not flow.every or e.attackCount % flow.every == 0) and nextOf(g, flow)
    if into then
      e.chain, e.chainFrom = into, atk.id
      e.recover = flow.gap
    else
      Attacks.rest(e, atk)
    end
    if e.guardFalling then
      Rules.guard(e, 0)
    end
  end
end
-- The full rest after an attack. A phase's pace shortens the pause between
-- attacks, never a windup.
function Attacks.rest(e, atk)
  e.recover = atk.recover
  e.attack = atk.cooldown / Selection.pace(e)
end
-- The next blow of a string, when its beat ran out. A string the target left
-- behind ends as the last blow would have.
function Attacks.flow(g, e, d)
  local list = arch(e).attacks
  local nextBlow, last
  for _, atk in ipairs(list) do
    if atk.id == e.chain then
      nextBlow = atk
    elseif atk.id == e.chainFrom then
      last = atk
    end
  end
  e.chain, e.chainFrom = nil, nil
  if nextBlow and e.visible and d <= nextBlow.range and d >= nextBlow.minRange then
    return Attacks.begin(g, e, d, nextBlow)
  end
  if last then
    Attacks.rest(e, last)
  end
  return false
end
-- A turning blow goes where the body faces: the body turns at its rate until
-- lockAt of the windup, and a dodge before that is followed. Otherwise the aim
-- follows the target for the first share of a tracking windup.
function Attacks.track(g, e, atk, dt)
  if atk.turn then
    local p = victimOf(g, e)
    if e.windup >= e.windupDuration * (1 - atk.lockAt) then
      local most = atk.turn * dt
      local off = angle(atan2(p.x - e.x, p.z - e.z) - e.facing)
      e.facing = e.facing + math.max(-most, math.min(most, off))
    end
    local d = math.max(1, len(p.x - e.x, p.z - e.z))
    e.aimX, e.aimZ, e.aimLevel = e.x + sin(e.facing) * d, e.z + cos(e.facing) * d, p.level
    return
  end
  if atk.track and e.windup > e.windupDuration * (1 - atk.track) then
    local p = victimOf(g, e)
    e.aimX, e.aimZ, e.aimLevel = p.x, p.z, p.level
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
