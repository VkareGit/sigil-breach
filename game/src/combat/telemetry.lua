-- Session measurements (0.24): the same numbers in real play and in the QA
-- bots, so a balance change is judged by data, not by impression. Counters
-- only; nothing here changes the game.
--   control uptime: the share of demon lifetime spent unable to act
--     (stunned, staggered, knocked down). High uptime = the player controls
--     the fight; near 0 = the demons are never interrupted.
--   time to kill: seconds from a demon's arrival to its death.
local T = {}
local NONE = {}
local percent = 100
local function fresh()
  return {
    enemyTime = 0,
    controlTime = 0,
    lightStaggers = 0,
    heavyStaggers = 0,
    counters = 0,
    knockdowns = 0,
    trips = 0,
    wounds = 0,
    kills = 0,
    breakKills = 0,
    healed = 0,
    healingPotential = 0,
    healingWasted = 0,
    awareTime = 0,
    engagedTime = 0,
    knockdownTime = 0,
    exposedTime = 0,
    staggerTime = 0,
    flinchTime = 0,
    awareKillSum = 0,
    awareKillCount = 0,
    firstHitKillSum = 0,
    firstHitKillCount = 0,
    breakGuard = 0,
    breakWound = 0,
    breakKnockdown = 0,
    breakMicro = 0,
    breakTrip = 0,
    breakOther = 0,
    perfectDodges = 0,
    ttkSum = 0,
    ttkCount = 0,
    hitsTaken = 0,
    damageTaken = 0,
  }
end
function T.get(g)
  g.telemetry = g.telemetry or fresh()
  return g.telemetry
end
function T.reset(g)
  g.telemetry = fresh()
  g.telemetryBodies = {}
  return g.telemetry
end
local function bodyRecord(g, e)
  g.telemetryBodies = g.telemetryBodies or {}
  local record = g.telemetryBodies[e.id]
  if not record then
    record = {}
    g.telemetryBodies[e.id] = record
  end
  return record
end
function T.aware(g, e)
  if e.dummy then
    return
  end
  local record = bodyRecord(g, e)
  record.awareAt = record.awareAt or g.elapsed
end
function T.hit(g, e)
  if e.dummy then
    return
  end
  local record = bodyRecord(g, e)
  record.firstHitAt = record.firstHitAt or g.elapsed
  T.aware(g, e)
end
-- The causes come with the kill (combat/rules/balance.lua: offBalance, the
-- one decision); this only counts them. They overlap: a revolver blow can
-- break a guard AND wound. breakOther counts a break kill with no named
-- cause (none is expected; a new way to lose balance would show here).
local causeKeys = {
  guard = 'breakGuard',
  wound = 'breakWound',
  knockdown = 'breakKnockdown',
  micro = 'breakMicro',
  trip = 'breakTrip',
}
function T.healing(g, event)
  local t = T.get(g)
  t.healingPotential = t.healingPotential + event.heal
  t.healingWasted = t.healingWasted + math.max(0, event.heal - event.healed)
  local counted = false
  for cause, key in pairs(causeKeys) do
    if event.causes and event.causes[cause] then
      t[key], counted = t[key] + 1, true
    end
  end
  if not counted then
    t.breakOther = t.breakOther + 1
  end
end
function T.add(g, key, amount)
  local t = T.get(g)
  t[key] = (t[key] or 0) + (amount or 1)
end
-- Every fixed step: demon lifetime and the part of it under control.
function T.tick(g, dt)
  local t = T.get(g)
  for _, e in ipairs(g.enemies) do
    if e.hp > 0 and not e.dummy and (e.spawnAge or 1) >= 0.6 then
      t.enemyTime = t.enemyTime + dt
      local record = bodyRecord(g, e)
      if e.awake then
        T.aware(g, e)
        t.awareTime = t.awareTime + dt
      end
      if record.firstHitAt then
        t.engagedTime = t.engagedTime + dt
      end
      if (e.stun or 0) > 0 or e.ai == 'hurt' then
        t.controlTime = t.controlTime + dt
        local conditions = e.conditions or NONE
        if e.knockedDown then
          t.knockdownTime = t.knockdownTime + dt
        elseif (conditions.exposed or 0) > 0 then
          t.exposedTime = t.exposedTime + dt
        elseif (conditions.staggered or 0) > 0 then
          t.staggerTime = t.staggerTime + dt
        else
          t.flinchTime = t.flinchTime + dt
        end
      end
    end
  end
  -- Records belong to bodies still in play: a kill releases its own
  -- (T.kill); a body removed alive (a cleared world) is released here.
  local records, alive = g.telemetryBodies, 0
  for _, e in ipairs(g.enemies) do
    alive = alive + (records and records[e.id] and 1 or 0)
  end
  local count = 0
  for _ in pairs(records or {}) do
    count = count + 1
  end
  if count > alive then
    for id in pairs(records) do
      local present = false
      for _, e in ipairs(g.enemies) do
        present = present or (e.id == id and e.hp > 0)
      end
      if not present then
        records[id] = nil
      end
    end
  end
end
-- The outcome of one blow on one body (Rules.react result).
function T.react(g, result, e)
  if type(result) ~= 'table' or (e and e.hp <= 0) then
    return
  end
  local t = T.get(g)
  if result.staggered then
    if result.heavy then
      t.heavyStaggers = t.heavyStaggers + 1
    else
      t.lightStaggers = t.lightStaggers + 1
    end
  end
  if result.counter then
    t.counters = t.counters + 1
  end
  if result.stopped or (result.counter and result.staggered) then
    t.knockdowns = t.knockdowns + 1
  end
  if result.tripped then
    t.trips = t.trips + 1
  end
  if result.wounded then
    t.wounds = t.wounds + 1
  end
end
-- Once per body: a second report of the same death (another listener, a
-- new damage source) changes no counter.
function T.kill(g, e)
  if e.killCounted then
    return
  end
  e.killCounted = true
  local t = T.get(g)
  t.kills = t.kills + 1
  local record = bodyRecord(g, e)
  if record.awareAt then
    t.awareKillSum = t.awareKillSum + math.max(0, g.elapsed - record.awareAt)
    t.awareKillCount = t.awareKillCount + 1
  end
  if record.firstHitAt then
    t.firstHitKillSum = t.firstHitKillSum + math.max(0, g.elapsed - record.firstHitAt)
    t.firstHitKillCount = t.firstHitKillCount + 1
  end
  if e.bornAt and g.elapsed then
    t.ttkSum = t.ttkSum + math.max(0, g.elapsed - e.bornAt)
    t.ttkCount = t.ttkCount + 1
  end
  -- The kill was the record's last use (the break-kill causes travel with the
  -- event): release it, keeping the sums above.
  g.telemetryBodies[e.id] = nil
end
-- The share of demon lifetime under control in a record of counters.
local function uptime(t)
  return t.enemyTime > 0 and t.controlTime / t.enemyTime or 0
end
function T.uptime(g)
  return uptime(T.get(g))
end
-- The counters gathered since a copy taken earlier (T.copy): one encounter.
function T.copy(g)
  local out = {}
  for key, value in pairs(T.get(g)) do
    out[key] = value
  end
  return out
end
function T.since(g, earlier)
  local out = {}
  for key, value in pairs(T.get(g)) do
    out[key] = value - ((earlier and earlier[key]) or 0)
  end
  return out
end
-- The report lines of a record of counters (default: the session's).
function T.lines(g, t)
  t = t or T.get(g)
  return {
    string.format(
      'Control uptime %.1f %% of demon lifetime; time to kill %.2f s (mean of %d)',
      percent * uptime(t),
      t.ttkCount > 0 and t.ttkSum / t.ttkCount or 0,
      t.ttkCount
    ),
    string.format(
      'Staggers %d light / %d heavy; counters %d; knockdowns %d; trips %d; wounds %d',
      t.lightStaggers,
      t.heavyStaggers,
      t.counters,
      t.knockdowns,
      t.trips,
      t.wounds
    ),
    string.format(
      'Break kills %d (%.0f %% of kills, healed %.1f); perfect dodges %d; hits taken %d (%.1f damage)',
      t.breakKills,
      percent * t.breakKills / math.max(1, t.kills),
      t.healed,
      t.perfectDodges,
      t.hitsTaken,
      t.damageTaken
    ),
    string.format(
      'Healing potential %.1f / actual %.1f / wasted %.1f HP',
      t.healingPotential,
      t.healed,
      t.healingWasted
    ),
    string.format(
      'Control seconds: down %.3f / exposed %.3f / stagger %.3f / flinch or micro %.3f',
      t.knockdownTime,
      t.exposedTime,
      t.staggerTime,
      t.flinchTime
    ),
    string.format(
      'Observed aware time %.2f s; after-first-hit time %.2f s; kill from awareness %.2f s (%d), first hit %.2f s (%d)',
      t.awareTime,
      t.engagedTime,
      t.awareKillSum / math.max(1, t.awareKillCount),
      t.awareKillCount,
      t.firstHitKillSum / math.max(1, t.firstHitKillCount),
      t.firstHitKillCount
    ),
    string.format(
      'Break causes (may overlap): guard %d / wound %d / down %d / micro %d / trip %d / other %d',
      t.breakGuard,
      t.breakWound,
      t.breakKnockdown,
      t.breakMicro,
      t.breakTrip,
      t.breakOther
    ),
  }
end
return T
