-- Every event kind of the simulation, declared once (an unknown kind is an
-- error at emission). 'sim' listeners may change the simulation in a
-- declared order; 'present' listeners run after the step and only show it.
-- Payload fields are named in the description.
local Catalog = {
  { 'ShotFired', 'the knight pulled a trigger {weapon, pellets}' },
  { 'VolleyResolved', 'a shot was applied to every body it reached {report, results}' },
  { 'BodyHit', 'a demon lost health {enemy, health, source}' },
  {
    'BlowResolved',
    'the rules resolved a blow on a body {target, result, impact, point, contact, number}',
  },
  { 'NearMiss', 'a projectile passed close to the knight {bullet, distance}' },
  { 'ProjectileBurst', 'a projectile ended (wall, knight, time) {bullet}' },
  { 'ChargeThrown', 'the knight threw a powder charge {}' },
  { 'AbilityCast', 'the knight cast an ability {ability, slot}' },
  { 'ChargeExploded', 'a powder charge went off {charge}' },
  { 'ReloadStage', 'a reload reached a stage {stage, mechanism, spent}' },
  { 'PlayerStaggered', 'the knight lost his balance {time}' },
  { 'Alerted', 'a demon noticed the knight {enemy}' },
  { 'ChargeBlocked', 'a rush ran into stone {enemy}' },
  { 'EnemyKilled', 'a demon died {enemy, source, offBalance, causes}' },
  { 'PlayerHit', 'the knight was hit {packet, events, x, z}' },
  { 'PerfectDodge', 'a blow landed during a dodge {packet, source}' },
  { 'WallSlam', 'a body met stone faster than the slam speed {body, speed, lost, player}' },
  { 'BodiesCollided', 'a thrown body struck another {body, other}' },
  { 'AttackTelegraphed', 'a demon committed to an attack {enemy, attack}' },
  { 'AttackReleased', 'a telegraph ran out and the attack went off {enemy, attack}' },
  { 'AttackCancelled', 'a committed attack was cancelled {enemy}' },
  { 'Landed', 'a leaping or falling body reached the floor {enemy, heavy}' },
  { 'Evaded', 'a demon sidestepped the aim {enemy}' },
  { 'PortalOpened', 'a summoning portal began to glow {gate}' },
  { 'EnemyArrived', 'a demon climbed out of a portal {enemy}' },
  {
    'WaveCleared',
    'a wave of the expedition or a proving-ground trial ended {wave, final, trial}',
  },
  { 'PickupTaken', 'the knight took a supply {pickup, text}' },
  { 'ModeStarted', 'the session left the menu into its mode {mode}' },
}
local Events = require('src.core.events')
local M = {}
M.kinds = Catalog
-- A bus with every kind of the catalogue declared.
function M.newBus()
  local bus = Events:new()
  for _, entry in ipairs(Catalog) do
    bus:define(entry[1], entry[2])
  end
  return bus
end
return M
