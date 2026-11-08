local Context = require('src.session.context')
-- Presentation responses to real kinematic contacts, not a second collision
-- solver. Mass 1 is the reference equipped human; momentum/energy/force are
-- relative game quantities, not kilograms, joules or a firearm simulation.
local MathX = require('src.core.mathx')
local Collision = require('src.physics.collision')
local FX = require('src.feedback.effects')
local Impulses = require('src.feedback.impulses')
local Hands = require('src.feedback.hand_profile')
local C = require('src.content.tuning').contact
local I = {
  mass = C.mass,
  wallCushion = C.wallCushion,
  landingCushion = C.landingCushion,
  takeoffCushion = C.takeoffCushion,
}
local finite = MathX.finite
function I.measure(bx, by, bz, ax, ay, az, mass, seconds)
  mass = mass or I.mass
  seconds = seconds or I.wallCushion
  if
    not (
      finite(bx)
      and finite(by)
      and finite(bz)
      and finite(ax)
      and finite(ay)
      and finite(az)
      and finite(mass)
      and finite(seconds)
    )
  then
    return nil
  end
  if mass <= 0 or seconds <= 0 then
    return nil
  end
  local dx, dy, dz = bx - ax, by - ay, bz - az
  local lostSpeed = math.sqrt(dx * dx + dy * dy + dz * dz)
  local before = 0.5 * mass * (bx * bx + by * by + bz * bz)
  local after = 0.5 * mass * (ax * ax + ay * ay + az * az)
  local impulse = mass * lostSpeed
  return {
    mass = mass,
    cushionTime = seconds,
    lostSpeed = lostSpeed,
    deltaX = dx,
    deltaY = dy,
    deltaZ = dz,
    impulse = impulse,
    energyBefore = before,
    energyAfter = after,
    energyLost = math.max(0, before - after),
    energyGained = math.max(0, after - before),
    meanForce = impulse / seconds,
  }
end
function I.kick(impulse, kind)
  -- Monotonic, saturating response: ordinary contact is readable while a dash
  -- or test-field drop can never throw the hands across the aiming area.
  local kick = kind == 'wall' and C.wallKick or C.landingKick
  return kick.most * (1 - math.exp(-math.max(0, impulse) / kick.scale))
end
function I.init(g)
  g.view.movementContact = { blocked = false, x = 0, z = 0, nx = 0, nz = 0 }
  g.view.movementImpactSerial = 0
  g.view.lastMovementImpact = nil
  g.view.lastWallImpact = nil
  g.view.lastLandingImpact = nil
end
local function record(g, report, kind)
  report.kind = kind
  report.time = g.elapsed or 0
  g.view.movementImpactSerial = g.view.movementImpactSerial + 1
  report.serial = g.view.movementImpactSerial
  g.view.lastMovementImpact = report
  return report
end
function I.wall(g, collided, beforeX, beforeZ, afterX, afterZ, oldX, oldZ, previousX, previousZ)
  local p = Context.actor(g)
  local state = g.view.movementContact
  if not state then
    I.init(g)
    state = g.view.movementContact
  end
  if
    state.previousX
    and (oldX - state.previousX) ^ 2 + (oldZ - state.previousZ) ^ 2 > C.relocated ^ 2
  then
    -- Field shortcuts can relocate the player without rebuilding the run.
    -- The old wall and its impulse must not follow them across the arena.
    state.blocked = false
    g.view.weaponImpactX, g.view.weaponImpactY, g.view.weaponImpactRoll = 0, 0, 0
    g.view.weaponImpactVX, g.view.weaponImpactVY, g.view.weaponImpactVRoll = 0, 0, 0
    g.view.weaponLastYaw, g.view.weaponLastPitch = p.yaw, p.pitch or 0
  end
  state.previousX, state.previousZ = p.x, p.z
  -- Merely releasing a key while touching the wall is not a new approach.
  -- Rearm only after leaving that contact plane by a visible separation.
  if state.blocked and (p.x - state.x) * state.nx + (p.z - state.z) * state.nz > C.rearm then
    state.blocked = false
  end
  if not collided then
    return
  end
  if not (finite(beforeX) and finite(beforeZ) and finite(afterX) and finite(afterZ)) then
    return
  end
  local dx, dz = beforeX - afterX, beforeZ - afterZ
  local loss = math.sqrt(dx * dx + dz * dz)
  if loss < 1e-6 then
    return
  end
  local nx, nz = -dx / loss, -dz / loss
  local approached = -(p.x - oldX) * nx - (p.z - oldZ) * nz
  local fromLast = math.sqrt((p.x - state.x) ^ 2 + (p.z - state.z) ^ 2)
  local newPlane = state.nx * nx + state.nz * nz < C.newPlane and fromLast > C.newPlaneDistance
  local fresh = not state.blocked or newPlane
  if fresh then
    state.x, state.z, state.nx, state.nz = p.x, p.z, nx, nz
  end
  state.blocked = true
  -- Acceleration pressed into an already-touching wall is motor demand, not
  -- acquired momentum. The prior velocity or actual approach must support it.
  local approach = -(previousX or 0) * nx - (previousZ or 0) * nz
  if
    not fresh
    or loss < C.minLoss
    or (approached < C.minApproach and approach < C.minPriorApproach)
  then
    return
  end
  local report = I.measure(beforeX, 0, beforeZ, afterX, 0, afterZ, I.mass, I.wallCushion)
  report.normalX, report.normalZ = nx, nz
  report.x, report.z = p.x, p.z
  report.kick = I.kick(report.impulse, 'wall')
  record(g, report, 'wall')
  g.view.lastWallImpact = report
  local side = (report.deltaX * math.cos(p.yaw) - report.deltaZ * math.sin(p.yaw))
    / report.lostSpeed
  local ahead = (report.deltaX * math.sin(p.yaw) + report.deltaZ * math.cos(p.yaw))
    / report.lostSpeed
  Impulses.react(g.view, 'wall', report.kick, side, ahead)
  return report
end
function I.landingMetrics(speed)
  if not finite(speed) then
    return nil
  end
  local r = I.measure(0, -math.abs(speed), 0, 0, 0, 0, I.mass, I.landingCushion)
  r.kick = I.kick(r.impulse, 'landing')
  return r
end
function I.landing(g, speed)
  local report = I.landingMetrics(speed)
  if not report then
    return
  end
  record(g, report, 'landing')
  g.view.lastLandingImpact = report
  report.dust = 0
  local D = C.dust
  -- Only a drop considerably harder than the normal jump sheds pigment dust.
  -- Energy threshold is deliberate; it is independent of render or tick rate.
  if g.view.motion ~= false and report.energyLost > D.energy then
    local p = Context.actor(g)
    local radius = D.radius + math.min(D.growth, (report.energyLost - D.energy) / D.growthEnergy)
    for side = -1, 1, 2 do
      -- The two short plumes spread outward from the boots, outside the gun's
      -- central silhouette. They remain on the floor rather than in screen space.
      local x = p.x + math.sin(p.yaw) * D.ahead + math.cos(p.yaw) * side * D.apart
      local z = p.z + math.cos(p.yaw) * D.ahead - math.sin(p.yaw) * side * D.apart
      if not Collision.solid(g.world, x, z, D.clearance) then
        FX.emit(g, 'stone', x, D.lift + radius * 0.5, z, radius)
        report.dust = report.dust + 1
      end
    end
  end
  return report
end
function I.takeoff(g, speed)
  if not finite(speed) or speed <= 0 then
    return
  end
  local report = I.measure(0, 0, 0, 0, speed, 0, I.mass, I.takeoffCushion)
  record(g, report, 'takeoff')
  -- The hands take the share of it their weapon's profile gives.
  Impulses.react(g.view, 'takeoff', report.impulse * Hands.current(g).air.takeoff)
  return report
end
return I
