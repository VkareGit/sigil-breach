-- Body motion after a hit: world contact, flight, landing and their effects.
-- Decision making stays in ai.lua; impulse math stays in body_physics.lua.
local Signal = require('src.session.signal')
local MathX = require('src.core.mathx')
local W = require('src.world.arena')
local Rules = require('src.combat.rules')
local Archetypes = require('src.content.enemies')
local Physics = require('src.physics.body_physics')
local K = require('src.physics.kinematics')
local Corpse = require('src.enemies.corpse')
local Anim = require('src.enemies.animation')
local SupportPath = require('src.physics.support_path')
local Pools = require('src.session.world')
local Body = {}
local sqrt = math.sqrt
local len = MathX.len
local radius = Rules.radius
-- Shove integration with drag. The speed lost against a wall is a slam and
-- the rest slides along it; a fast body hands momentum to the body it hits.
local function push(g, e, dt, drag)
  local decay, travel = Physics.drag(drag, dt)
  local dx, dz = e.pushX * travel, e.pushZ * travel
  local vx, vz, collided = W.move(g.world, e, dx, dz, radius(e))
  if collided and travel > 0 then
    vx, vz = vx or 0, vz or 0
    local lost = len(dx - vx, dz - vz) / travel
    e.pushX, e.pushZ = vx / travel, vz / travel
    if Rules.slam(g, e, lost) > 0 then
      Signal(g, 'WallSlam', { body = e, lost = lost })
    end
  end
  for _, o in ipairs(Pools.of(g, 'enemies')) do
    if
      o ~= e
      and o.hp > 0
      and len(o.x - e.x, o.z - e.z) < radius(o) + radius(e) + Archetypes.defaults.contactMargin
    then
      if Rules.collide(g, e, o) then
        Signal(g, 'BodiesCollided', { body = e, other = o })
      end
    end
  end
  e.pushX, e.pushZ = e.pushX * decay, e.pushZ * decay
end
-- The fall of a killed body, integrated in closed form so the result does
-- not depend on the frame rate: flight under gravity with air drag, landing
-- (thud, one bounce if hard), then sliding with ground drag until life ends.
local function fall(g, e, dt)
  local F = Archetypes.defaults.fall
  local remaining = math.min(dt, math.max(0, F.life - e.deathTime))
  local elapsed = e.deathTime
  local iterations = 0
  while g.world.elevations or iterations < 6 do
    iterations = iterations + 1
    if remaining <= 1e-9 then
      break
    end
    local y, vy = e.fallY or 0, e.fallVY or 0
    if y > 0 or vy > 0 then
      local land = g.world.elevations and K.fallTime(y, vy, F.gravity)
        or (vy + sqrt(vy * vy + 2 * F.gravity * y)) / F.gravity
      local step = math.min(remaining, land)
      push(g, e, step, F.airDrag)
      -- Horizontal travel can leave a ledge. W.move preserved world height by
      -- rebasing fallY to the new support; do not overwrite it with old support.
      if g.world.elevations then
        y = e.fallY or 0
      end
      local endY = y + vy * step - 0.5 * F.gravity * step * step
      if
        (not g.world.elevations and step >= land - 1e-12) or (g.world.elevations and endY <= 0)
      then
        local hit = -(vy - F.gravity * land)
        e.fallY = 0
        e.fallVY = hit > F.bounceFrom and hit * F.bounce or 0
        if not e.fallLanded then
          e.fallLanded = elapsed + step
        end
        Corpse.land(g, e, hit, elapsed + step)
      else
        e.fallY = endY
        e.fallVY = vy - F.gravity * step
      end
      remaining = remaining - step
      elapsed = elapsed + step
    else
      local step = remaining
      if g.world.elevations then
        local _, travel = Physics.drag(F.groundDrag, remaining)
        local fraction =
          SupportPath.firstChange(g.world, e.x, e.z, e.pushX * travel, e.pushZ * travel)
        if fraction then
          step = SupportPath.time(fraction, F.groundDrag, remaining)
        end
      end
      push(g, e, step, F.groundDrag)
      remaining = remaining - step
      elapsed = elapsed + step
    end
  end
  -- At the end of its fall the body is at rest.
  if e.deathTime + dt >= F.life then
    e.pushX, e.pushZ = 0, 0
  end
  local contactTime = Corpse.contactTime(Anim.extended(e.kind))
  if
    (e.fallY or 0) <= 0
    and (e.fallVY or 0) <= 0
    and e.deathTime < contactTime
    and e.deathTime + dt >= contactTime
  then
    Corpse.land(g, e, nil, contactTime)
  end
end
-- Contact cooldowns count down even after a body has come to rest.
-- Previously slamLock only ticked while moving, suppressing a later impact.
function Body.recover(e, dt)
  e.slamLock = math.max(0, (e.slamLock or 0) - dt)
  e.collideLock = math.max(0, (e.collideLock or 0) - dt)
  local spring = Archetypes.defaults.flinch
  e.flinchLean, e.flinchLeanV =
    K.spring(e.flinchLean or 0, e.flinchLeanV or 0, 0, spring.stiffness, spring.damping, dt)
end
Body.push = push
Body.fall = fall
return Body
