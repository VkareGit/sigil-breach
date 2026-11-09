-- A chapel hall from its map record (content/maps/proving_halls.lua) and its
-- painted surfaces (content/art/chapel_hall.lua). Floors, steps and solid
-- furniture follow the map's heights, so what is drawn is what is walked on.
local Tiles = require('src.core.tiles')
local ChapelHall = require('src.content.art.chapel_hall')
local Builder = require('src.render.kit.builder')
local Relief = require('src.render.kit.relief')
local Light = require('src.render.kit.light')
local Props = require('src.render.kit.props')
local Ground = require('src.physics.ground')
local Ruin = require('src.content.maps.breakables')
local Breakables = require('src.content.breakables')
local Forms = require('src.content.art.chapel_forms')
local Chapel = {}
-- A cell as one number, whatever the width of the map.
local function cellKey(x, z)
  return z * 65536 + x -- constant: a map is narrower than 65536 cells
end
local abs, cos, sin, sqrt, max, pi = math.abs, math.cos, math.sin, math.sqrt, math.max, math.pi
local function floorCell(w, hall, list, risers, x, z)
  local h = Ground.cell(w, x, z)
  local height = h < hall.solidFrom and h or 0
  local cx = hall.x
  for i = 0, 1 do
    for j = 0, 1 do
      local x0, z0 = x - 0.5 + i * 0.5, z - 0.5 + j * 0.5
      local x1, z1 = x0 + 0.5, z0 + 0.5
      local function p(a, c)
        return { a, height, c, (a - cx) / Forms.floorSpan + 0.5, c / Forms.floorSpan }
      end
      Builder.quad(list, p(x0, z0), p(x1, z0), p(x1, z1), p(x0, z1), { x0, height + Forms.aim, z0 })
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
          (px + tz * side + pz + tx * side) / Forms.stoneSpan,
          y / Forms.stoneSpan,
        }
      end
      Builder.quad(
        risers,
        p(-1, other),
        p(1, other),
        p(1, height),
        p(-1, height),
        { px + d[1] * Forms.aim, height / 2, pz + d[2] * Forms.aim },
        Forms.floor.riserShade
      )
    end
  end
end
local function tombFace(list, a, b, height0, height1, rect, front)
  Builder.quad(
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
  local T, SLAB = Forms.sarcophagus, Forms.tombSlab
  Builder.moulded(lists.ashlar, x0, z0, x1, z1, 0, T.profile, T.shade)
  local face = s.x < axis and x1 - T.inset or x0 + T.inset
  local toward = { axis, 1, (z0 + z1) / 2 }
  tombFace(
    lists.tomb,
    { face, z0 + T.margin },
    { face, z1 - T.margin },
    T.bottom,
    T.top,
    Forms.tombFront,
    toward
  )
  tombFace(
    lists.tomb,
    { x0 + T.margin, z1 - T.inset },
    { x1 - T.margin, z1 - T.inset },
    T.bottom,
    T.top,
    Forms.tombFigure,
    { s.x, 1, Forms.farAim }
  )
  tombFace(
    lists.tomb,
    { x0 + T.margin, z0 + T.inset },
    { x1 - T.margin, z0 + T.inset },
    T.bottom,
    T.top,
    Forms.tombFigure,
    { s.x, 1, -Forms.farAim }
  )
  Builder.quad(
    lists.tomb,
    { x0, T.lid, z0, SLAB[1], SLAB[2] },
    { x1, T.lid, z0, SLAB[1], SLAB[4] },
    { x1, T.lid, z1, SLAB[3], SLAB[4] },
    { x0, T.lid, z1, SLAB[3], SLAB[2] },
    { s.x, Forms.aim, s.z1 }
  )
end
local function banner(list, def, cloth)
  local x, z, top = def.from[1], def.from[3], def.to[2]
  local B = Forms.banner
  local function wob(t)
    return sin(t * B.wave + x) * B.wobble
  end
  for i = 0, B.columns - 1 do
    local a, b = i / B.columns, (i + 1) / B.columns
    for j = 0, B.rows - 1 do
      local c, d = j / B.rows, (j + 1) / B.rows
      local y1, y2 = top - c * cloth.height, top - d * cloth.height
      local xa, xb = x + (a - 0.5) * cloth.width, x + (b - 0.5) * cloth.width
      Builder.quad(
        list,
        { xa, y1, z + wob(a), a, c },
        { xb, y1, z + wob(b), b, c },
        { xb, y2, z + wob(b), b, d },
        { xa, y2, z + wob(a), a, d },
        { x, y1, z + Forms.aim }
      )
    end
  end
end
-- The cloth where it fell, in loose folds.
local function fallenBanner(list, def, cloth)
  local L = Forms.fallenBanner
  local x, z = def.from[1], def.from[3] + L.reach
  local function fold(a, b)
    return L.lift + L.ruck * (sin(a * L.waveAcross + x) + sin(b * L.waveAlong - x))
  end
  for i = 0, L.columns - 1 do
    local a, b = i / L.columns, (i + 1) / L.columns
    for j = 0, L.rows - 1 do
      local c, d = j / L.rows, (j + 1) / L.rows
      local xa, xb = x + (a - 0.5) * cloth.width * L.narrow, x + (b - 0.5) * cloth.width * L.narrow
      local za, zb = z + c * cloth.height * L.spread, z + d * cloth.height * L.spread
      Builder.quad(
        list,
        { xa, fold(a, c), za + sin(c * L.ripple) * L.drift, a, c },
        { xb, fold(b, c), za + sin(c * L.ripple) * L.drift, b, c },
        { xb, fold(b, d), zb + sin(d * L.ripple) * L.drift, b, d },
        { xa, fold(a, d), zb + sin(d * L.ripple) * L.drift, a, d },
        { x, Forms.aim, z }
      )
    end
  end
end
local function ribs(list, hall, p)
  local R = Forms.ribs
  local x, z, inward = p.x, p.z, p.x < hall.x and 1 or -1
  local wall = hall.x - inward * (hall.half - R.inset)
  local apex, spring = hall.vaultHeight(hall.x) - R.drop, R.spring
  Builder.rib(
    list,
    Builder.arc(x + inward * R.foot, spring, z, hall.x, apex, z, R.segments),
    R.width,
    R.depth,
    R.shade
  )
  if abs(x - wall) > 1 then
    Builder.rib(
      list,
      Builder.arc(x - inward * R.foot, spring, z, wall, R.wallTop, z, R.wallSegments),
      R.width,
      R.depth,
      R.shade
    )
  end
  for _, s in ipairs({ { 1, hall.piers[#hall.piers].z }, { -1, hall.piers[1].z } }) do
    if z ~= s[2] then
      Builder.rib(
        list,
        Builder.arc(
          x + inward * R.crossFoot,
          spring,
          z + s[1] * R.crossFoot,
          hall.x,
          apex + R.crossRise,
          z + s[1] * R.crossReach,
          R.segments
        ),
        R.crossWidth,
        R.crossDepth,
        R.crossShade
      )
    end
  end
end
-- A pier that stands to the end, or one that can fall: whole, wounded, stump.
local function pier(sink, hall, p, def, seed)
  local x, z = p.x, p.z
  local P = Forms.pier
  local PIER = P.profile
  local lists = sink:scope()
  if not def then
    Builder.lathe(lists.drum, x, z, PIER, P.sides, P.wraps, P.shade)
    ribs(lists.drum, hall, p)
    return
  end
  local id = def.id
  Builder.lathe(sink:scope(id, 'whole').drum, x, z, PIER, P.sides, P.wraps, P.shade)
  local C = P.bite
  local function bite(angle, y)
    local d = sin(angle * C.round + seed) * sin(y * C.up + seed * 2)
      + sin(angle * C.roundFine - seed) * sin(y * C.upFine)
    return max(0, d - C.from) * C.depth
  end
  Builder.lathe(sink:scope(id, 'cracked').drum, x, z, PIER, P.sides, P.wraps, P.crackedShade, bite)
  ribs(sink:scope(id, 'gone').drum, hall, p)
  local after = sink:scope(id, 'after', { rise = P.stumpRise })
  Builder.lathe(after.drum, x, z, P.stump, P.sides, P.wraps, P.crackedShade, function(angle, y)
    return y > P.stumpTop and max(0, sin(angle * P.stumpLobes + seed)) * P.stumpBite or 0
  end)
end
-- What is left at the edge of a fall: stepped broken courses along the tear
-- and round the hole, then the heap of what came down.
local function ruinOf(sink, hall, def, seed)
  local hole = def.hole
  local U = Forms.ruin
  local G = U.glow
  local glow = Light.new({
    ambient = ChapelHall.light.ambient,
    tone = ChapelHall.light.tone,
    sources = {
      { hole.x, G.height, hole.z, G.r, G.g, G.b, G.power, G.reach },
      ChapelHall.light.sources[1],
    },
  }, 0, 0, {})
  local after = sink:scope(def.id, 'after', { rise = U.rise, light = glow })
  local edge = sink:scope(def.id .. '|edge', 'after', { light = glow })
  local rng = Builder.random(seed)
  -- The thickness of the broken vault, then loose stones hanging at its lip.
  local function lip(a)
    local r = Ruin.holeEdge(hole, a)
    local x, z = hole.x + cos(a) * r, hole.z + sin(a) * r
    return x, z, abs(x - hall.x) < hall.half and z > hall.chancel and z < hall.south
  end
  local facets = U.facets
  for i = 0, facets - 1 do
    local a, b = i / facets * 2 * pi, (i + 1) / facets * 2 * pi
    local x1, z1, in1 = lip(a)
    local x2, z2, in2 = lip(b)
    if in1 and in2 then
      local y1, y2 = hall.vaultHeight(x1), hall.vaultHeight(x2)
      local up = U.lipHeight + U.lipVary * sin(i * U.lipWave + seed)
      local span = Forms.rubbleSpan
      Builder.quad(
        edge.rubble,
        { x1, y1 - U.lipDrop, z1, x1 / span, y1 / span },
        { x2, y2 - U.lipDrop, z2, x2 / span, y2 / span },
        { x2, y2 + up, z2, x2 / span, (y2 + up) / span },
        { x1, y1 + up, z1, x1 / span, (y1 + up) / span },
        { hole.x, y1, hole.z },
        U.edgeShade
      )
    end
  end
  for i = 0, U.stones - 1 do
    local a = i / U.stones * 2 * pi
    local x, z, inside = lip(a)
    x, z = x + (rng() - 0.5) * U.jitter, z + (rng() - 0.5) * U.jitter
    if inside then
      local size = U.stoneSize + rng() * U.stoneVary
      Builder.chunk(
        edge.rubble,
        { x, hall.vaultHeight(x) - size * U.stoneSink, z },
        { size * U.stoneLong, size * U.stoneHigh, size },
        a + rng(),
        seed + i
      )
    end
  end
  local tear = def.tear
  if tear then
    local x = hall.x + tear.side * (hall.half + U.tearInset)
    for i = 0, U.tearStones - 1 do
      local z = tear.z - tear.half + (i + 0.5) / U.tearStones * tear.half * 2
      local y = Ruin.tearHeight(tear, z)
      if y < U.tearTop then
        for k = 0, 1 do
          local size = U.tearSize + rng() * U.tearVary
          Builder.chunk(
            edge.rubble,
            { x + (rng() - 0.5) * U.jitter, y - k * U.course, z },
            { size, size * U.tearHigh, size * U.tearLong },
            rng() * 0.5,
            seed * 3 + i * 5 + k
          )
        end
      end
    end
  end
  for i, heap in ipairs(def.heaps) do
    Builder.heap(after.rubble, after.ashlar, heap, seed + i)
  end
  local D = U.drum
  Builder.drum(
    after.drum,
    def.cell[1] + 0.5,
    D.lift,
    def.cell[2] + D.back,
    seed,
    D.radius,
    D.length,
    D.shade
  )
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
  local surface = ChapelHall.surfaces[spec.surface]
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
  local f = ChapelHall.surfaces[spec.surface].features[1]
  local rise = f.apex - f.spring
  local r = (f.half * f.half + rise * rise) / (2 * f.half)
  local V = Forms.reveal
  local function outline(side, t)
    if t < V.jamb then
      return hall.x + side * f.half, t / V.jamb * f.spring
    end
    local y = f.spring + rise * (t - V.jamb) / V.arch
    return hall.x + side * (f.half - (r - sqrt(max(0, r * r - (y - f.spring) ^ 2)))), y
  end
  for _, side in ipairs({ -1, 1 }) do
    for i = 0, V.steps - 1 do
      local a, b = i / V.steps, (i + 1) / V.steps
      local x1, y1 = outline(side, a)
      local x2, y2 = outline(side, b)
      local span = Forms.stoneSpan
      Builder.quad(
        list,
        { x1, y1, z0, 0, y1 / span },
        { x2, y2, z0, 0, y2 / span },
        { x2, y2, z1, V.depth, y2 / span },
        { x1, y1, z1, V.depth, y1 / span },
        { hall.x, Forms.aimHeight, (z0 + z1) / 2 },
        V.shade
      )
    end
  end
end
local function vault(sink, hall, falls)
  local list = sink:scope().ashlar
  local half = hall.half
  local height = hall.vaultHeight
  local V, span, aim = Forms.vault, Forms.stoneSpan, Forms.aimHeight
  -- Grid points beside a hole move onto its edge: the break is a line, not steps.
  local function point(x, z)
    for _, def in ipairs(falls) do
      local hole = def.hole
      local dx, dz = x - hole.x, z - hole.z
      local d = sqrt(dx * dx + dz * dz)
      if d > 1e-2 then
        local edge = Ruin.holeEdge(hole, math.atan2(dz, dx))
        if abs(d - edge) < V.snap then
          x, z = hole.x + dx / d * edge, hole.z + dz / d * edge
          break
        end
      end
    end
    return { x, height(x), z, x / span, z / span }
  end
  for z2 = hall.chancel * 2, hall.south * 2 - 1 do
    local z = z2 / 2
    for i = 0, 2 * V.cells - 1 do
      local a, b = hall.x - half + i * half / V.cells, hall.x - half + (i + 1) * half / V.cells
      local into = list
      for _, def in ipairs(falls) do
        if Ruin.inHole(def.hole, (a + b) / 2, z + V.rowMiddle) then
          into = sink:scope(def.id, 'gone').ashlar
          break
        end
      end
      Builder.quad(
        into,
        point(a, z),
        point(b, z),
        point(b, z + 0.5),
        point(a, z + 0.5),
        { hall.x, aim, z },
        V.shade
      )
    end
  end
  if hall.southTop then
    for i = 0, 2 * V.southCells - 1 do
      local a, b =
        hall.x - half + i * half / V.southCells, hall.x - half + (i + 1) * half / V.southCells
      local y = hall.southTop
      Builder.quad(
        list,
        { a, y, hall.south, a / span, y / span },
        { b, y, hall.south, b / span, y / span },
        { b, height(b), hall.south, b / span, height(b) / span },
        { a, height(a), hall.south, a / span, height(a) / span },
        { hall.x, aim, 0 },
        V.southShade
      )
    end
  end
end
local function altar(w, lists, hall)
  local a = hall.altar
  local x0, x1, z0, z1 = a.x1 - 0.5, a.x2 + 0.5, a.z - 0.5, a.z + 0.5
  local base = Ground.cell(w, hall.x, a.z + 1)
  local A = Forms.altar
  Builder.moulded(lists.ashlar, x0, z0, x1, z1, 0, {
    { 0, 0 },
    { 0, base + A.plinth },
    { A.inset, base + A.waist },
    { A.inset, a.top - A.waist },
    { -A.overhang, a.top - A.lip },
    { -A.overhang, a.top },
  }, A.shade)
  tombFace(
    lists.tomb,
    { x0 + A.faceMargin, z1 - A.faceInset },
    { x1 - A.faceMargin, z1 - A.faceInset },
    base + A.faceGap,
    a.top - A.faceGap,
    Forms.tombFront,
    { hall.x, 1, Forms.farAim }
  )
  for _, seal in ipairs(w.seals) do
    if abs(seal.x - hall.x) < 3 and seal.z < hall.chancel then
      local h = Ground.cell(w, math.floor(seal.x + 0.5), math.floor(seal.z + 0.5))
      local profile = {}
      for i, p in ipairs(Forms.pedestal.profile) do
        profile[i] = { p[1], p[2] + h }
      end
      Builder.lathe(
        lists.drum,
        seal.x,
        seal.z,
        profile,
        Forms.pedestal.sides,
        1,
        Forms.pedestal.shade
      )
    end
  end
  for _, post in ipairs(hall.posts) do
    local profile = {}
    for i, p in ipairs(Forms.table.profile) do
      profile[i] = { p[1], p[2] / Forms.table.height * post.height }
    end
    Builder.moulded(
      lists.ashlar,
      post.x - 0.5,
      post.z - 0.5,
      post.x + 0.5,
      post.z + 0.5,
      0,
      profile,
      Forms.table.shade
    )
  end
end
function Chapel.build(w, hall)
  local blockers = {}
  for _, p in ipairs(hall.piers) do
    blockers[#blockers + 1] = { x = p.x, z = p.z, r = Forms.pier.blocks }
  end
  for _, s in ipairs(hall.sarcophagi or {}) do
    blockers[#blockers + 1] = { x = s.x, z = (s.z1 + s.z2) / 2, r = Forms.sarcophagus.blocks }
  end
  for _, h in ipairs(hall.heaps or {}) do
    blockers[#blockers + 1] = { x = h.x, z = h.z, r = h.radius * Forms.heap.blocks }
  end
  local light =
    Light.new(hall.light or ChapelHall.light, hall.x, hall.rear or hall.chancel, blockers)
  local sink = Builder.sink(light)
  local lists = sink:scope()
  local falls, tears, byCell = {}, {}, {}
  for _, def in ipairs(hall.breakables) do
    if Breakables[def.kind].collapses then
      falls[#falls + 1] = def
      byCell[cellKey(def.cell[1], def.cell[2])] = def
      if def.tear then
        tears[#tears + 1] = def
      end
    end
  end
  local walls = Forms.walls
  sideWalls(sink, hall, ChapelHall.surfaces, tears)
  endWall(lists, hall, hall.chancelWall, hall.chancel, 1)
  if hall.chancelWall.back then
    endWall(lists, hall, hall.chancelWall, hall.chancel - walls.thickness, -1)
  end
  reveal(lists.ashlar, hall, hall.chancelWall, hall.chancel, hall.chancel - walls.thickness)
  endWall(lists, hall, hall.southWall, hall.south, -1)
  if ChapelHall.surfaces[hall.southWall.surface].features[1].kind == 'opening' then
    reveal(lists.ashlar, hall, hall.southWall, hall.south, hall.south + walls.southReveal)
  end
  if hall.rearWall then
    local surface = ChapelHall.surfaces[hall.rearWall]
    Relief.wall(
      lists[surface.image],
      surface,
      { x = hall.x - walls.rearHalf, z = hall.rear, ux = 1, uz = 0, nx = 0, nz = 1 }
    )
    for _, side in ipairs({ -1, 1 }) do
      Relief.wall(lists.apse_side, ChapelHall.surfaces.apse_side, {
        x = hall.x + side * hall.apse,
        z = hall.rear,
        ux = 0,
        uz = 1,
        nx = -side,
        nz = 0,
        from = 0,
        to = hall.chancel - walls.thickness - hall.rear,
        shade = walls.apseShade,
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
    local def = byCell[cellKey(p.x, p.z)]
    pier(sink, hall, p, def, i * Forms.seeds.pier + hall.x)
    if def then
      ruinOf(sink, hall, def, i * Forms.seeds.ruin + hall.x * Forms.seeds.ruinAxis)
    end
  end
  for _, s in ipairs(hall.sarcophagi or {}) do
    sarcophagus(lists, s, hall.x)
  end
  if hall.altar then
    altar(w, lists, hall)
  end
  local plinth = Forms.plinth
  for _, p in ipairs(hall.pedestals or {}) do
    Builder.moulded(lists.ashlar, p.x - 0.5, p.z - 0.5, p.x + 0.5, p.z + 0.5, 0, {
      { 0, 0 },
      { 0, plinth.foot },
      { plinth.inset, plinth.waist },
      { plinth.inset, p.height - plinth.neck },
      { 0, p.height - plinth.lip },
      { 0, p.height },
    }, plinth.shade)
  end
  local banners = 0
  for _, def in ipairs(hall.breakables) do
    if def.kind == 'banner' then
      banners = banners + 1
      local image = banners % 2 == 1 and 'banner_a' or 'banner_b'
      banner(sink:scope(def.id, 'fall')[image], def, ChapelHall.banner)
      fallenBanner(sink:scope(def.id, 'after')[image], def, ChapelHall.banner)
    elseif def.kind == 'chain' then
      local top, length = def.from, def.length
      local C = Forms.chain
      Builder.chain(
        sink:scope(def.id, 'whole', { sway = { top[2], length } }).iron,
        def.from,
        def.to,
        def.sag,
        def.links,
        C.shade
      )
      Builder.chain(
        sink:scope(def.id, 'hanging', { sway = { top[2], length } }).iron,
        def.from,
        { top[1], top[2] - C.hang, top[3] },
        0,
        C.hangLinks,
        C.shade
      )
      local F = C.fallen
      Builder.chain(
        sink:scope(def.id, 'after').iron,
        { def.to[1], F.lift, def.to[3] + F.out },
        { def.to[1] + F.along, F.rest, def.to[3] + F.reach },
        F.sag,
        F.links,
        C.shade
      )
    else
      Props.add(sink, w, def)
    end
  end
  for _, h in ipairs(hall.heaps or {}) do
    Builder.heap(lists.rubble, lists.ashlar, h)
  end
  for _, d in ipairs(hall.drums or {}) do
    Builder.drum(lists.drum, d.x, d.y or 0, d.z, d.yaw, d.radius, d.length, Forms.drumShade)
  end
  local unlit = sink:scope(nil, 'unlit')
  unlit.far_ruins.light = false
  for _, f in ipairs(hall.backdrops or {}) do
    Builder.quad(
      unlit.far_ruins,
      { f[1], f.bottom, f[2], 0, 1 },
      { f[3], f.bottom, f[4], 1, 1 },
      { f[3], f.top, f[4], 1, 0 },
      { f[1], f.top, f[2], 0, 0 },
      { hall.x, Forms.aimHeight, Forms.backdropAim }
    )
  end
  return sink:parts(ChapelHall)
end
return Chapel
