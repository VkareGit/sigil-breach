-- Resolve BEFORE health/death events. Same entity, target and effects: no
-- spawn, death reward or invulnerability at a refill.
local A = require('src.content.enemies')
local Signal = require('src.session.signal')
local Encounter = {}
function Encounter.advance(g, e)
  local def = A.of(e)
  if not (def and def.phases) then
    return false
  end
  local changed = false
  while true do
    local index = e.phaseIndex or 1
    local nextPhase = def.phases[index + 1]
    if not nextPhase or e.hp > e.maxHp * nextPhase.at then
      break
    end
    -- A hit may cross several thresholds. At a new health stock excess
    -- damage is discarded, never carried to the next life.
    e.phaseBaseHp = e.phaseBaseHp or e.maxHp
    if nextPhase.refill then
      e.maxHp = math.max(1, math.floor(e.phaseBaseHp * nextPhase.refill + 0.5))
      e.hp = e.maxHp
    end
    e.phaseIndex = index + 1
    if e.pendingHazard then
      e.pendingHazard.cancelled = true
      e.pendingHazard = nil
    end
    -- Cancel unreleased work / body attacks. Released projectiles and floor
    -- hazards stay with the same owner; existing flight settles physically.
    e.ai, e.phase, e.windup = 'recover', 0, 0
    e.recover = nextPhase.recovery
    e.attack = math.max(e.attack or 0, nextPhase.recovery)
    e.rushVX, e.rushVZ = nil, nil
    e.walkVX, e.walkVZ, e.walkSpeed = nil, nil, 0
    e.evadeTime = nil
    -- Guard damage, conditions, cooldowns and reactions are not cleansed.
    local event = { enemy = e, from = index, phase = index + 1, id = nextPhase.id }
    Signal(g, 'EnemyPhaseChanged', event)
    changed = true
    if nextPhase.refill then
      break
    end
  end
  return changed
end
return Encounter
