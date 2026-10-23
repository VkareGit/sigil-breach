-- Session clocks: captions, combo, the zone banner, the countdowns of the
-- knight's weapons and screen feedback, and both hit-stops (impactSlow: the
-- demons wait; worldStop: missiles and ground wait too).
local Presentation = require('src.session.presentation')
local Arena = require('src.world.arena')
local Timers = require('src.core.timers')
local K = require('src.content.tuning').clocks
local Clocks = { name = 'clocks' }
local plain = { 'comboTimer', 'zoneTimer', 'cooldown', 'impactSlow', 'worldStop' }
local plainView = { 'feedbackTimer', 'muzzle' }
local after = { 'staggerFlash', 'hitmarker', 'shake', 'killPunch', 'messageTimer', 'perfectDodge' }
function Clocks.run(g, dt)
  Timers.tick(g, plain, dt)
  Timers.tick(g.view, plainView, dt)
  local zone = Arena.zone(g.world, g.player.x, g.player.z)
  if zone ~= g.zone then
    g.zone, g.zoneTimer = zone, K.zoneBanner
    Presentation.cue(g, 'bell', K.zoneBell)
  end
  g.view.hurt = Timers.down(g.view.hurt, dt * K.hurtFade)
  g.view.surge = Timers.down(g.view.surge, dt * K.surgeFade)
  Timers.tick(g.view, after, dt)
end
return Clocks
