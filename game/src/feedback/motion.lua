-- The knight's movement as felt: weight, weapon motion and movement impacts
-- answer the hooks player/feel.lua calls at fixed points of its step
-- (session/presentation.lua). Pure presentation; the movement is simulation.
local Presentation = require('src.session.presentation')
local WeaponMotion = require('src.feedback.weapon_motion')
local MovementImpact = require('src.feedback.movement_impact')
local Weight = require('src.feedback.weight')
local Marks = require('src.feedback.movement_marks')
local Motion = {}
function Motion.init(g)
  g.view.abilityCast, g.view.abilityVoice = nil, nil
  WeaponMotion.init(g)
  MovementImpact.init(g)
  Weight.init(g)
end
function Motion.clear(g)
  g.view.abilityCast, g.view.abilityVoice = nil, nil
  Weight.clearMotion(g)
  WeaponMotion.init(g, true)
end
-- A landing: the impact's measurement (handed to the weapon motion), its
-- weight and the dust it raises.
function Motion.landing(g, impact)
  local measured = MovementImpact.landing(g, impact or 0)
  Weight.landing(g, impact)
  Marks.landing(g, impact)
  return measured
end
-- A jump: the weapon dips, dust rings the boots.
function Motion.takeoff(g, speed)
  local measured = MovementImpact.takeoff(g, speed)
  Marks.takeoff(g)
  return measured
end
Presentation.hook('motion.init', Motion.init)
Presentation.hook('motion.clear', Motion.clear)
Presentation.hook('motion.weight', Weight.update)
Presentation.hook('motion.wall', MovementImpact.wall)
Presentation.hook('motion.takeoff', Motion.takeoff)
Presentation.hook('motion.landing', Motion.landing)
Presentation.hook('motion.weapon', WeaponMotion.update)
return Motion
