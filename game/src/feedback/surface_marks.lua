-- Small painted consequences on the existing arena. No collision/damage rules.
local MathX = require('src.core.mathx')
local Collision = require('src.physics.collision')
local S = { limit = 96, duration = 36, fade = 6, path = 'assets/art/impact-scars-v17.png' }
local abs, min, max, sqrt = math.abs, math.min, math.max, math.sqrt
local clamp = MathX.clamp
local function cell(w, x, z)
  return w and w.map[math.floor(z + 0.5)] and w.map[math.floor(z + 0.5)][math.floor(x + 0.5)]
end
-- Collision uses ideal tile faces; visible lime is 1 cm proud of that face.
-- Niche and fillet offsets come from the actual boxes in world.rebuild.
function S.mount(world, c)
  local n = c.normal or {}
  local nx, ny, nz = n[1] or 0, n[2] or 0, n[3] or 0
  if nx * nx + ny * ny + nz * nz < 0.5 then
    return
  end
  local x, y, z = c.x, c.y, c.z
  local surface = 'wall'
  if abs(ny) > 0.7 then
    nx, nz = 0, 0
    ny = ny > 0 and 1 or -1
    if c.kind == 'floor' then
      y = 0.004
      surface = 'floor'
    elseif c.kind == 'ceiling' then
      y = y - 0.004
      surface = 'ceiling'
    else
      -- A cap is a wall's or a pillar's (an unknown cell reads as wall).
      local cx, cz = math.floor(x + 0.5), math.floor(z + 0.5)
      y = Collision.top(cell(world, x, z) or 1, world, cx, cz) + 0.004
      surface = 'cap'
    end
  else
    -- Pillars have octagonal shafts AND exposed square decorative panels.
    -- Mount onto the visible panel, not inside the ideal ballistic cylinder.
    local cx, cz = math.floor(x - nx * 0.12 + 0.5), math.floor(z - nz * 0.12 + 0.5)
    if not cell(world, cx, cz) or cell(world, cx, cz) == 0 then
      return
    end
    -- Fallen masonry leaves nothing to mark at this height.
    if y > Collision.top(cell(world, cx, cz), world, cx, cz) then
      return
    end
    if abs(nx) >= abs(nz) then
      nx = nx >= 0 and 1 or -1
      nz = 0
      x = cx + nx * 0.5
    else
      nz = nz >= 0 and 1 or -1
      nx = 0
      z = cz + nz * 0.5
    end
    ny = 0
    local ox, oz = cx + nx, cz + nz
    local mural = ((ox == 3 or ox == 29) and oz >= 14 and oz <= 18)
      or (oz == 29 and ox >= 14 and ox <= 18)
    local tangent = nx ~= 0 and z - oz or x - ox
    local offset = 0.014
    if (ox + oz) % 3 == 0 and not mural then
      if abs(tangent) < 0.46 and y >= 0.55 and y <= 3.35 then
        offset = 0.0692
      end
      if abs(tangent) < 0.0175 and y >= 0.7 and y <= 2.95 then
        offset = 0.0865
      end
    end
    x, z = x + nx * offset, z + nz * offset
  end
  -- The visible surface is proud of the ideal collision face. Intersect that
  -- plane along the actual shot, so an oblique scar remains under the aim ray.
  local dx, dy, dz = c.dx or 0, c.dy or 0, c.dz or 0
  local approach = dx * nx + dy * ny + dz * nz
  if approach < -0.04 then
    local shift = ((x - c.x) * nx + (y - c.y) * ny + (z - c.z) * nz) / approach
    if math.abs(shift) > 0.75 then
      return
    end -- no detached scrape at extreme grazing angles
    x, y, z = c.x + dx * shift, c.y + dy * shift, c.z + dz * shift
  end
  return x, y, z, nx, ny, nz, surface
end
function S.emit(g, c, response)
  if
    not response
    or response.energy <= 0
    or (c.kind ~= 'wall' and c.kind ~= 'floor' and c.kind ~= 'ceiling')
  then
    return
  end
  local x, y, z, nx, ny, nz, surface = S.mount(g.world, c)
  if not x then
    return
  end
  local size = clamp(0.060 + sqrt(response.normalEnergy) * 0.012, 0.065, 0.23)
  local list = g.view.surfaceMarks or {}
  g.view.surfaceMarks = list
  g.view.surfaceMarkPool = g.view.surfaceMarkPool or {}
  -- Overlapping pellets deepen one scar rather than accumulating coplanar cards.
  for i = #list, 1, -1 do
    local d = list[i]
    if
      d.nx * nx + d.ny * ny + d.nz * nz > 0.99
      and (d.x - x) ^ 2 + (d.y - y) ^ 2 + (d.z - z) ^ 2 < (min(d.size, size) * 0.24) ^ 2
    then
      d.size = min(0.25, max(d.size, size) * 1.035)
      d.age = 0
      return d
    end
  end
  local d = (#list >= S.limit and table.remove(list, 1))
    or table.remove(g.view.surfaceMarkPool)
    or {}
  d.x, d.y, d.z, d.nx, d.ny, d.nz = x, y, z, nx, ny, nz
  d.size, d.age, d.surface, d.material = size, 0, surface, response.material
  d.kind = c.kind
  d.frame = (response.material == 'stone' and 3 or 1) + (math.floor(c.seed or 0) % 2)
  d.rotation = ((c.seed or 0) * 2.39996323) % (2 * math.pi)
  d.stretch = 1 + clamp(1 - response.incidence, 0, 1) * 0.65
  d.energy = response.energy
  list[#list + 1] = d
  return d
end
function S.alpha(d)
  return clamp((S.duration - d.age) / S.fade, 0, 1) * 0.91
end
function S.update(g, dt)
  local list = g.view.surfaceMarks or {}
  g.view.surfaceMarkPool = g.view.surfaceMarkPool or {}
  local write = 1
  for i = 1, #list do
    local d = list[i]
    d.age = d.age + dt
    if d.age < S.duration then
      list[write] = d
      write = write + 1
    elseif #g.view.surfaceMarkPool < S.limit then
      g.view.surfaceMarkPool[#g.view.surfaceMarkPool + 1] = d
    end
  end
  for i = #list, write, -1 do
    list[i] = nil
  end
end
return S
