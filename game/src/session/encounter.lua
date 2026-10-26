-- Encounter lifetimes are explicit. A new wave clears its actors and attacks,
-- but lets the last ejected shells finish. A full reset also clears those
-- visual remnants and cached combat reports. Neither operation touches the
-- player, run wallet/checkpoint, world geometry or persistent score.
local Pools = require('src.session.world')
local Encounter = {}

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
  g.bossSpawned = false
  g.bossDead = false
  g.threat = 0
  g.player.effectState = nil
end

return Encounter
