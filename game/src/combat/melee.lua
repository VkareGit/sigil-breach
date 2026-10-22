-- Finite contact volumes evaluated only during their authored active window.
local MathX = require('src.core.mathx')
local B = require('src.combat.ballistics')
local W = require('src.world.arena')
local Ground = require('src.physics.ground')
local Anchor = require('src.enemies.contact_anchor')
-- The knight's hit volume: radius, height and floor clearance (body data).
local knight = require('src.content.enemies').player.body
local Claw = require('src.content.combat_defaults').claw
local M = {}
local reachSamples = Claw.reach
local lerp = MathX.lerp
local function playerAt(previous, current, t, out)
  out = out or {}
  out.x, out.z = lerp(previous.x, current.x, t), lerp(previous.z, current.z, t)
  out.jump = lerp(previous.jump or 0, current.jump or 0, t)
  out.crouch = lerp(previous.crouch or 0, current.crouch or 0, t)
  return out
end
M.playerAt = playerAt
-- Restrict [lo, hi] to a + b*t >= 0. Preserve a crouching/jumping
-- body's moving upper and lower planes instead of its largest pose.
local function clip(lo, hi, a, b)
  if math.abs(b) < 1e-10 then
    if a < 0 then
      return nil
    end
    return lo, hi
  end
  local t = -a / b
  if b > 0 then
    lo = math.max(lo, t)
  else
    hi = math.min(hi, t)
  end
  if lo > hi then
    return nil
  end
  return lo, hi
end
function M.contact(g, x1, z1, x2, z2, y, radius, previous, current, endY)
  local p = current or g.player
  previous = previous or p
  local dx, dz = x2 - x1, z2 - z1
  local dy = (endY or y) - y
  local rx, rz = dx - (p.x - previous.x), dz - (p.z - previous.z)
  local ex, ez = x1 - previous.x, z1 - previous.z
  local a = rx * rx + rz * rz
  local r = knight.radius + radius
  local c = ex * ex + ez * ez - r * r
  local lo, hi = 0, 1
  if a < 1e-12 then
    if c > 0 then
      return false
    end
  else
    local b = ex * rx + ez * rz
    local disc = b * b - a * c
    if disc < 0 then
      return false
    end
    local root = math.sqrt(disc)
    lo = math.max(0, (-b - root) / a)
    hi = math.min(1, (-b + root) / a)
    if lo > hi then
      return false
    end
  end
  local jump = previous.jump or 0
  local jumpDelta = (p.jump or 0) - jump
  lo, hi = clip(lo, hi, y - jump - knight.feet + radius, dy - jumpDelta)
  if not lo then
    return false
  end
  lo, hi = clip(
    lo,
    hi,
    jump + knight.height - (previous.crouch or 0) + radius - y,
    jumpDelta - ((p.crouch or 0) - (previous.crouch or 0)) - dy
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
  if not W.visible(g.world, lerp(x1, x2, lo), lerp(z1, z2, lo), px, pz) then
    return false
  end
  return true, lo
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
    return ax, ay, az, e.lungeX, e.lungeZ
  end
  -- Unannotated extension art retains the generic physical swing. Existing
  -- creatures use their named painted contact, not this fallback arc.
  if not activeStart then
    activeStart, activeEnd = M.window(action)
  end
  local a = math.atan2(e.lungeX, e.lungeZ)
  local yaw = a - Claw.arc + 2 * Claw.arc * (phase - activeStart) / (activeEnd - activeStart)
  return x, Claw.height, z, math.sin(yaw), math.cos(yaw)
end
-- The depths along the forward direction where the contact is sampled.
function M.depths(action)
  return action and action.contactReach or reachSamples
end
-- current (optional): the body swept against now (default the knight).
function M.claw(g, e, oldX, oldZ, previous, before, after, movementEnd, active, current, action)
  current = current or g.player
  -- The authored active window comes from the attack's data (default claw).
  local activeStart = active and active[1] or Claw.active[1]
  local activeEnd = active and active[2] or Claw.active[2]
  local start, finish = math.max(before, activeStart), math.min(after, activeEnd)
  if finish <= start or after <= before then
    return false
  end
  local duration = after - before
  local movingDuration = math.max(1e-9, math.min(after, movementEnd or after) - before)
  previous = previous or g.player
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
    local from = playerAt(previous, current, (t1 - before) / duration, e.clawFrom)
    local to = playerAt(previous, current, (t2 - before) / duration, e.clawTo)
    local x1, y1, z1, dx1, dz1 = point(t1)
    local x2, y2, z2, dx2, dz2 = point(t2)
    for _, reach in ipairs(M.depths(action)) do
      local hit, t = M.contact(
        g,
        x1 + dx1 * reach,
        z1 + dz1 * reach,
        x2 + dx2 * reach,
        z2 + dz2 * reach,
        y1,
        action and action.contactRadius or Claw.radius,
        from,
        to,
        y2
      )
      if hit then
        return true, (t1 - before + (t2 - t1) * t) / duration
      end
    end
  end
  return false
end
return M
