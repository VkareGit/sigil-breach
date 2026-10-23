-- The session field catalogue (0.24 E11): every field a session (g) may
-- carry, grouped by the module that owns it. Reading is free; writing
-- belongs to the owner (a mode's reset may set its owners' fields back to
-- their start values: run/descent.lua, run/test_field.lua). A new field is
-- declared here first; the golden suite fails on an undeclared one.
-- Simulation fields are part of a snapshot and of the golden digest;
-- presentation fields never feed back into the simulation.
local Fields = {}
Fields.groups = {}
local index = {}
function Fields.owner(name)
  return index[name]
end
-- Presentation fields live in g.view (0.24 F2), never on the session.
Fields.viewGroups = {}
local viewIndex = {}
function Fields.viewOwner(name)
  return viewIndex[name]
end
function Fields.declareView(owner, names)
  Fields.viewGroups[#Fields.viewGroups + 1] = { owner = owner, names = names }
  for _, name in ipairs(names) do
    assert(not viewIndex[name], 'view field declared twice: ' .. name)
    viewIndex[name] = owner
  end
end
function Fields.declare(owner, names)
  Fields.groups[#Fields.groups + 1] = { owner = owner, names = names }
  for _, name in ipairs(names) do
    assert(not index[name], 'session field declared twice: ' .. name)
    index[name] = owner
  end
end
local declare = Fields.declare
local declareView = Fields.declareView

-- SIMULATION ----------------------------------------------------------------
-- The session itself (session/state.lua): the world, the pools' arrays, the
-- knight, its machinery and its counters.
declare('session/state.lua', {
  'world', -- the arena: map cells, seals, lamps, portal, spawn
  'view', -- presentation state (Fields.view below)
  'enemies', -- demons (pool 'enemies')
  'bullets', -- missiles in flight (pool 'projectiles')
  'hazards', -- marked ground strikes and pools (pool 'hazards')
  'pickups', -- supplies and souls on the floor (pool 'pickups')
  'charges', -- thrown powder charges (pool 'charges')
  'player', -- the knight (single 'knight')
  'ecs', -- the ECS world over these arrays (machinery)
  'bus', -- the event bus with its listeners (machinery)
  'rng', -- the simulation and presentation random streams
  'events', -- the recent-event log the HUD reads
  'state', -- the screen: menu, playing, paused, shop, dead, won... (app/screens.lua)
  'time', -- seconds since the session began (any screen)
  'elapsed', -- seconds of play (session/simulation.lua)
  'step', -- presentation step counter
  'nextId', -- the last demon id given (Game:spawn)
  'testing', -- set by tests and QA: no files written
  'map', -- the map overlay is open (app/commands.lua)
  'help', -- the help overlay is open (app/commands.lua)
  'flowTimer', -- reserved pathing clock
})
-- The frame record of a step (session/simulation.lua): previous positions.
declare('session/simulation.lua', { 'frame' })
-- The knight's commands and weapons (session/game.lua, combat/*).
declare('combat/combat.lua', {
  'weapon', -- the weapon in hand (1 shotgun, 2 revolver)
  'cooldown', -- seconds until the weapon may fire
  'shots',
  'hits',
  'kills',
  'shotSerial',
  '_shotBodies', -- per-shot scratch (combat/ballistics.lua)
})
declare('combat/reload.lua', {
  'reload',
  'reloadWeapon',
  'reloadStage',
  'reloadDuration',
  'reloadOffset',
})
declare('combat/explosives.lua', { 'explosionReport' })
declare('combat/projectiles.lua', { '_projectileEvents' })
declare('combat/rules/contact.lua', { 'collisions', 'slams', 'lastSlam' })
declare('combat/telemetry.lua', { 'telemetry', 'telemetryBodies' })
declare('player/feel.lua', {
  -- the world's hit-stop (s): demons wait it out (set by session/listeners
  -- and combat/dodge, counted down by systems/clocks)
  'impactSlow',
})
declare('player/intent.lua', { 'fireBuffer', 'fireCommand' })
declare(
  'combat/observation.lua',
  { '_observationSession', '_observationGeneration', '_observationSequence' }
)
-- Demons' shared state (enemies/*).
declare('enemies/ai.lua', {
  'threat', -- summed threat of awake demons near the knight
  'nextAttack', -- when the next demon may commit an attack
  'cancelledAttacks',
  'evadeCount',
  'retargets',
})
declare('enemies/actions.lua', { 'attackStarts', 'leapStarts' })
-- Consequences of damage and kills (session/listeners.lua, damage_outcomes).
declare('session/listeners.lua', {
  'score',
  'combo',
  'comboTimer',
  'damageTaken',
  'intensity', -- the pacing director's faded damage (run/spawner.lua reads it)
  'bossDead',
  -- the guard-break hit-stop (s): missiles, ground and charges wait
  -- (session/capabilities.lua: held; counted down by systems/clocks)
  'worldStop',
})
declare('session/damage_outcomes.lua', { 'playerDamageReport' })
-- Modes.
declare('run/descent.lua', { 'run', 'shopMessage', 'saveWarning' })
declare('run/modes.lua', { 'mode' }) -- the mode a session names (new modes)
declare('run/spawner.lua', { 'bossSpawned' })
declare('run/test_field.lua', { 'testField', 'availableSave', 'tier' })
declare('session/interactions.lua', { 'seals', 'secretFound', 'rank', 'bestScore' })
declare('systems/clocks.lua', { 'zone', 'zoneTimer' })

-- PRESENTATION --------------------------------------------------------------
declareView('session/game.lua', { 'message', 'messageTimer' })
declareView('feedback/damage_numbers.lua', { 'damageNumbers', 'numberSerial' })
declareView('app/commands.lua', { 'motion', 'fov', 'confirmReturn', 'presentationPrevious' })
declareView('app/input.lua', { 'swayX', 'swayY' })
declareView('feedback/listeners.lua', {
  'feedback',
  'feedbackTimer',
  'hurt',
  'surge',
  'hitmarker',
  'shake',
  'muzzle',
  'damageDir',
  'killPunch',
  'breakKill',
  'perfectDodge',
  'lastDamage',
  'lastKill',
  'precisionHit',
})
declareView('feedback/shot_feedback.lua', {
  'armorHit',
  'flashColor',
  'hitWeight',
  'shotPower',
  'shotReport',
})
declareView('feedback/world_feedback.lua', { 'staggerFlash' })
declareView('feedback/weight.lua', {
  'breakConfirm',
  'heartTimer',
  'heartbeats',
  'hurtMarks',
  'kickBack',
  'kickBackV',
  'kickFlip',
  'rollPunch',
  'rollPunchV',
  'rollSide',
  'viewPunch',
  'viewPunchV',
  'weaponShotRoll',
  'weaponShotRollV',
  'aimKick', -- the shot's climb of the view (rad), back before the next pull
  'aimKickV',
  'aimKickRate',
})
declareView('feedback/effects.lua', { 'effects', 'effectPool', 'decals', 'decalPool' })
declareView('feedback/surface_marks.lua', { 'surfaceMarks', 'surfaceMarkPool' })
declareView('feedback/shot_trails.lua', { 'traces', 'tracePool' })
declareView('feedback/death_response.lua', { 'particles', 'corpses', 'shells' })
declareView('feedback/movement_impact.lua', {
  'lastLandingImpact',
  'lastMovementImpact',
  'lastWallImpact',
  'movementContact',
  'movementImpactSerial',
})
declareView('player/feel.lua (camera)', {
  'bank',
  'bobWeight',
  'fovKick',
  'land',
  'landV',
  'moving',
  'recoil',
  'recoilV',
  'stepSound',
  'shotAge', -- seconds since the last trigger pull (hands, flash, portrait)
  'swapAge', -- seconds since the weapon was drawn (hands)
})
declareView('player/movement_gait.lua', { 'gaitPhase', 'gaitSteps' })
declareView('feedback/weapon_motion.lua', {
  'weaponAimVX',
  'weaponAimVY',
  'weaponAimX',
  'weaponAimY',
  'weaponAirVY',
  'weaponAirY',
  'weaponCarry',
  'weaponClock',
  'weaponDip',
  'weaponDipV',
  'weaponImpactRoll',
  'weaponImpactVRoll',
  'weaponImpactVX',
  'weaponImpactVY',
  'weaponImpactX',
  'weaponImpactY',
  'weaponLagVX',
  'weaponLagVY',
  'weaponLagX',
  'weaponLagY',
  'weaponLastPitch',
  'weaponLastYaw',
  'weaponLean',
  'weaponLower',
  'weaponStepRoll',
  'weaponStepVRoll',
  'weaponStepVY',
  'weaponStepY',
  'weaponStride',
})
return Fields
