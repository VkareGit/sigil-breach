local Context = require('src.session.context')
-- The knight's movement as the painted world shows it: flecks of the
-- fresco's pigments (content/movement_marks.lua) where a dodge leaves the
-- stone, along a dodge and a slide, round a jump and a landing, behind a
-- powder charge's fuse; the dodge's gilded wash and the shade a perfect dodge
-- leaves. Answers the movement hooks (player/feel.lua, session/game.lua) and
-- the PerfectDodge listener; pure presentation (no simulation state written).
local Presentation = require('src.session.presentation')
local Ground = require('src.physics.ground')
local Ballistics = require('src.combat.ballistics')
local Transients = require('src.feedback.transients')
local Data = require('src.content.movement_marks')
local Pools = require('src.session.world')
local Marks = {}
local random = Transients.random
local sin, cos, sqrt = math.sin, math.cos, math.sqrt

-- An emitter: a place (x, y of the ground or the eye, z), the move's
-- direction (dx, dz; unit), its own velocity (vx, vy, vz) and the direction
-- its sprays are placed along (px, pz; the move's unless given).
local function emitter(x, y, z, dx, dz, vx, vy, vz, px, pz)
  return {
    x = x,
    y = y,
    z = z,
    dx = dx,
    dz = dz,
    vx = vx or 0,
    vy = vy or 0,
    vz = vz or 0,
    px = px or dx,
    pz = pz or dz,
  }
end

-- One spray from an emitter; scale multiplies its count.
function Marks.spray(g, spray, e, scale)
  local count = math.floor(spray.count * (scale or 1) + 0.5)
  local color = Data.pigments[spray.pigment]
  -- Across the placement: its right hand.
  local rx, rz = e.pz, -e.px
  for i = 1, count do
    local side = (random(g) * 2 - 1) * spray.side
    local x = e.x + e.px * spray.ahead + rx * side
    local z = e.z + e.pz * spray.ahead + rz * side
    local y = e.y + spray.height + random(g) * spray.rise
    local vx, vy, vz
    if spray.ring then
      local angle = (i - 1 + random(g) * 0.6) / count * math.pi * 2
      local speed = (0.5 + 0.5 * random(g)) * spray.scatter
      vx, vz = sin(angle) * speed, cos(angle) * speed
      vy = spray.up * (0.6 + 0.4 * random(g))
    else
      local s = spray.scatter
      vx = e.dx * spray.along + (random(g) * 2 - 1) * s
      vz = e.dz * spray.along + (random(g) * 2 - 1) * s
      vy = spray.up * (0.6 + 0.4 * random(g)) + (random(g) * 2 - 1) * s * 0.3
    end
    Transients.add(
      g,
      x,
      y,
      z,
      vx + e.vx * spray.carry,
      vy + e.vy * spray.carry,
      vz + e.vz * spray.carry,
      spray.life * (1 + 0.5 * random(g)),
      color,
      spray.size * (0.75 + 0.5 * random(g))
    )
  end
end

-- Every spray of a move, each from the emitter its 'from' names (a spray
-- whose emitter is absent is skipped); then the move's flash.
function Marks.move(g, name, emitters, scale)
  local move = Data.moves[name]
  for _, spray in ipairs(move.sprays) do
    local e = emitters[spray.from]
    if e then
      Marks.spray(g, spray, e, scale)
    end
  end
  if move.flash > 0 then
    g.view.surge = math.max(g.view.surge, move.flash)
  end
end

-- The knight's emitters for a move towards (dx, dz) (his travel when not
-- given): his boots, the spot the dodge left, before his eyes.
local function knight(g, dx, dz)
  local p = Context.actor(g)
  if not dx then
    local v = sqrt(p.vx * p.vx + p.vz * p.vz)
    if v > 0.1 then
      dx, dz = p.vx / v, p.vz / v
    else
      dx, dz = sin(p.yaw), cos(p.yaw)
    end
  end
  local ground = Ground.of(g.world, p)
  local ex, ey, ez = Ballistics.origin(g, p)
  local vy = p.jumpV or 0
  return {
    feet = emitter(p.x, ground + p.jump, p.z, dx, dz, p.vx, vy, p.vz),
    origin = emitter(p.dodgeFromX or p.x, ground, p.dodgeFromZ or p.z, dx, dz),
    view = emitter(ex, ey, ez, dx, dz, p.vx, vy, p.vz, sin(p.yaw), cos(p.yaw)),
  }
end

-- The dodge begins (session/game.lua: dash), towards (dx, dz).
function Marks.dash(g, dx, dz)
  Marks.move(g, 'dash', knight(g, dx, dz))
end
-- A slide begins (player/feel.lua).
function Marks.slide(g)
  local p = Context.actor(g)
  Marks.move(g, 'slide', knight(g, p.slideX, p.slideZ))
end
-- The knight leaves the ground.
function Marks.takeoff(g)
  Marks.move(g, 'takeoff', knight(g))
end
-- He lands falling at speed m/s: the harder, the more dust.
function Marks.landing(g, speed)
  local fall = Data.moves.landing.fall
  local scale =
    math.min(1, (math.abs(speed or 0) - fall.from) / math.max(1e-6, fall.full - fall.from))
  if scale > 0 then
    Marks.move(g, 'landing', knight(g), scale)
  end
end
-- The shade a perfect dodge leaves where the knight stood.
function Marks.afterimage(g)
  Marks.move(g, 'afterimage', knight(g))
end

-- A trail sprays every so often while active: emit() sprays once.
local function trail(g, name, dt, active, emit)
  local clocks = g.view.markClocks
  if not active then
    clocks[name] = 0
    return
  end
  local every = Data.moves[name].every
  clocks[name] = (clocks[name] or 0) + dt
  while clocks[name] >= every do
    clocks[name] = clocks[name] - every
    emit()
  end
end
-- Each step: the dodge and the slide under way, every charge's fuse.
function Marks.update(g, dt)
  g.view.markClocks = g.view.markClocks or {}
  local p = Context.actor(g)
  trail(g, 'dashTrail', dt, p.dashTimer > 0, function()
    Marks.move(g, 'dashTrail', knight(g, p.dashX, p.dashZ))
  end)
  trail(g, 'slideTrail', dt, p.slideTimer > 0 and p.jump <= 0, function()
    Marks.move(g, 'slideTrail', knight(g, p.slideX, p.slideZ))
  end)
  -- Every actor has movement trails, but fuse embers are one shared world
  -- emission. Additional observed views must not advance this clock again.
  if Context.isControlled(g, p) then
    local charges = Pools.of(g, 'charges')
    trail(g, 'charge', dt, #charges > 0, function()
      for _, c in ipairs(charges) do
        Marks.move(g, 'charge', { charge = emitter(c.x, c.y, c.z, 0, 1, c.vx, c.vy, c.vz) })
      end
    end)
  end
end

Presentation.hook('motion.dash', Marks.dash)
Presentation.hook('motion.slide', Marks.slide)
Presentation.hook('motion.marks', Marks.update)
return Marks
