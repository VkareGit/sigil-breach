-- Session clocks: captions, combo, the zone banner, the countdowns of the
-- knight's weapons and screen feedback, and both hit-stops (impactSlow: the
-- demons wait; worldStop: missiles and ground wait too).
local Presentation = require('src.session.presentation')
local Arena = require('src.world.arena')
local Timers = require('src.core.timers')
local K = require('src.content.tuning').clocks
local Roles = require('src.core.roles')
local Pools = require('src.session.world')
local Stats = require('src.session.stats')
local Context = require('src.session.context')
local Clocks = { name = 'clocks' }
local plain = { 'zoneTimer', 'impactSlow', 'worldStop' }
-- Each actor's own weapon cadence (plan v11 E3).
local actor = { 'cooldown', 'chainLeft' }
local plainView =
  { 'feedbackTimer', 'refusalTimer', 'killPop', 'soulsGainTimer', 'medalTimer', 'muzzle' }
local after = { 'staggerFlash', 'hitmarker', 'shake', 'killPunch', 'messageTimer', 'perfectDodge' }
local function tickView(view, dt)
  Timers.tick(view, plainView, dt)
  view.hurt = Timers.down(view.hurt, dt * K.hurtFade)
  view.surge = Timers.down(view.surge, dt * K.surgeFade)
  Timers.tick(view, after, dt)
end
function Clocks.run(g, dt)
  Timers.tick(g, plain, dt)
  -- Each actor's combo window (session/stats.lua, plan v11 E3d).
  Stats.tick(g, dt)
  -- The controlled knight first, then every other one (systems/knight.lua).
  local controlled = Roles.controlled(g)
  Timers.tick(controlled, actor, dt)
  for _, knight in ipairs(Pools.of(g, 'knights')) do
    if knight ~= controlled then
      Timers.tick(knight, actor, dt)
    end
  end
  local zone = Arena.zone(g.world, Roles.controlled(g).x, Roles.controlled(g).z)
  if zone ~= g.zone then
    g.zone, g.zoneTimer = zone, K.zoneBanner
    Presentation.cue(g, 'bell', K.zoneBell)
  end
  tickView(g.view, dt)
  for _, view in pairs(Context.watched(g)) do
    tickView(view, dt)
  end
end
return Clocks
