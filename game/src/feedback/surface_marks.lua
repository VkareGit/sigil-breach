-- Small painted consequences on the existing arena. No collision/damage rules.
local Tiles = require('src.core.tiles')
local MathX = require('src.core.mathx')
local Collision = require('src.physics.collision')
local Scars = require('src.content.scars')
local S = { limit = Scars.limit, duration = Scars.duration, fade = Scars.fade, path = Scars.path }
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
  if abs(ny) > Scars.flat then
    nx, nz = 0, 0
    ny = ny > 0 and 1 or -1
    if c.kind == 'floor' then
      y = Scars.proud
      surface = 'floor'
    elseif c.kind == 'ceiling' then
      y = y - Scars.proud
      surface = 'ceiling'
    else
      -- A cap is a wall's or a pillar's (an unknown cell reads as wall).
      local cx, cz = math.floor(x + 0.5), math.floor(z + 0.5)
      y = Collision.top(cell(world, x, z) or Tiles.wall, world, cx, cz) + Scars.proud
      surface = 'cap'
    end
  else
    -- Pillars have octagonal shafts AND exposed square decorative panels.
    -- Mount onto the visible panel, not inside the ideal ballistic cylinder.
    local cx, cz = math.floor(x - nx * Scars.probe + 0.5), math.floor(z - nz * Scars.probe + 0.5)
    if not cell(world, cx, cz) or Tiles.walkable[cell(world, cx, cz)] then
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
    local mural = false
    for _, wall in ipairs(world.decor.jointless or {}) do
      mural = mural or (ox >= wall[1] and ox <= wall[3] and oz >= wall[2] and oz <= wall[4])
    end
    local tangent = nx ~= 0 and z - oz or x - ox
    local offset = Scars.wall
    local niche, fillet = Scars.niche, Scars.fillet
    if (ox + oz) % niche.every == 0 and not mural then
      if abs(tangent) < niche.half and y >= niche.low and y <= niche.high then
        offset = niche.offset
      end
      if abs(tangent) < fillet.half and y >= fillet.low and y <= fillet.high then
        offset = fillet.offset
      end
    end
    x, z = x + nx * offset, z + nz * offset
  end
  -- The visible surface is proud of the ideal collision face. Intersect that
  -- plane along the actual shot, so an oblique scar remains under the aim ray.
  local dx, dy, dz = c.dx or 0, c.dy or 0, c.dz or 0
  local approach = dx * nx + dy * ny + dz * nz
  if approach < Scars.grazing then
    local shift = ((x - c.x) * nx + (y - c.y) * ny + (z - c.z) * nz) / approach
    if math.abs(shift) > Scars.detached then
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
  local Z = Scars.size
  local size = clamp(Z.base + sqrt(response.normalEnergy) * Z.gain, Z.low, Z.high)
  local list = g.view.surfaceMarks or {}
  g.view.surfaceMarks = list
  g.view.surfaceMarkPool = g.view.surfaceMarkPool or {}
  -- Overlapping pellets deepen one scar rather than accumulating coplanar cards.
  for i = #list, 1, -1 do
    local d = list[i]
    if
      d.nx * nx + d.ny * ny + d.nz * nz > Scars.coplanar
      and (d.x - x) ^ 2 + (d.y - y) ^ 2 + (d.z - z) ^ 2 < (min(d.size, size) * Scars.overlap) ^ 2
    then
      d.size = min(Scars.deepest, max(d.size, size) * Scars.deepen)
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
  d.frame = (response.material == 'stone' and Scars.stoneFrame or 1) + (math.floor(c.seed or 0) % 2)
  d.rotation = ((c.seed or 0) * Scars.turn) % (2 * math.pi)
  d.stretch = 1 + clamp(1 - response.incidence, 0, 1) * Scars.stretch
  d.energy = response.energy
  list[#list + 1] = d
  return d
end
function S.alpha(d)
  return clamp((S.duration - d.age) / S.fade, 0, 1) * Scars.opacity
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
