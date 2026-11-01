-- A chapel hall from its map record (content/maps/proving_halls.lua) and its
-- painted surfaces (content/art/chapel_hall.lua). Floors, steps and solid
-- furniture follow the map's heights, so what is drawn is what is walked on.
local Tiles = require('src.core.tiles')
local Art = require('src.content.art.chapel_hall')
local B = require('src.render.kit.builder')
local Relief = require('src.render.kit.relief')
local Light = require('src.render.kit.light')
local Props = require('src.render.kit.props')
local Ground = require('src.physics.ground')
local Ruin = require('src.content.maps.breakables')
local Kinds = require('src.content.breakables')
local Chapel = {}
local abs, cos, sin, sqrt, max, pi = math.abs, math.cos, math.sin, math.sqrt, math.max, math.pi
local PIER = {
  { 0.8, 0.0 },
  { 0.8, 0.5 },
  { 0.72, 0.78 },
  { 0.65, 0.98 },
  { 0.62, 2.7 },
  { 0.69, 2.78 },
  { 0.69, 2.98 },
  { 0.62, 3.06 },
  { 0.62, 5.3 },
  { 0.68, 5.38 },
  { 0.68, 5.56 },
  { 0.62, 5.62 },
  { 0.62, 7.3 },
  { 0.71, 7.42 },
  { 0.88, 8.0 },
  { 0.88, 8.3 },
  { 0.62, 8.4 },
}
local PEDESTAL = {
  { 0.95, 0 },
  { 0.85, 0.18 },
  { 0.48, 0.18 },
  { 0.32, 0.93 },
  { 0.62, 1.046 },
  { 0, 1.046 },
}
local TABLE = { { 0, 0 }, { 0.0, 0.14 }, { 0.09, 0.2 }, { 0.09, 1 }, { 0.0, 1.06 }, { 0.0, 1.18 } }
local FRONT = { 0.006, 0.49, 0.56, 0.006 }
local FIGURE = { 0.575, 0.49, 0.99, 0.006 }
local SLAB = { 0.006, 0.99, 0.49, 0.51 }
local function floorCell(w, hall, list, risers, x, z)
  local h = Ground.cell(w, x, z)
  local height = h < hall.solidFrom and h or 0
  local cx = hall.x
  for i = 0, 1 do
    for j = 0, 1 do
      local x0, z0 = x - 0.5 + i * 0.5, z - 0.5 + j * 0.5
      local x1, z1 = x0 + 0.5, z0 + 0.5
      local function p(a, c)
        return { a, height, c, (a - cx) / 9 + 0.5, c / 9 }
      end
      B.quad(list, p(x0, z0), p(x1, z0), p(x1, z1), p(x0, z1), { x0, height + 9, z0 })
    end
  end
  for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
    local other = Ground.cell(w, x + d[1], z + d[2])
    if other < height and w.map[z + d[2]] and w.map[z + d[2]][x + d[1]] == 0 then
      local px, pz = x + d[1] * 0.5, z + d[2] * 0.5
      local tx, tz = d[2] * 0.5, d[1] * 0.5
      local function p(side, y)
        return {
          px + tx * side,
          y,
          pz + tz * side,
          (px + tz * side + pz + tx * side) / 3.4,
          y / 3.4,
        }
      end
      B.quad(
        risers,
        p(-1, other),
        p(1, other),
        p(1, height),
        p(-1, height),
        { px + d[1] * 9, height / 2, pz + d[2] * 9 },
        0.82
      )
    end
  end
end
local function tombFace(list, a, b, height0, height1, rect, front)
  B.quad(
    list,
    { a[1], height0, a[2], rect[1], rect[2] },
    { b[1], height0, b[2], rect[3], rect[2] },
    { b[1], height1, b[2], rect[3], rect[4] },
    { a[1], height1, a[2], rect[1], rect[4] },
    front
  )
end
local function sarcophagus(lists, s, axis)
  local x0, x1, z0, z1 = s.x - 0.5, s.x + 0.5, s.z1 - 0.5, s.z2 + 0.5
  B.moulded(lists.ashlar, x0, z0, x1, z1, 0, {
    { 0, 0 },
    { 0, 0.14 },
    { 0.06, 0.18 },
    { 0.06, 0.8 },
    { 0, 0.84 },
    { 0, 1.0 },
  }, 0.95)
  local face = s.x < axis and x1 - 0.05 or x0 + 0.05
  local toward = { axis, 1, (z0 + z1) / 2 }
  tombFace(lists.tomb, { face, z0 + 0.1 }, { face, z1 - 0.1 }, 0.2, 0.8, FRONT, toward)
  tombFace(
    lists.tomb,
    { x0 + 0.1, z1 - 0.05 },
    { x1 - 0.1, z1 - 0.05 },
    0.2,
    0.8,
    FIGURE,
    { s.x, 1, 99 }
  )
  tombFace(
    lists.tomb,
    { x0 + 0.1, z0 + 0.05 },
    { x1 - 0.1, z0 + 0.05 },
    0.2,
    0.8,
    FIGURE,
    { s.x, 1, -99 }
  )
  B.quad(
    lists.tomb,
    { x0, 1.003, z0, SLAB[1], SLAB[2] },
    { x1, 1.003, z0, SLAB[1], SLAB[4] },
    { x1, 1.003, z1, SLAB[3], SLAB[4] },
    { x0, 1.003, z1, SLAB[3], SLAB[2] },
    { s.x, 9, s.z1 }
  )
end
local function banner(list, def, cloth)
  local x, z, top = def.from[1], def.from[3], def.to[2]
  local function wob(t)
    return sin(t * 15 + x) * 0.04
  end
  for i = 0, 9 do
    local a, b = i / 10, (i + 1) / 10
    for j = 0, 13 do
      local c, d = j / 14, (j + 1) / 14
      local y1, y2 = top - c * cloth.height, top - d * cloth.height
      local xa, xb = x + (a - 0.5) * cloth.width, x + (b - 0.5) * cloth.width
      B.quad(
        list,
        { xa, y1, z + wob(a), a, c },
        { xb, y1, z + wob(b), b, c },
        { xb, y2, z + wob(b), b, d },
        { xa, y2, z + wob(a), a, d },
        { x, y1, z + 9 }
      )
    end
  end
end
-- The cloth where it fell, in loose folds.
local function fallenBanner(list, def, cloth)
  local x, z = def.from[1], def.from[3] + 0.9
  local function fold(a, b)
    return 0.05 + 0.05 * (sin(a * 11 + x) + sin(b * 9 - x))
  end
  for i = 0, 7 do
    local a, b = i / 8, (i + 1) / 8
    for j = 0, 9 do
      local c, d = j / 10, (j + 1) / 10
      local xa, xb = x + (a - 0.5) * cloth.width * 0.9, x + (b - 0.5) * cloth.width * 0.9
      local za, zb = z + c * cloth.height * 0.42, z + d * cloth.height * 0.42
      B.quad(
        list,
        { xa, fold(a, c), za + sin(c * 7) * 0.1, a, c },
        { xb, fold(b, c), za + sin(c * 7) * 0.1, b, c },
        { xb, fold(b, d), zb + sin(d * 7) * 0.1, b, d },
        { xa, fold(a, d), zb + sin(d * 7) * 0.1, a, d },
        { x, 9, z }
      )
    end
  end
end
local function ribs(list, hall, p)
  local x, z, inward = p.x, p.z, p.x < hall.x and 1 or -1
  local wall = hall.x - inward * (hall.half - 0.1)
  local apex, spring = hall.vaultHeight(hall.x) - 0.5, 8.3
  B.rib(list, B.arc(x + inward * 0.7, spring, z, hall.x, apex, z, 14), 0.42, 0.34, 0.8)
  if abs(x - wall) > 1 then
    B.rib(list, B.arc(x - inward * 0.7, spring, z, wall, 10.4, z, 5), 0.42, 0.34, 0.8)
  end
  for _, s in ipairs({ { 1, hall.piers[#hall.piers].z }, { -1, hall.piers[1].z } }) do
    if z ~= s[2] then
      B.rib(
        list,
        B.arc(x + inward * 0.5, spring, z + s[1] * 0.5, hall.x, apex + 0.4, z + s[1] * 3.5, 14),
        0.2,
        0.2,
        0.7
      )
    end
  end
end
-- A pier that stands to the end, or one that can fall: whole, wounded, stump.
local function pier(sink, hall, p, def, seed)
  local x, z = p.x, p.z
  local lists = sink:scope()
  if not def then
    B.lathe(lists.drum, x, z, PIER, 28, 2, 0.95)
    ribs(lists.drum, hall, p)
    return
  end
  local id = def.id
  B.lathe(sink:scope(id, 'whole').drum, x, z, PIER, 28, 2, 0.95)
  local function bite(angle, y)
    local d = sin(angle * 2 + seed) * sin(y * 1.7 + seed * 2) + sin(angle * 5 - seed) * sin(y * 3.1)
    return max(0, d - 0.35) * 0.42
  end
  B.lathe(sink:scope(id, 'cracked').drum, x, z, PIER, 28, 2, 0.8, bite)
  ribs(sink:scope(id, 'gone').drum, hall, p)
  local after = sink:scope(id, 'after', { rise = 0.9 })
  B.lathe(
    after.drum,
    x,
    z,
    {
      { 0.8, 0.0 },
      { 0.8, 0.5 },
      { 0.72, 0.78 },
      { 0.65, 0.98 },
    },
    28,
    2,
    0.8,
    function(angle, y)
      return y > 0.9 and max(0, sin(angle * 3 + seed)) * 0.4 or 0
    end
  )
end
-- What is left at the edge of a fall: stepped broken courses along the tear
-- and round the hole, then the heap of what came down.
local function ruinOf(sink, hall, def, seed)
  local hole = def.hole
  local glow = Light.new({
    ambient = Art.light.ambient,
    tone = Art.light.tone,
    sources = {
      { hole.x, 13, hole.z, 1, 0.56, 0.32, 3.2, 40 },
      Art.light.sources[1],
    },
  }, 0, 0, {})
  local after = sink:scope(def.id, 'after', { rise = 1.4, light = glow })
  local edge = sink:scope(def.id .. '|edge', 'after', { light = glow })
  local rng = B.random(seed)
  -- The thickness of the broken vault, then loose stones hanging at its lip.
  local function lip(a)
    local r = Ruin.holeEdge(hole, a)
    local x, z = hole.x + cos(a) * r, hole.z + sin(a) * r
    return x, z, abs(x - hall.x) < hall.half and z > hall.chancel and z < hall.south
  end
  local facets = 120
  for i = 0, 119 do
    local a, b = i / facets * 2 * pi, (i + 1) / facets * 2 * pi
    local x1, z1, in1 = lip(a)
    local x2, z2, in2 = lip(b)
    if in1 and in2 then
      local y1, y2 = hall.vaultHeight(x1), hall.vaultHeight(x2)
      local up = 0.5 + 0.22 * sin(i * 1.7 + seed)
      B.quad(
        edge.rubble,
        { x1, y1 - 0.04, z1, x1 / 1.7, y1 / 1.7 },
        { x2, y2 - 0.04, z2, x2 / 1.7, y2 / 1.7 },
        { x2, y2 + up, z2, x2 / 1.7, (y2 + up) / 1.7 },
        { x1, y1 + up, z1, x1 / 1.7, (y1 + up) / 1.7 },
        { hole.x, y1, hole.z },
        0.85
      )
    end
  end
  for i = 0, 83 do
    local a = i / 84 * 2 * pi
    local x, z, inside = lip(a)
    x, z = x + (rng() - 0.5) * 0.3, z + (rng() - 0.5) * 0.3
    if inside then
      local size = 0.14 + rng() * 0.22
      B.chunk(
        edge.rubble,
        { x, hall.vaultHeight(x) - size * 0.2, z },
        { size * 1.5, size * 0.8, size },
        a + rng(),
        seed + i
      )
    end
  end
  local tear = def.tear
  if tear then
    local x = hall.x + tear.side * (hall.half + 0.1)
    for i = 0, 47 do
      local z = tear.z - tear.half + (i + 0.5) / 48 * tear.half * 2
      local y = Ruin.tearHeight(tear, z)
      if y < 10.5 then
        for k = 0, 1 do
          local size = 0.13 + rng() * 0.17
          B.chunk(
            edge.rubble,
            { x + (rng() - 0.5) * 0.3, y - k * 0.22, z },
            { size, size * 0.7, size * 1.5 },
            rng() * 0.5,
            seed * 3 + i * 5 + k
          )
        end
      end
    end
  end
  for i, heap in ipairs(def.heaps) do
    B.heap(after.rubble, after.ashlar, heap, seed + i)
  end
  B.drum(after.drum, def.cell[1] + 0.5, 0.25, def.cell[2] + 0.8, seed, 0.5, 1.5, 0.8)
end
local function sideWalls(sink, hall, surfaces, tears)
  local lists = sink:scope()
  for _, wall in ipairs(hall.walls) do
    local x = hall.x + wall.side * hall.half
    for _, s in ipairs(wall) do
      local name = surfaces[s.surface].image
      Relief.wall(lists[name], surfaces[s.surface], {
        x = x,
        z = s.z,
        ux = 0,
        uz = 1,
        nx = -wall.side,
        nz = 0,
        from = s.from,
        to = s.to,
        split = function(along, v)
          for _, def in ipairs(tears) do
            if def.tear.side == wall.side and v > Ruin.tearHeight(def.tear, along) then
              return sink:scope(def.id, 'gone')[name]
            end
          end
        end,
      })
    end
  end
end
-- An end wall across the hall, its opening centred on the axis.
local function endWall(lists, hall, spec, z, facing)
  local surface = Art.surfaces[spec.surface]
  Relief.wall(lists[surface.image], surface, {
    x = hall.x - hall.half,
    z = z,
    ux = 1,
    uz = 0,
    nx = 0,
    nz = facing,
    from = spec.from,
    to = spec.to,
  })
end
-- The ring of an opening, from the wall face back through its thickness.
local function reveal(list, hall, spec, z0, z1)
  local f = Art.surfaces[spec.surface].features[1]
  local rise = f.apex - f.spring
  local r = (f.half * f.half + rise * rise) / (2 * f.half)
  local function outline(side, t)
    if t < 0.4 then
      return hall.x + side * f.half, t / 0.4 * f.spring
    end
    local y = f.spring + rise * (t - 0.4) / 0.6
    return hall.x + side * (f.half - (r - sqrt(max(0, r * r - (y - f.spring) ^ 2)))), y
  end
  for _, side in ipairs({ -1, 1 }) do
    for i = 0, 29 do
      local a, b = i / 30, (i + 1) / 30
      local x1, y1 = outline(side, a)
      local x2, y2 = outline(side, b)
      B.quad(
        list,
        { x1, y1, z0, 0, y1 / 3.4 },
        { x2, y2, z0, 0, y2 / 3.4 },
        { x2, y2, z1, 0.33, y2 / 3.4 },
        { x1, y1, z1, 0.33, y1 / 3.4 },
        { hall.x, 3, (z0 + z1) / 2 },
        0.85
      )
    end
  end
end
local function vault(sink, hall, falls)
  local list = sink:scope().ashlar
  local half = hall.half
  local height = hall.vaultHeight
  -- Grid points beside a hole move onto its edge: the break is a line, not steps.
  local function point(x, z)
    for _, def in ipairs(falls) do
      local hole = def.hole
      local dx, dz = x - hole.x, z - hole.z
      local d = sqrt(dx * dx + dz * dz)
      if d > 0.01 then
        local edge = Ruin.holeEdge(hole, math.atan2(dz, dx))
        if abs(d - edge) < 0.3 then
          x, z = hole.x + dx / d * edge, hole.z + dz / d * edge
          break
        end
      end
    end
    return { x, height(x), z, x / 3.4, z / 3.4 }
  end
  for z2 = hall.chancel * 2, hall.south * 2 - 1 do
    local z = z2 / 2
    for i = 0, 59 do
      local a, b = hall.x - half + i * half / 30, hall.x - half + (i + 1) * half / 30
      local into = list
      for _, def in ipairs(falls) do
        if Ruin.inHole(def.hole, (a + b) / 2, z + 0.25) then
          into = sink:scope(def.id, 'gone').ashlar
          break
        end
      end
      B.quad(
        into,
        point(a, z),
        point(b, z),
        point(b, z + 0.5),
        point(a, z + 0.5),
        { hall.x, 3, z },
        0.62
      )
    end
  end
  if hall.southTop then
    for i = 0, 29 do
      local a, b = hall.x - half + i * half / 15, hall.x - half + (i + 1) * half / 15
      local y = hall.southTop
      B.quad(
        list,
        { a, y, hall.south, a / 3.4, y / 3.4 },
        { b, y, hall.south, b / 3.4, y / 3.4 },
        { b, height(b), hall.south, b / 3.4, height(b) / 3.4 },
        { a, height(a), hall.south, a / 3.4, height(a) / 3.4 },
        { hall.x, 3, 0 },
        0.7
      )
    end
  end
end
local function altar(w, lists, hall)
  local a = hall.altar
  local x0, x1, z0, z1 = a.x1 - 0.5, a.x2 + 0.5, a.z - 0.5, a.z + 0.5
  local base = Ground.cell(w, hall.x, a.z + 1)
  B.moulded(lists.ashlar, x0, z0, x1, z1, 0, {
    { 0, 0 },
    { 0, base + 0.14 },
    { 0.1, base + 0.2 },
    { 0.1, a.top - 0.2 },
    { -0.06, a.top - 0.12 },
    { -0.06, a.top },
  }, 0.86)
  tombFace(
    lists.tomb,
    { x0 + 0.2, z1 - 0.08 },
    { x1 - 0.2, z1 - 0.08 },
    base + 0.22,
    a.top - 0.22,
    FRONT,
    { hall.x, 1, 99 }
  )
  for _, seal in ipairs(w.seals) do
    if abs(seal.x - hall.x) < 3 and seal.z < hall.chancel then
      local h = Ground.cell(w, math.floor(seal.x + 0.5), math.floor(seal.z + 0.5))
      local profile = {}
      for i, p in ipairs(PEDESTAL) do
        profile[i] = { p[1], p[2] + h }
      end
      B.lathe(lists.drum, seal.x, seal.z, profile, 18, 1, 0.8)
    end
  end
  for _, post in ipairs(hall.posts) do
    local profile = {}
    for i, p in ipairs(TABLE) do
      profile[i] = { p[1], p[2] / 1.18 * post.height }
    end
    B.moulded(
      lists.ashlar,
      post.x - 0.5,
      post.z - 0.5,
      post.x + 0.5,
      post.z + 0.5,
      0,
      profile,
      0.86
    )
  end
end
function Chapel.build(w, hall)
  local blockers = {}
  for _, p in ipairs(hall.piers) do
    blockers[#blockers + 1] = { x = p.x, z = p.z, r = 0.62 }
  end
  for _, s in ipairs(hall.sarcophagi or {}) do
    blockers[#blockers + 1] = { x = s.x, z = (s.z1 + s.z2) / 2, r = 1.25 }
  end
  for _, h in ipairs(hall.heaps or {}) do
    blockers[#blockers + 1] = { x = h.x, z = h.z, r = h.radius * 0.8 }
  end
  local light = Light.new(hall.light or Art.light, hall.x, hall.rear or hall.chancel, blockers)
  local sink = B.sink(light)
  local lists = sink:scope()
  local falls, tears, byCell = {}, {}, {}
  for _, def in ipairs(hall.breakables) do
    if Kinds[def.kind].collapses then
      falls[#falls + 1] = def
      byCell[def.cell[2] * 100 + def.cell[1]] = def
      if def.tear then
        tears[#tears + 1] = def
      end
    end
  end
  sideWalls(sink, hall, Art.surfaces, tears)
  endWall(lists, hall, hall.chancelWall, hall.chancel, 1)
  if hall.chancelWall.back then
    endWall(lists, hall, hall.chancelWall, hall.chancel - 0.6, -1)
  end
  reveal(lists.ashlar, hall, hall.chancelWall, hall.chancel, hall.chancel - 0.6)
  endWall(lists, hall, hall.southWall, hall.south, -1)
  if Art.surfaces[hall.southWall.surface].features[1].kind == 'opening' then
    reveal(lists.ashlar, hall, hall.southWall, hall.south, hall.south + 0.3)
  end
  if hall.rearWall then
    local surface = Art.surfaces[hall.rearWall]
    Relief.wall(
      lists[surface.image],
      surface,
      { x = hall.x - 5.25, z = hall.rear, ux = 1, uz = 0, nx = 0, nz = 1 }
    )
    for _, side in ipairs({ -1, 1 }) do
      Relief.wall(lists.apse_side, Art.surfaces.apse_side, {
        x = hall.x + side * hall.apse,
        z = hall.rear,
        ux = 0,
        uz = 1,
        nx = -side,
        nz = 0,
        from = 0,
        to = hall.chancel - 0.6 - hall.rear,
        shade = 0.62,
      })
    end
  end
  vault(sink, hall, falls)
  for _, rect in ipairs(hall.footprint) do
    for z = rect[2], rect[4] do
      for x = rect[1], rect[3] do
        if not Tiles.masonry[w.map[z][x]] then
          floorCell(w, hall, lists.floor, lists.ashlar, x, z)
        end
      end
    end
  end
  for i, p in ipairs(hall.piers) do
    local def = byCell[p.z * 100 + p.x]
    pier(sink, hall, p, def, i * 1.7 + hall.x)
    if def then
      ruinOf(sink, hall, def, i * 97 + hall.x * 13)
    end
  end
  for _, s in ipairs(hall.sarcophagi or {}) do
    sarcophagus(lists, s, hall.x)
  end
  if hall.altar then
    altar(w, lists, hall)
  end
  for _, p in ipairs(hall.pedestals or {}) do
    B.moulded(lists.ashlar, p.x - 0.5, p.z - 0.5, p.x + 0.5, p.z + 0.5, 0, {
      { 0, 0 },
      { 0, 0.12 },
      { 0.1, 0.16 },
      { 0.1, p.height - 0.14 },
      { 0, p.height - 0.08 },
      { 0, p.height },
    }, 0.86)
  end
  local banners = 0
  for _, def in ipairs(hall.breakables) do
    if def.kind == 'banner' then
      banners = banners + 1
      local image = banners % 2 == 1 and 'banner_a' or 'banner_b'
      banner(sink:scope(def.id, 'fall')[image], def, Art.banner)
      fallenBanner(sink:scope(def.id, 'after')[image], def, Art.banner)
    elseif def.kind == 'chain' then
      local top, length = def.from, def.length
      B.chain(
        sink:scope(def.id, 'whole', { sway = { top[2], length } }).iron,
        def.from,
        def.to,
        def.sag,
        def.links,
        0.8
      )
      B.chain(
        sink:scope(def.id, 'hanging', { sway = { top[2], length } }).iron,
        def.from,
        { top[1], top[2] - 2.6, top[3] },
        0,
        7,
        0.8
      )
      B.chain(
        sink:scope(def.id, 'after').iron,
        { def.to[1], 0.2, def.to[3] + 0.5 },
        { def.to[1] + 1.2, 0.08, def.to[3] + 0.9 },
        -0.02,
        9,
        0.8
      )
    else
      Props.add(sink, w, def)
    end
  end
  for _, h in ipairs(hall.heaps or {}) do
    B.heap(lists.rubble, lists.ashlar, h)
  end
  for _, d in ipairs(hall.drums or {}) do
    B.drum(lists.drum, d.x, d.y or 0, d.z, d.yaw, d.radius, d.length, 0.82)
  end
  local unlit = sink:scope(nil, 'unlit')
  unlit.far_ruins.light = false
  for _, f in ipairs(hall.backdrops or {}) do
    B.quad(
      unlit.far_ruins,
      { f[1], f.bottom, f[2], 0, 1 },
      { f[3], f.bottom, f[4], 1, 1 },
      { f[3], f.top, f[4], 1, 0 },
      { f[1], f.top, f[2], 0, 0 },
      { hall.x, 3, 20 }
    )
  end
  return sink:parts(Art)
end
return Chapel
