-- Finite contact volumes evaluated only during their authored active window.
local MathX = require('src.core.mathx')
local B = require('src.combat.ballistics')
local W = require('src.world.arena')
local Ground = require('src.physics.ground')
local CylinderCast = require('src.physics.cylinder_cast')
local Receipt = require('src.combat.contact_receipt')
local Anchor = require('src.enemies.contact_anchor')
local Bodies = require('src.combat.bodies')
local Characters = require('src.content.characters')
local Claw = require('src.content.combat_defaults').claw
local M = {}
local reachSamples = Claw.reach
local lerp = MathX.lerp
local function playerAt(previous, current, t, out, world)
  out = out or {}
  out.x, out.z = lerp(previous.x, current.x, t), lerp(previous.z, current.z, t)
  out.jump = lerp(previous.jump or 0, current.jump or 0, t)
  if world and world.elevations then
    local from = Ground.of(world, previous) + (previous.jump or 0)
    local to = Ground.of(world, current) + (current.jump or 0)
    local feet = lerp(from, to, t)
    if world.decks then
      -- The swept body stands on the surface under its feet (plan v10 V3).
      out.level = feet
    end
    out.jump = feet - Ground.of(world, out)
  end
  out.crouch = lerp(previous.crouch or 0, current.crouch or 0, t)
  return out
end
M.playerAt = playerAt
-- body (optional): the body whose volume is met (plan v10 V2; default the
-- knight's dimensions); previous/current: its swept points (x, z, jump,
-- crouch) at the start and end of the interval.
function M.contact(g, x1, z1, x2, z2, y, radius, previous, current, endY, body)
  local p = current or Bodies.controlled(g)
  previous = previous or p
  -- The hit volume of the knight met: radius, floor clearance and height.
  local knight = Characters.of(p).body
  local bodyRadius, feet, height = knight.radius, knight.feet, knight.height
  if body then
    bodyRadius, feet, height = Bodies.extent(g, body)
  end
  local dx, dz = x2 - x1, z2 - z1
  local dy = (endY or y) - y
  local rx, rz = dx - (p.x - previous.x), dz - (p.z - previous.z)
  local ex, ez = x1 - previous.x, z1 - previous.z
  local datum = Ground.height(g.world)
  local jump = Ground.of(g.world, previous) - datum + (previous.jump or 0)
  local jumpDelta = Ground.of(g.world, p) - datum + (p.jump or 0) - jump
  local lo = CylinderCast.sweep(
    ex,
    ez,
    rx,
    rz,
    jump + feet - y,
    jumpDelta - dy,
    jump + height - (previous.crouch or 0) - y,
    jumpDelta - ((p.crouch or 0) - (previous.crouch or 0)) - dy,
    bodyRadius,
    radius
  )
  if not lo then
    return false
  end
  local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
  if distance > 1e-7 then
    -- y is above the ground; the ray takes world height (physics/ground.lua).
    local wall, _, kind = B.world(
      g.world,
      x1,
      Ground.height(g.world) + y,
      z1,
      dx / distance,
      dy / distance,
      dz / distance,
      distance
    )
    if kind ~= 'range' and lo >= wall / distance - 1e-6 then
      return false
    end
  end
  local px, pz = lerp(previous.x, p.x, lo), lerp(previous.z, p.z, lo)
  if
    not W.visible(g.world, lerp(x1, x2, lo), lerp(z1, z2, lo), px, pz, nil, nil, p.level, p.level)
  then
    return false
  end
  local contact = Receipt.sphere(
    lerp(x1, x2, lo),
    datum + lerp(y, endY or y, lo),
    lerp(z1, z2, lo),
    radius,
    px,
    pz,
    datum + jump + jumpDelta * lo + feet,
    datum + jump + jumpDelta * lo + height - lerp(previous.crouch or 0, p.crouch or 0, lo),
    bodyRadius
  )
  contact.fraction = lo
  return true, lo, contact
end
-- The active window of a strike's contact: the attack's own, or the claw's.
function M.window(action)
  local active = action and action.active
  return active and active[1] or Claw.active[1], active and active[2] or Claw.active[2]
end
-- Where the attacking hand (muzzle) is at phase of the strike, for the body
-- standing at x, z: the contact point (height above the ground) and the
-- forward direction its reach samples extend along. Used by the contact test
-- below and by the hit diagnostics (render/effects.lua), never redrawn apart.
function M.reach(g, e, phase, x, z, action, activeStart, activeEnd)
  local ax, ay, az = Anchor.point(g, e, phase, x, z, action and action.contactAnchor or 'claw')
  if ax then
    return ax,
      ay + Ground.height(g.world, x, z, e.level) - Ground.height(g.world),
      az,
      e.lungeX,
      e.lungeZ
  end
  -- Unannotated extension art retains the generic physical swing. Existing
  -- creatures use their named painted contact, not this fallback arc.
  if not activeStart then
    activeStart, activeEnd = M.window(action)
  end
  local a = math.atan2(e.lungeX, e.lungeZ)
  local yaw = a - Claw.arc + 2 * Claw.arc * (phase - activeStart) / (activeEnd - activeStart)
  return x,
    Claw.height + Ground.height(g.world, x, z, e.level) - Ground.height(g.world),
    z,
    math.sin(yaw),
    math.cos(yaw)
end
-- The depths along the forward direction where the contact is sampled.
function M.depths(action)
  return action and action.contactReach or reachSamples
end
-- current (optional): the swept point of the body met now (default the
-- controlled knight); body (optional): whose volume it is (M.contact).
function M.claw(
  g,
  e,
  oldX,
  oldZ,
  previous,
  before,
  after,
  movementEnd,
  active,
  current,
  action,
  body
)
  current = current or Bodies.controlled(g)
  -- The authored active window comes from the attack's data (default claw).
  local activeStart = active and active[1] or Claw.active[1]
  local activeEnd = active and active[2] or Claw.active[2]
  local start, finish = math.max(before, activeStart), math.min(after, activeEnd)
  if finish <= start or after <= before then
    return false
  end
  local duration = after - before
  local movingDuration = math.max(1e-9, math.min(after, movementEnd or after) - before)
  previous = previous or Bodies.controlled(g)
  local function point(phase)
    local time = math.min(1, (phase - before) / movingDuration)
    local x, z = lerp(oldX, e.x, time), lerp(oldZ, e.z, time)
    return M.reach(g, e, phase, x, z, action, activeStart, activeEnd)
  end
  -- Subdivide the authored arc, not the entire frame; inactive time must never
  -- become a stationary hitbox or an extra sweep of the player.
  local steps = math.max(1, math.ceil((finish - start) / Claw.step))
  e.clawFrom, e.clawTo = e.clawFrom or {}, e.clawTo or {}
  for step = 1, steps do
    local t1 = start + (finish - start) * (step - 1) / steps
    local t2 = start + (finish - start) * step / steps
    local from = playerAt(previous, current, (t1 - before) / duration, e.clawFrom, g.world)
    local to = playerAt(previous, current, (t2 - before) / duration, e.clawTo, g.world)
    local x1, y1, z1, dx1, dz1 = point(t1)
    local x2, y2, z2, dx2, dz2 = point(t2)
    for _, reach in ipairs(M.depths(action)) do
      local hit, t, contact = M.contact(
        g,
        x1 + dx1 * reach,
        z1 + dz1 * reach,
        x2 + dx2 * reach,
        z2 + dz2 * reach,
        y1,
        action and action.contactRadius or Claw.radius,
        from,
        to,
        y2,
        body
      )
      if hit then
        local fraction = (t1 - before + (t2 - t1) * t) / duration
        contact.fraction = fraction
        contact.time = fraction * duration
        return true, fraction, contact
      end
    end
  end
  return false
end
return M
