-- Closed-form integration for constant acceleration and damped weapon springs.
local K = {}
-- Positive descending root of h + v*t - g*t^2/2 = 0. The rational form
-- avoids cancellation when a descending body is extremely close to support.
function K.fallTime(height, velocity, gravity)
  local root = math.sqrt(math.max(0, velocity * velocity + 2 * gravity * height))
  if velocity < 0 then
    return math.max(0, 2 * height / (root - velocity))
  end
  return (velocity + root) / gravity
end
function K.spring(x, v, target, k, d, dt)
  local y = x - target
  local a = d * 0.5
  local q = k - a * a
  local decay = math.exp(-a * dt)
  if q > 1e-8 then
    local w = math.sqrt(q)
    local c, s = math.cos(w * dt), math.sin(w * dt) / w
    return target + decay * (y * c + (v + a * y) * s), decay * (v * c - (a * v + k * y) * s)
  elseif q < -1e-8 then
    local w = math.sqrt(-q)
    local r1, r2 = -a + w, -a - w
    local c1 = (v - r2 * y) / (r1 - r2)
    local c2 = y - c1
    local e1, e2 = math.exp(r1 * dt), math.exp(r2 * dt)
    return target + c1 * e1 + c2 * e2, c1 * r1 * e1 + c2 * r2 * e2
  end
  local b = v + a * y
  return target + decay * (y + b * dt), decay * (v - a * b * dt)
end
-- How every body's own velocity follows what it means to do (PLAN E2): it
-- moves toward the wanted velocity (wx, wz) at rate m/s^2, for at most dt.
-- Returns the new velocity and the time it spent changing (the rest of dt it
-- holds the wanted velocity). The controller says only what is wanted and how
-- fast it may change: the knight's keys (player/feel.lua), a creature's walk
-- (enemies/walking.lua).
function K.steer(vx, vz, wx, wz, rate, dt)
  local ax, az = wx - vx, wz - vz
  local al = math.sqrt(ax * ax + az * az)
  if al <= 0 then
    return vx, vz, 0
  end
  local active = math.min(dt, al / rate)
  local amount = rate * active
  return vx + ax / al * amount, vz + az / al * amount, active
end
-- Free flight under gravity for dt: the height and vertical velocity after
-- it. Every body flies by this (PLAN E2): the knight, a leap, a fallen body.
function K.flight(height, velocity, gravity, dt)
  return height + velocity * dt - 0.5 * gravity * dt * dt, velocity - gravity * dt
end
-- The knight's vertical step: flight that ends on the floor, with the speed
-- it met it at.
function K.vertical(height, velocity, gravity, dt)
  local h, v = K.flight(height, velocity, gravity, dt)
  if h <= 0 then
    local impact = -math.sqrt(math.max(0, velocity * velocity + 2 * gravity * height))
    return 0, 0, impact
  end
  return h, v
end
return K
