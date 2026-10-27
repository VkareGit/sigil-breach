-- A painted flinch has one local spring and an explicit source-facing basis.
-- The source body remains its reference while present (the original single
-- observer convention); after it leaves, its last contact origin stands in.
-- Other observers project that same spring, never rewrite it on drawing.
local Pools = require('src.session.world')
local Flinch = {}
local function axis(e, x, z)
  local yaw = math.atan2(x - e.x, z - e.z)
  return math.cos(yaw), -math.sin(yaw)
end
local function sourceAxis(g, e)
  local source = e.flinchOwner and Pools.get(g, e.flinchOwner)
  if source then
    return axis(e, source.x, source.z)
  end
  return axis(e, e.flinchOriginX, e.flinchOriginZ)
end
function Flinch.begin(g, e, origin)
  local x, z = axis(e, origin.x, origin.z)
  if e.flinchOriginX ~= nil and not (origin.id and origin.id == e.flinchOwner) then
    local oldX, oldZ = sourceAxis(g, e)
    local projection = oldX * x + oldZ * z
    e.flinchLean = (e.flinchLean or 0) * projection
    e.flinchLeanV = (e.flinchLeanV or 0) * projection
  end
  e.flinchOwner, e.flinchOriginX, e.flinchOriginZ = origin.id, origin.x, origin.z
  return x, z
end
-- Scalars can be interpolated only within one source basis. Repeated hits
-- from the same body follow it, including while its contact position moves.
-- An anonymous source instead has only its retained contact coordinates.
function Flinch.sameBasis(before, after)
  if before.flinchOriginX == nil or after.flinchOriginX == nil then
    return before.flinchOriginX == after.flinchOriginX
  end
  if before.flinchOwner ~= nil or after.flinchOwner ~= nil then
    return before.flinchOwner == after.flinchOwner
  end
  return before.flinchOriginX == after.flinchOriginX and before.flinchOriginZ == after.flinchOriginZ
end
function Flinch.projection(g, e, observer)
  if e.flinchOriginX == nil or observer.id and observer.id == e.flinchOwner then
    return 1
  end
  local x, z = sourceAxis(g, e)
  local vx, vz = axis(e, observer.x, observer.z)
  return x * vx + z * vz
end
return Flinch
