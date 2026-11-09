-- Session clocks: captions, combo, the zone banner, the countdowns of the
-- knight's weapons and screen feedback, and both hit-stops (impactSlow: the
-- demons wait; worldStop: missiles and ground wait too).
local Signal = require('src.session.signal')
local Arena = require('src.world.arena')
local Timers = require('src.core.timers')
local K = require('src.content.tuning').clocks
local Roles = require('src.core.roles')
local Pools = require('src.session.world')
local Bodies = require('src.combat.bodies')
local Stats = require('src.session.stats')
local Context = require('src.session.context')
local Clocks = { name = 'clocks' }
local plain = { 'zoneTimer', 'impactSlow', 'worldStop' }
-- Each actor's own weapon cadence (plan v11 E3).
local actor = { 'cooldown', 'chainLeft' }
local plainView =
  { 'feedbackTimer', 'refusalTimer', 'killPop', 'soulsGainTimer', 'medalTimer', 'muzzle' }
local after = { 'staggerFlash', 'hitmarker', 'shake', 'killPunch', 'messageTimer', 'perfectDodge' }
-- The damage trail of a view (feedback/listeners.lua): its sum holds trailHold s after the last
-- blow, then the pale share falls to what the body has left. Time passes whether or not the
-- body is in the sights.
local function trail(view, dt)
  local t = view.damageTrail
  if not t then
    return
  end
  t.hold = t.hold - dt
  if t.hold <= 0 then
    t.sum = 0
    t.shown = math.max(t.hp, t.shown - t.maxHp * K.trailFall * dt)
  end
end
-- The lessons of a view (feedback/lessons.lua): one stands for lessonTime s, and the next
-- waiting starts only while nothing hunts the knight, never in the heat of a fight.
local function lesson(view, dt, calm)
  local lessons = view.lessons
  if not lessons then
    return
  end
  lessons.left = math.max(0, (lessons.left or 0) - dt)
  if lessons.left <= 0 then
    lessons.showing = nil
  end
  if not lessons.showing and calm and lessons.queue[1] then
    lessons.showing, lessons.left = table.remove(lessons.queue, 1), K.lessonTime
  end
end
local function tickView(view, dt, calm)
  Timers.tick(view, plainView, dt)
  view.hurt = Timers.down(view.hurt, dt * K.hurtFade)
  view.surge = Timers.down(view.surge, dt * K.surgeFade)
  Timers.tick(view, after, dt)
  trail(view, dt)
  lesson(view, dt, calm)
end
local function calm(g)
  return Bodies.each(g, function(b)
    return b.awake and b.hp > 0
  end) == nil
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
    Signal(g, 'ZoneEntered', { zone = zone })
  end
  local quiet = calm(g)
  tickView(g.view, dt, quiet)
  for _, view in pairs(Context.watched(g)) do
    tickView(view, dt, quiet)
  end
end
return Clocks
