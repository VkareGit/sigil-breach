-- Foundation layer (src/core): small pure helpers shared by every layer,
-- content and physics included. Core depends on nothing but core, so any
-- module may use it without creating a dependency cycle.
local M = {}
-- Bounded interval refinement with double precision, independent of game
-- balance. Solvers may stop earlier at their own spatial tolerance.
M.bisectionIterations = 64 -- constant: double precision is reached
local sqrt, min, max, pi = math.sqrt, math.min, math.max, math.pi
function M.clamp(v, low, high)
  return max(low, min(high, v))
end
-- A share (0..1) as a percentage.
function M.percent(share)
  return share * 100 -- constant: a percent
end
function M.clamp01(v)
  return max(0, min(1, v))
end
-- A real, finite number (not NaN, not infinite).
function M.finite(v)
  return type(v) == 'number' and v == v and v ~= math.huge and v ~= -math.huge
end
-- Length of a horizontal vector (x, z).
function M.len(x, z)
  return sqrt(x * x + z * z)
end
-- Horizontal distance between two records with x and z.
function M.distance(a, b)
  local dx, dz = a.x - b.x, a.z - b.z
  return sqrt(dx * dx + dz * dz)
end
-- Hermite smoothstep: 0 at edge0, 1 at edge1, eased between (edges may be reversed).
function M.smoothstep(edge0, edge1, x)
  local t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
  return t * t * (3 - 2 * t)
end
function M.lerp(a, b, t)
  return a + (b - a) * t
end
-- An angle wrapped into [-pi, pi).
function M.wrapAngle(a)
  return (a + pi) % (2 * pi) - pi
end
-- Move value toward target by at most step.
function M.approach(value, target, step)
  if value < target then
    return min(target, value + step)
  end
  return max(target, value - step)
end
return M
