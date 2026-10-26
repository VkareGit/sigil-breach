-- Encounter lifetimes are explicit. A new wave clears its actors and attacks,
-- but lets the last ejected shells finish. A full reset also clears those
-- visual remnants and cached combat reports. Neither operation touches the
-- player, run wallet/checkpoint, world geometry or persistent score.
local Pools = require('src.session.world')
local Roles = require('src.core.roles')
local Encounter = {}

-- The circle's guardian (plan v11 E2): one record of the session's
-- encounter (g.encounter), shared by every mode and changed only here.
-- Modes say when it arrives and falls; screens, music and the world's exit
-- read the world view (run/queries.lua), never the record.
function Encounter.new()
  return { guardianSpawned = false, guardianDead = false }
end
local function record(g)
  local e = g.encounter
  if not e then
    e = Encounter.new()
    g.encounter = e
  end
  return e
end
function Encounter.guardianSpawned(g)
  return g.encounter ~= nil and g.encounter.guardianSpawned == true
end
function Encounter.guardianDead(g)
  return g.encounter ~= nil and g.encounter.guardianDead == true
end
-- The guardian is on the field (and not yet fallen).
function Encounter.guardianFighting(g)
  return Encounter.guardianSpawned(g) and not Encounter.guardianDead(g)
end
function Encounter.guardianArrived(g)
  record(g).guardianSpawned = true
end
function Encounter.guardianFell(g)
  record(g).guardianDead = true
end
-- Both at once: a restored checkpoint, the proving ground's census.
function Encounter.setGuardian(g, spawned, dead)
  local e = record(g)
  e.guardianSpawned, e.guardianDead = spawned == true, dead == true
end

function Encounter.clearThreats(g)
  Pools.clear(g, 'projectiles')
  Pools.clear(g, 'hazards')
  Pools.clear(g, 'charges')
end

function Encounter.clearStage(g)
  require('src.combat.observation').invalidate(g)
  require('src.player.intent').clear(g)
  Encounter.clearThreats(g)
  Pools.clear(g, 'enemies')
  Pools.clear(g, 'remains')
  Pools.clear(g, 'pickups')
  g.view.particles = {}
  g.view.traces = {}
  g.view.surfaceMarks = {}
  g.view.effects = {}
  g.view.decals = {}
end

function Encounter.clearWorld(g)
  Encounter.clearStage(g)
  g.view.shells = {}
  g.explosionReport = nil
  g._shotBodies = nil
  Encounter.setGuardian(g, false, false)
  g.threat = 0
  Roles.controlled(g).effectState = nil
end

return Encounter
