-- Continuous ground-plane circle / tile collision. Rounded corners avoid
-- invisible square snagging; the remaining motion slides on the contact plane.
local MathX = require('src.core.mathx')
local Ground = require('src.physics.ground')
local Grid = require('src.physics.grid')
local C = {}
local abs, sqrt, min, max = math.abs, math.sqrt, math.min, math.max
local EPS = 1e-9
local finite = MathX.finite
-- A deck of the cell (x, z) a body between lift and head would strike: one
-- above what it can step onto, below its head (plan v10 V3).
local function struck(w, x, z, lift, head)
  local decks = Ground.decks(w, x, z)
  if not decks then
    return false
  end
  local datum = w.floor or 0
  for _, deck in ipairs(decks) do
    if datum + deck[2] > lift + EPS and datum + deck[1] < head - EPS then
      return true
    end
  end
  return false
end
-- head (optional, world height): the top of the body whose feet are at feet.
local function occupied(w, x, z, feet, step, head)
  return not w.map[z]
    or not w.map[z][x]
    or w.map[z][x] > 0
    or (feet ~= nil and Ground.height(w, x, z) > feet + (step or 0) + EPS)
    or (head ~= nil and struck(w, x, z, feet + (step or 0), head))
end
-- Round pillars (tile 2) are cylinders of the painted shaft radius for bodies,
-- sight and shots alike (ballistics uses the same value).
C.pillarRadius = 0.46
-- Heights (m) of the solid tiles: walls, the pillars' flat capitals, the
-- roof of a covered cell, and 'outside the map' (never cleared).
C.heights = { wall = 4.2, pillar = 4.8, roof = 4.175, outside = 1000 }
-- The top of a cell's solid (tile nil: outside the map).
function C.top(tile)
  local H = C.heights
  return not tile and H.outside or (tile == 2 and H.pillar or H.wall)
end
local function pillar(w, x, z)
  return w.map[z] and w.map[z][x] == 2
end
function C.solid(w, x, z, r, feet, step, head)
  r = r or 0.20
  if not finite(x) or not finite(z) or not finite(r) or r < 0 then
    return true
  end
  if x - r < 0.5 or z - r < 0.5 or x + r > Grid.width(w) + 0.5 or z + r > Grid.depth(w) + 0.5 then
    return true
  end
  for tz = math.floor(z - r + 0.5), math.floor(z + r + 0.5) do
    for tx = math.floor(x - r + 0.5), math.floor(x + r + 0.5) do
      if occupied(w, tx, tz, feet, step, head) then
        if pillar(w, tx, tz) then
          local R = C.pillarRadius + r
          if (x - tx) ^ 2 + (z - tz) ^ 2 < R * R - EPS then
            return true
          end
        else
          local qx = max(abs(x - tx) - 0.5, 0)
          local qz = max(abs(z - tz) - 0.5, 0)
          if qx * qx + qz * qz < r * r - EPS or (qx == 0 and qz == 0) then
            return true
          end
        end
      end
    end
  end
  return false
end
function C.cast(w, x, z, dx, dz, r, feet, step, head)
  local best, nx, nz, ax, az = 1, nil, nil, nil, nil
  if
    not finite(x)
    or not finite(z)
    or not finite(dx)
    or not finite(dz)
    or not finite(r)
    or r < 0
  then
    return 0, 0, 0
  end
  local length2 = dx * dx + dz * dz
  if length2 < EPS * EPS then
    return
  end
  local function hit(t, hx, hz)
    if t >= -EPS and t <= best + EPS and dx * hx + dz * hz < -EPS then
      t = max(0, t)
      if not nx or t < best - EPS then
        best, nx, nz, ax, az = t, hx, hz, nil, nil
      elseif abs(t - best) <= EPS and (abs(hx - nx) > EPS or abs(hz - nz) > EPS) then
        -- Keep independent planes: an average normal would bounce a diagonal
        -- sideways out of an interior corner instead of stopping it.
        if abs(nx * hz - nz * hx) > 1e-7 then
          ax, az = hx, hz
        end
      end
    end
  end
  local x1 = max(0, math.floor(min(x, x + dx) - r + 0.5))
  local x2 = min(Grid.width(w) + 1, math.floor(max(x, x + dx) + r + 0.5))
  local z1 = max(0, math.floor(min(z, z + dz) - r + 0.5))
  local z2 = min(Grid.depth(w) + 1, math.floor(max(z, z + dz) + r + 0.5))
  for tz = z1, z2 do
    for tx = x1, x2 do
      if pillar(w, tx, tz) then
        local R = C.pillarRadius + r
        local rx, rz = x - tx, z - tz
        local b = rx * dx + rz * dz
        local c = rx * rx + rz * rz - R * R
        local disc = b * b - length2 * c
        if disc >= 0 then
          local t = (-b - sqrt(disc)) / length2
          hit(t, (x + dx * t - tx) / R, (z + dz * t - tz) / R)
        end
      elseif occupied(w, tx, tz, feet, step, head) then
        local left, right, bottom, top = tx - 0.5, tx + 0.5, tz - 0.5, tz + 0.5
        -- Feet use point support; the circular footprint only constrains
        -- horizontal motion. Just after leaving a ledge, the trailing part
        -- can still overlap its riser. It may leave or slide, but never move
        -- farther into that riser. This is a velocity constraint, not a
        -- displacement to add to a body's flight momentum.
        if feet ~= nil and w.map[tz] and w.map[tz][tx] == 0 then
          local qx, qz = max(left, min(right, x)), max(bottom, min(top, z))
          local rx, rz = x - qx, z - qz
          local distance = sqrt(rx * rx + rz * rz)
          if distance > EPS and distance < r then
            hit(0, rx / distance, rz / distance)
          end
        end
        if abs(dx) > EPS then
          local side = dx > 0 and -1 or 1
          local t = ((side < 0 and left - r or right + r) - x) / dx
          local zz = z + dz * t
          if zz >= bottom - EPS and zz <= top + EPS then
            hit(t, side, 0)
          end
        end
        if abs(dz) > EPS then
          local side = dz > 0 and -1 or 1
          local t = ((side < 0 and bottom - r or top + r) - z) / dz
          local xx = x + dx * t
          if xx >= left - EPS and xx <= right + EPS then
            hit(t, 0, side)
          end
        end
        if r > 0 then
          for sx = -1, 1, 2 do
            for sz = -1, 1, 2 do
              local cx, cz = tx + sx * 0.5, tz + sz * 0.5
              local rx, rz = x - cx, z - cz
              local b = rx * dx + rz * dz
              local c = rx * rx + rz * rz - r * r
              local disc = b * b - length2 * c
              if disc >= 0 then
                local t = (-b - sqrt(disc)) / length2
                local hx, hz = x + dx * t - cx, z + dz * t - cz
                if hx * sx >= -EPS and hz * sz >= -EPS then
                  hit(t, hx / r, hz / r)
                end
              end
            end
          end
        end
      end
    end
  end
  if nx then
    return best, nx, nz, ax, az
  end
end
local function project(x, z, nx, nz, ax, az)
  local dot = min(0, x * nx + z * nz)
  local px, pz = x - dot * nx, z - dot * nz
  if not ax or px * ax + pz * az >= -EPS then
    return px, pz
  end
  dot = min(0, x * ax + z * az)
  px, pz = x - dot * ax, z - dot * az
  if px * nx + pz * nz >= -EPS then
    return px, pz
  end
  return 0, 0
end
local function separate(w, o, r, feet, step)
  -- Restores valid shallow overlaps (spawn placement / accumulated roundoff).
  -- Push to the nearest surface, never through the far face of a crossed tile.
  for _ = 1, 8 do
    if not C.solid(w, o.x, o.z, r, feet, step) then
      return true
    end
    local best, bx, bz
    for tz = max(0, math.floor(o.z - r + 0.5)), min(Grid.depth(w) + 1, math.floor(o.z + r + 0.5)) do
      for tx = max(0, math.floor(o.x - r + 0.5)), min(Grid.width(w) + 1, math.floor(o.x + r + 0.5)) do
        if occupied(w, tx, tz, feet, step) then
          local qx = max(tx - 0.5, min(tx + 0.5, o.x))
          local qz = max(tz - 0.5, min(tz + 0.5, o.z))
          local nx, nz = o.x - qx, o.z - qz
          local d = sqrt(nx * nx + nz * nz)
          local depth
          if pillar(w, tx, tz) then
            nx, nz = o.x - tx, o.z - tz
            d = sqrt(nx * nx + nz * nz)
            depth = C.pillarRadius + r - d
            if d > EPS then
              nx, nz = nx / d, nz / d
            else
              nx, nz = 1, 0
            end
          elseif d > EPS then
            depth = r - d
            nx, nz = nx / d, nz / d
          else
            depth = o.x - (tx - 0.5) + r
            nx, nz = -1, 0
            local right = tx + 0.5 - o.x + r
            if right < depth then
              depth = right
              nx, nz = 1, 0
            end
            local down = o.z - (tz - 0.5) + r
            if down < depth then
              depth = down
              nx, nz = 0, -1
            end
            local up = tz + 0.5 - o.z + r
            if up < depth then
              depth = up
              nx, nz = 0, 1
            end
          end
          if depth > EPS and (not best or depth < best) then
            best, bx, bz = depth, nx, nz
          end
        end
      end
    end
    if not best then
      return false
    end
    o.x, o.z = o.x + bx * (best + 1e-7), o.z + bz * (best + 1e-7)
  end
  return not C.solid(w, o.x, o.z, r, feet, step)
end
function C.move(w, o, dx, dz, r, velocity, feet, step, head)
  r = r or 0.20
  if
    not finite(dx)
    or not finite(dz)
    or not finite(o.x)
    or not finite(o.z)
    or not finite(r)
    or r < 0
  then
    return 0, 0, true
  end
  -- Spawn recovery applies to actual walls/pillars. A trailing riser overlap
  -- is resolved by cast's directional constraint above, never by teleporting
  -- the body sideways as its feet descend past the old floor.
  if C.solid(w, o.x, o.z, r) and not separate(w, o, r) then
    if velocity then
      velocity.vx, velocity.vz = 0, 0
    end
    return 0, 0, true
  end
  local vx, vz = dx, dz
  local collided = false
  for _ = 1, 5 do
    if dx * dx + dz * dz < 1e-16 then
      break
    end
    local t, nx, nz, ax, az = C.cast(w, o.x, o.z, dx, dz, r, feet, step, head)
    if not t then
      o.x, o.z = o.x + dx, o.z + dz
      break
    end
    collided = true
    o.x, o.z = o.x + dx * t + (nx + (ax or 0)) * 1e-7, o.z + dz * t + (nz + (az or 0)) * 1e-7
    dx, dz = dx * (1 - t), dz * (1 - t)
    dx, dz = project(dx, dz, nx, nz, ax, az)
    vx, vz = project(vx, vz, nx, nz, ax, az)
    if velocity then
      velocity.vx, velocity.vz = project(velocity.vx, velocity.vz, nx, nz, ax, az)
    end
  end
  return vx, vz, collided
end
function C.visible(w, x, z, tx, tz)
  if C.solid(w, x, z, 0.02) or C.solid(w, tx, tz, 0.02) then
    return false
  end
  return C.cast(w, x, z, tx - x, tz - z, 0.02) == nil
end
return C
