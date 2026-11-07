-- An optional patient claimant lets existing commitments finish before newcomers enter.
-- Merely checking the queue never chooses a target, consumes RNG or reserves a blow.
local Pools = require('src.session.world')
local Bodies = require('src.combat.bodies')
local Rules = require('src.combat.rules')
local Archetypes = require('src.content.enemies')
local AttackSelection = require('src.enemies.attack_selection')
local Slots = {}
function Slots.clear(e)
  e.slotWaitAt, e.slotWaitTarget = nil, nil
end
function Slots.request(g, e)
  if Archetypes.of(e).move.attackWait then
    if e.slotWaitTarget ~= e.target then
      Slots.clear(e)
    end
    e.slotWaitAt, e.slotWaitTarget = e.slotWaitAt or g.elapsed, e.target
  end
end
local function eligible(g, e)
  local patience = Archetypes.of(e).move.attackWait
  if not patience or not e.slotWaitAt or g.elapsed - e.slotWaitAt < patience then
    return false
  end
  if
    e.slotWaitTarget ~= e.target
    or e.hp <= 0
    or not e.awake
    or not e.visible
    or e.dummy
    or e.ai ~= 'move'
    or (e.recover or 0) > 0
    or (e.spent or 0) > 0
    or e.attack > 0
    or e.stun > 0
    or e.hitPause > 0
    or (e.evadeTime or 0) > 0
    or e.spawnAge < Archetypes.defaults.spawnPause
  then
    return false
  end
  local victim = Pools.get(g, e.target)
  if
    not victim
    or victim.hp <= 0
    or not Bodies.hostile(g, e, victim)
    or not Rules.sees(g, e, victim)
  then
    return false
  end
  local distance = math.sqrt((victim.x - e.x) ^ 2 + (victim.z - e.z) ^ 2)
  return AttackSelection.choose(e, distance, g.elapsed, nil, g) ~= nil
end
function Slots.yields(g, e)
  -- The connecting beat already owns a slot. Fairness cannot cut a series in half.
  if e.chain then
    return false
  end
  local first
  Bodies.eachCreature(g, function(other)
    if
      other.target == e.target
      and eligible(g, other)
      and (
        not first
        or other.slotWaitAt < first.slotWaitAt
        or (other.slotWaitAt == first.slotWaitAt and other.id < first.id)
      )
    then
      first = other
    end
  end)
  return first ~= nil and first ~= e
end
return Slots
