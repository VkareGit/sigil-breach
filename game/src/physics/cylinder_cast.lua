-- A finite sphere swept against a vertical cylinder. All motion is relative:
-- ox/oz and dx/dz are the sphere's horizontal start and displacement;
-- bottom/top are the cylinder's planes relative to the sphere centre at t=0,
-- with independently moving planes bottomDelta/topDelta over t in [0, 1].
-- This includes translation, jumping and changing stance without a pose union.
-- Preconditions: finite values, nonnegative radii, bottom <= top at both ends.
local Cast = {}
local max, min, sqrt, abs = math.max, math.min, math.sqrt, math.abs
local EPS = 1e-8 -- spatial units, not an enlarged hitbox
local MAX_ITERATIONS = require('src.core.mathx').bisectionIterations

local function clip(lo, hi, value, slope)
  if slope == 0 then
    if value < 0 then
      return nil
    end
  elseif slope > 0 then
    lo = max(lo, -value / slope)
  else
    hi = min(hi, -value / slope)
  end
  if lo <= hi then
    return lo, hi
  end
end

-- Squared separation and half its derivative. Horizontal distance outside
-- the disk and vertical distance outside the two planes form the exact rim.
local function separation(t, ox, oz, dx, dz, bottom, bottomDelta, top, topDelta, bodyRadius)
  local x, z = ox + dx * t, oz + dz * t
  local radial = sqrt(x * x + z * z)
  local side = max(0, radial - bodyRadius)
  local vertical, velocity = 0, 0
  local lower, upper = bottom + bottomDelta * t, top + topDelta * t
  if lower > 0 then
    vertical, velocity = lower, bottomDelta
  elseif upper < 0 then
    vertical, velocity = -upper, -topDelta
  end
  local slope = vertical * velocity
  if side > 0 then
    slope = slope + side * (x * dx + z * dz) / radial
  end
  return side * side + vertical * vertical, slope
end

function Cast.sweep(ox, oz, dx, dz, bottom, bottomDelta, top, topDelta, bodyRadius, radius)
  -- Broad phase: expanded disk intersected with expanded height planes.
  -- Its square rim is only a candidate, never by itself proof of contact.
  local expanded = bodyRadius + radius
  local a, halfB = dx * dx + dz * dz, ox * dx + oz * dz
  local c = ox * ox + oz * oz - expanded * expanded
  local lo, hi = 0, 1
  if a == 0 then
    if c > 0 then
      return nil
    end
  else
    local disc = halfB * halfB - a * c
    if disc < 0 then
      -- Rotating an exact tangent can make the discriminant slightly negative.
      -- Check in spatial units instead of an arbitrary discriminant epsilon.
      local closest = max(0, min(1, -halfB / a))
      local x, z = ox + dx * closest, oz + dz * closest
      if x * x + z * z > (expanded + EPS) ^ 2 then
        return nil
      end
      lo, hi = closest, closest
    else
      local root = sqrt(disc)
      lo, hi = max(lo, (-halfB - root) / a), min(hi, (-halfB + root) / a)
    end
  end
  lo, hi = clip(lo, hi, radius - bottom, -bottomDelta)
  if not lo then
    return nil
  end
  lo, hi = clip(lo, hi, top + radius, topDelta)
  if not lo then
    return nil
  end
  if radius == 0 then
    return lo -- the unexpanded cylinder is already exact for a point
  end
  local threshold = (radius + EPS) ^ 2
  local distance, slope =
    separation(lo, ox, oz, dx, dz, bottom, bottomDelta, top, topDelta, bodyRadius)
  if distance <= threshold then
    return lo -- preserve analytical face/side contacts (the common case)
  end
  if slope >= 0 then
    return nil
  end
  -- Separation squared is convex: norm-minus-radius and each moving plane
  -- are convex, their positive distances are nonnegative. Locate the minimum
  -- by its monotone derivative, then the first radius crossing. This finds
  -- narrow grazes even when both endpoints miss; it never samples fixed poses.
  local entry, left, right = lo, lo, hi
  local tolerance = EPS / max(1, sqrt(a) + max(abs(bottomDelta), abs(topDelta)))
  for _ = 1, MAX_ITERATIONS do
    if right - left <= tolerance then
      break
    end
    local mid = (left + right) * 0.5
    local _, derivative =
      separation(mid, ox, oz, dx, dz, bottom, bottomDelta, top, topDelta, bodyRadius)
    if derivative < 0 then
      left = mid
    else
      right = mid
    end
  end
  local closest = (left + right) * 0.5
  distance = separation(closest, ox, oz, dx, dz, bottom, bottomDelta, top, topDelta, bodyRadius)
  -- Include the endpoint: a monotone approach may first touch at t=1.
  local endDistance = separation(hi, ox, oz, dx, dz, bottom, bottomDelta, top, topDelta, bodyRadius)
  if endDistance < distance then
    closest, distance = hi, endDistance
  end
  if distance > threshold then
    return nil
  end
  left, right = entry, closest
  for _ = 1, MAX_ITERATIONS do
    if right - left <= tolerance then
      break
    end
    local mid = (left + right) * 0.5
    if
      separation(mid, ox, oz, dx, dz, bottom, bottomDelta, top, topDelta, bodyRadius) <= threshold
    then
      right = mid
    else
      left = mid
    end
  end
  return right
end

return Cast
