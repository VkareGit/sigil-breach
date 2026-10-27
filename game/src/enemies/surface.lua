-- A painted body is a billboard, not an invisible box. Runtime queries use
-- immutable baked alpha and authored semantic regions, never GPU/image reads.
-- Motion collision and claw reach remain separate physical descriptions.
local Pose = require('src.enemies.pose')
local Masks = require('src.content.art.hit_masks')
local Anatomy = require('src.content.art.anatomy_regions')
local Ground = require('src.physics.ground')
local Surface = {}
local floor, abs, sin, cos = math.floor, math.abs, math.sin, math.cos
local digits = {}
local alphabet = '0123456789abcdef'
for n = 1, #alphabet do
  digits[alphabet:byte(n)] = n - 1
end
function Surface.painted(mask, u, v, alive)
  local x, y = floor(u * Masks.grid), floor(v * Masks.grid)
  if x < 0 or y < 0 or x >= Masks.grid or y >= Masks.grid then
    return false
  end
  local code = digits[mask[y + 1]:byte(floor(x / 2) + 1)]
  code = floor(code / 4 ^ (1 - x % 2)) % 4
  return code == 1 or code == 3 or (code == 2 and alive ~= false)
end
-- Hex digits holding a painted-body cell (code 1 or 3) in either half: a row
-- with one of them is a row the body reaches (the contour alone does not).
local bodyDigits = {}
for n = 0, #alphabet - 1 do
  local high, low = floor(n / 4), n % 4
  if high % 2 == 1 or low % 2 == 1 then
    bodyDigits[#bodyDigits + 1] = alphabet:sub(n + 1, n + 1)
  end
end
local bodyRow = '[' .. table.concat(bodyDigits) .. ']'
local crowns = setmetatable({}, { __mode = 'k' })
-- The top of the painted body in one mask frame, as v (down from the top of
-- the frame): its highest painted row. Read once per frame, then kept.
function Surface.crown(mask)
  local crown = crowns[mask]
  if not crown then
    crown = 1
    for j = 1, #mask do
      if mask[j]:find(bodyRow) then
        crown = (j - 1) / Masks.grid
        break
      end
    end
    crowns[mask] = crown
  end
  return crown
end
local stature = {}
-- How high the painted body reaches above the floor under it, as posed now:
-- its stature, crouch, flinch, leap and ability sheet, the same pose a shot
-- meets. Its fall frames lie where they are drawn.
-- observer (plan v11 E4): whose eyes the pose is seen from (default: the
-- creature's target, enemies/pose.lua: observerOf).
function Surface.top(g, e, observer)
  local p = Pose.sample(g, e, stature, observer or Pose.observerOf(g, e))
  local masks = p.ability and Masks.abilities[p.ability] or Masks.layouts[p.atlas]
  local mask = assert(masks and masks[p.abilityFrame or p.frame], 'missing baked pigment mask')
  return p.baseY + (1 - Surface.crown(mask)) * p.sy * p.size
end
function Surface.contains(polygon, u, v)
  local inside, last = false, #polygon - 1
  for i = 1, #polygon, 2 do
    local ax, ay, bx, by = polygon[last], polygon[last + 1], polygon[i], polygon[i + 1]
    if (ay > v) ~= (by > v) and u < (bx - ax) * (v - ay) / (by - ay) + ax then
      inside = not inside
    end
    last = i
  end
  return inside
end
function Surface.part(parts, u, v)
  for i = #parts, 1, -1 do
    local part = parts[i]
    if Surface.contains(part.polygon, u, v) then
      return part
    end
  end
end
-- observer (plan v11 E4): the point the billboard turns to (a shooter's eye,
-- a missile's owner); default the controlled knight.
function Surface.prepare(g, e, out, observer)
  local p = Pose.sample(g, e, out, observer)
  -- Art registration is local to the feet. Queries, like the shooter's eye,
  -- use world height even on an authored map with a non-zero ground datum.
  p.baseY = p.baseY + Ground.of(g.world, e)
  local group = p.ability and Anatomy.abilities[p.ability] or Anatomy.layouts[p.regions]
  local index = p.abilityFrame or p.frame
  p.parts = assert(group and group.frames[index], 'missing authored anatomy frame').parts
  p.mask = (p.ability and Masks.abilities[p.ability] or Masks.layouts[p.atlas])[index]
  p.rx, p.rz = cos(p.yaw), -sin(p.yaw)
  p.nx, p.nz = sin(p.yaw), cos(p.yaw)
  p.x, p.z = e.x + p.rx * p.shift, e.z + p.rz * p.shift
  p.width, p.height = p.sx * p.size, p.sy * p.size
  p.alive = e.hp > 0
  return p
end
-- The world point of source-art coordinates (u across, v down the frame, as
-- the regions are authored) on a prepared surface.
function Surface.point(p, u, v)
  if p.mirror > 0.5 then
    u = 1 - u
  end
  local y = (1 - v) * p.height
  local side = (u - 0.5) * p.width + y * p.lean
  return p.x + side * p.rx, p.baseY + y, p.z + side * p.rz
end
-- Where a part is drawn now: the centre of its painted texels (pigment inside
-- its region, where no later region covers it), in source coordinates and in
-- the world; nil when the part is not in this frame or not painted. For
-- diagnostics, aiming tools and tests; a shot never asks it.
local function centre(p, accept)
  local left, top, right, bottom = 1, 1, 0, 0
  for _, part in ipairs(p.parts) do
    if accept(part) then
      local poly = part.polygon
      for i = 1, #poly, 2 do
        left, right = math.min(left, poly[i]), math.max(right, poly[i])
        top, bottom = math.min(top, poly[i + 1]), math.max(bottom, poly[i + 1])
      end
    end
  end
  local n = Masks.grid
  local su, sv, count = 0, 0, 0
  for j = math.max(0, floor(top * n)), math.min(n - 1, floor(bottom * n)) do
    for i = math.max(0, floor(left * n)), math.min(n - 1, floor(right * n)) do
      local u, v = (i + 0.5) / n, (j + 0.5) / n
      if Surface.painted(p.mask, u, v, p.alive) then
        local part = Surface.part(p.parts, u, v)
        if part and accept(part) then
          su, sv, count = su + u, sv + v, count + 1
        end
      end
    end
  end
  if count == 0 then
    return nil
  end
  local u, v = su / count, sv / count
  local x, y, z = Surface.point(p, u, v)
  return x, y, z, u, v
end
function Surface.locate(p, id)
  return centre(p, function(part)
    return part.id == id
  end)
end
-- The same for every hittable part of a damage zone ('torso': ribs, arms,
-- wings...): where a shot at that zone lands on average.
function Surface.locateZone(p, zone)
  return centre(p, function(part)
    return part.zone == zone and part.hittable ~= false
  end)
end
-- Broad phase is exactly the complete sheared quad. It cannot discard any
-- authored limb or alpha texel; no guessed radius or head-index dependency.
function Surface.ray(p, ox, oy, oz, dx, dy, dz, limit, radius)
  if radius and radius > 0 then
    return Surface.sweep(p, ox, oy, oz, dx, dy, dz, limit, radius)
  end
  local den = dx * p.nx + dz * p.nz
  if abs(den) < 1e-8 then
    return
  end
  local d = ((p.x - ox) * p.nx + (p.z - oz) * p.nz) / den
  if d <= 1e-8 or d > limit then
    return
  end
  local y = oy + dy * d - p.baseY
  local side = (ox + dx * d - p.x) * p.rx + (oz + dz * d - p.z) * p.rz
  local u, v = (side - y * p.lean) / p.width + 0.5, 1 - y / p.height
  if p.mirror > 0.5 then
    u = 1 - u
  end
  if not Surface.painted(p.mask, u, v, p.alive) then
    return
  end
  local part = Surface.part(p.parts, u, v)
  if not part or part.hittable == false then
    return
  end
  local sideSign = den < 0 and 1 or -1
  return d,
    part.zone,
    {
      shapeId = part.id,
      zone = part.zone,
      material = part.material,
      normal = { p.nx * sideSign, 0, p.nz * sideSign },
      uv = { u, v },
    }
end
-- Finite projectiles sweep continuously against covered source cells. Each
-- cell is enclosed by its circumscribed sphere: conservative by at most one
-- cell diagonal, explicitly measured by tests. This is NOT an exact 3D mesh.
function Surface.sweep(p, ox, oy, oz, dx, dy, dz, limit, radius)
  local cellX, cellY = p.width / Masks.grid, p.height / Masks.grid
  local pad = math.sqrt((cellX + abs(p.lean) * cellY) ^ 2 + cellY ^ 2) * 0.5
  local reach = radius + pad
  local den = dx * p.nx + dz * p.nz
  local plane = (ox - p.x) * p.nx + (oz - p.z) * p.nz
  local lo, hi = 0, limit
  if abs(den) < 1e-8 then
    if abs(plane) > reach then
      return
    end
  else
    local a, b = (-reach - plane) / den, (reach - plane) / den
    lo, hi = math.max(0, math.min(a, b)), math.min(limit, math.max(a, b))
    if lo > hi then
      return
    end
  end
  local function uv(t)
    local y = oy + dy * t - p.baseY
    local side = (ox + dx * t - p.x) * p.rx + (oz + dz * t - p.z) * p.rz
    return (side - y * p.lean) / p.width + 0.5, 1 - y / p.height
  end
  local u0, v0 = uv(lo)
  local u1, v1 = uv(hi)
  local du, dv = reach * (1 + abs(p.lean)) / p.width, reach / p.height
  local left = math.max(0, floor((math.min(u0, u1) - du) * Masks.grid))
  local right = math.min(Masks.grid - 1, floor((math.max(u0, u1) + du) * Masks.grid))
  local top = math.max(0, floor((math.min(v0, v1) - dv) * Masks.grid))
  local bottom = math.min(Masks.grid - 1, floor((math.max(v0, v1) + dv) * Masks.grid))
  local best, selected
  for j = top, bottom do
    for i = left, right do
      local u, v = (i + 0.5) / Masks.grid, (j + 0.5) / Masks.grid
      local sourceU = p.mirror > 0.5 and 1 - u or u
      if Surface.painted(p.mask, sourceU, v, p.alive) then
        local part = Surface.part(p.parts, sourceU, v)
        if part and part.hittable ~= false then
          local y = (1 - v) * p.height
          local side = (u - 0.5) * p.width + y * p.lean
          local cx, cy, cz = p.x + side * p.rx, p.baseY + y, p.z + side * p.rz
          local ex, ey, ez = ox - cx, oy - cy, oz - cz
          local dot = ex * dx + ey * dy + ez * dz
          local discriminant = dot * dot - (ex * ex + ey * ey + ez * ez - reach * reach)
          if discriminant >= 0 then
            local d = math.max(0, -dot - math.sqrt(discriminant))
            if -dot + math.sqrt(discriminant) >= 0 and d <= limit and (not best or d < best) then
              best = d
              local nx, ny, nz = ex + dx * d, ey + dy * d, ez + dz * d
              local length = math.max(1e-8, math.sqrt(nx * nx + ny * ny + nz * nz))
              selected = {
                shapeId = part.id,
                zone = part.zone,
                material = part.material,
                normal = { nx / length, ny / length, nz / length },
                uv = { sourceU, v },
                tolerance = pad,
              }
            end
          end
        end
      end
    end
  end
  return best, selected and selected.zone, selected
end
return Surface
