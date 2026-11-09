-- Presentation resource: built on first draw, reused until the world revision changes.
-- World creation and collision tests never allocate a GPU mesh.
local Tiles = require('src.core.tiles')
local Mesh = require('src.render.mesh')
local Collision = require('src.physics.collision')
local Ground = require('src.physics.ground')
local Grid = require('src.physics.grid')
local RoofCell = require('src.physics.roof_cell')
local Halls = require('src.render.kit.halls')
local GridLook = require('src.content.art.grid_look')
local Geometry = {}
-- The weak map names worlds but owns no native resources. A live simulation
-- world must not keep a mesh alive after its last renderer has closed.
local identities, serial = setmetatable({}, { __mode = 'k' }), 0
local colors = GridLook.colors
local stone, dark, trim, glow = colors.stone, colors.dark, colors.trim, colors.glow
local function roofCell(v, w, x, z, deck)
  local p, top = RoofCell.corners(deck, x, z), deck[2]
  if deck[3][5] then
    local middle = { x, deck[3][5], z }
    for i = 1, 4 do
      Mesh.tri(v, p[i], p[i % 4 + 1], middle, stone)
    end
  else
    Mesh.tri(v, p[1], p[2], p[3], stone)
    Mesh.tri(v, p[1], p[3], p[4], stone)
  end
  -- A hall open to the sky sees over the walls: the outer shell of the other
  -- roofs must not rise behind it. Steps between vaults stay.
  local shell = not (w.decor and w.decor.halls)
  if shell then
    Mesh.quad(
      v,
      { x - 0.5, top, z - 0.5 },
      { x - 0.5, top, z + 0.5 },
      { x + 0.5, top, z + 0.5 },
      { x + 0.5, top, z - 0.5 },
      stone
    )
  end
  for i, d in ipairs({ { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }) do
    local j = i % 4 + 1
    local shared = false
    local highA, highB = top, top
    local beside = Ground.decks(w, x + d[1], z + d[2])
    for _, other in ipairs(beside or {}) do
      local h = other[3]
      if h and other[2] == top then
        -- Opposite edge, reversed orientation, at the exact shared vertices.
        local a, b = (i + 2) % 4 + 1, (i + 1) % 4 + 1
        highA, highB = math.min(highA, h[a]), math.min(highB, h[b])
        shared = shared or (highA <= p[i][2] + 1e-8 and highB <= p[j][2] + 1e-8)
      end
    end
    if not shared and (shell or beside) then
      local a, b = p[i], p[j]
      local da, db = highA - a[2], highB - b[2]
      -- If the exposed step crosses this edge, clip at the crossing instead
      -- of drawing a folded quad over the neighbouring solid.
      if da * db < 0 then
        local t = da / (da - db)
        local middle =
          { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
        if da < 0 then
          a, highA = middle, middle[2]
        else
          b, highB = middle, middle[2]
        end
      end
      Mesh.quad(v, a, { a[1], highA, a[3] }, { b[1], highB, b[3] }, b, stone)
    end
  end
end
local function muralWall(decor, x, z)
  for _, area in ipairs(decor.muralWalls or {}) do
    if x >= area[1] and x <= area[3] and z >= area[2] and z <= area[4] then
      return true
    end
  end
  return false
end
-- The wall face a walkable cell shows toward its solid neighbour.
local function wallFace(v, w, decor, raise, x, z, nx, nz, d)
  local tile = w.map[nz] and w.map[nz][nx]
  -- A round shaft must not be hidden behind the adjacent wall faces.
  -- Older maps retain their authored boxed-pier appearance.
  if tile and Tiles.solid[tile] and not (Tiles.round[tile] and decor.pillarStyle == 'shaft') then
    local first = #v + 1
    local h = Collision.top(w.map[nz][nx])
    local F = GridLook.wall
    local px, pz = x + d[1] * F.out, z + d[2] * F.out
    local bw, bd = d[1] == 0 and 1 or F.thickness, d[2] == 0 and 1 or F.thickness
    Mesh.box(v, px, 0, pz, bw, F.base, bd, trim)
    Mesh.box(v, px, F.bodyFoot, pz, bw, h - F.body, bd, stone)
    Mesh.box(v, px, h - F.cornice, pz, bw, F.cornice, bd, trim)
    -- Leave continuous lime behind the three narrative wall paintings:
    -- a black niche stripe through a fresco reads as a pasted decal.
    if decor.niches ~= false and (x + z) % 3 == 0 and not muralWall(decor, x, z) then
      local N, S = GridLook.niche, GridLook.stripe
      Mesh.box(
        v,
        px - d[1] * N.inset,
        N.bottom,
        pz - d[2] * N.inset,
        bw * N.scale,
        N.height,
        bd * N.scale,
        dark
      )
      Mesh.box(
        v,
        px - d[1] * S.inset,
        S.bottom,
        pz - d[2] * S.inset,
        d[1] == 0 and S.wide or S.thin,
        S.height,
        d[2] == 0 and S.wide or S.thin,
        colors.nicheStripe
      )
    end
    raise(first, nx, nz)
  end
end
local function floorCell(v, w, decor, raise, x, z)
  local elevation = Ground.cell(w, x, z)
  Mesh.quad(
    v,
    { x - 0.5, elevation, z - 0.5 },
    { x - 0.5, elevation, z + 0.5 },
    { x + 0.5, elevation, z + 0.5 },
    { x + 0.5, elevation, z - 0.5 },
    colors.floor
  )
  -- Every exposed face has a high base, a dark panel, and brass cornice.
  for _, d in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
    local nx, nz = x + d[1], z + d[2]
    local adjacent = Ground.cell(w, nx, nz)
    if w.map[nz] and Tiles.walkable[w.map[nz][nx]] and elevation > adjacent then
      -- The riser is the same cell boundary queried by collision/rays.
      local px, pz = x + d[1] * 0.5, z + d[2] * 0.5
      local tx, tz = d[2] * 0.5, -d[1] * 0.5
      Mesh.quad(
        v,
        { px - tx, adjacent, pz - tz },
        { px - tx, elevation, pz - tz },
        { px + tx, elevation, pz + tz },
        { px + tx, adjacent, pz + tz },
        stone
      )
    end
    wallFace(v, w, decor, raise, x, z, nx, nz, d)
  end
end
local function roundShaft(v, w, raise, x, z)
  local elevation = Ground.cell(w, x, z)
  if elevation > 0 then
    Mesh.box(v, x, 0, z, 1, elevation, 1, stone)
  end
  local first = #v + 1
  local S = GridLook.shaft
  local drum, capital, abacus = S.drum, S.capital, S.abacus
  Mesh.box(v, x, 0, z, S.plinth, S.plinthHeight, S.plinth, trim)
  Mesh.cone(v, x, S.plinthHeight, z, drum.foot, drum.head, drum.height, stone, S.sides)
  Mesh.cone(v, x, capital.at, z, capital.foot, capital.head, capital.height, trim, S.sides)
  Mesh.cone(v, x, abacus.at, z, abacus.foot, abacus.head, abacus.height, stone, S.sides)
  raise(first, x, z)
end
-- A slab's top, underside and the edges no neighbouring cell of the same deck hides.
local function deckCell(v, w, decor, x, z, deck)
  if deck[3] then
    roofCell(v, w, x, z, deck)
  else
    local bottom, top = deck[1], deck[2]
    Mesh.quad(
      v,
      { x - 0.5, top, z - 0.5 },
      { x - 0.5, top, z + 0.5 },
      { x + 0.5, top, z + 0.5 },
      { x + 0.5, top, z - 0.5 },
      colors.floor
    )
    Mesh.quad(
      v,
      { x - 0.5, bottom, z + 0.5 },
      { x - 0.5, bottom, z - 0.5 },
      { x + 0.5, bottom, z - 0.5 },
      { x + 0.5, bottom, z + 0.5 },
      dark
    )
    for _, d in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
      local shared = false
      for _, other in ipairs(Ground.decks(w, x + d[1], z + d[2]) or {}) do
        shared = shared or other == deck
      end
      if not shared then
        local px, pz = x + d[1] * 0.5, z + d[2] * 0.5
        local tx, tz = d[2] * 0.5, -d[1] * 0.5
        Mesh.quad(
          v,
          { px - tx, bottom, pz - tz },
          { px - tx, top, pz - tz },
          { px + tx, top, pz + tz },
          { px + tx, bottom, pz + tz },
          decor.stonePaint and stone or trim
        )
      end
    end
  end
end
-- Ribs spring from map-authored walls/pillars. Yaw also allows longitudinal
-- arcades and chapel entrances without a separate church renderer.
local function ribArch(v, arch, raise)
  local first = #v + 1
  local function point(angle, side)
    local dx = side * arch.halfSpan * math.cos(angle)
    local x, z = arch.x + dx, arch.z
    if arch.yaw then
      x, z = arch.x + dx * math.cos(arch.yaw), arch.z + dx * math.sin(arch.yaw)
    end
    return { x, arch.spring + arch.rise * math.sin(angle), z }
  end
  for side = -1, 1, 2 do
    local n = GridLook.arch.segments
    for i = 0, n - 1 do
      local a = i / n * math.pi / 2
      local b = (i + 1) / n * math.pi / 2
      Mesh.beam(v, point(a, side), point(b, side), arch.radius or GridLook.arch.radius, stone)
    end
  end
  raise(first, arch.x, arch.z, arch.y)
end
-- Main ritual inlay, lines and nine circles.
local function ritualInlay(v, ritual, raise)
  local first = #v + 1
  local R = GridLook.ritual
  for _, r in ipairs(ritual.rings) do
    Mesh.ring(v, ritual.x, R.lift, ritual.z, r, R.width, colors.ritual)
  end
  for i = 0, ritual.seals - 1 do
    local a = i * math.pi * 2 / ritual.seals
    Mesh.ring(
      v,
      ritual.x + math.cos(a) * ritual.orbit,
      R.sealLift,
      ritual.z + math.sin(a) * ritual.orbit,
      R.sealRadius,
      R.sealWidth,
      trim,
      R.sealSides
    )
  end
  raise(first, ritual.x, ritual.z, ritual.y)
end
local function sealStone(v, s, raise)
  local first = #v + 1
  local L = GridLook.sealStone
  local base, shaft, crown, ring = L.base, L.shaft, L.crown, L.ring
  Mesh.cone(v, s.x, 0, s.z, base.foot, base.head, base.height, dark, base.sides)
  Mesh.cone(
    v,
    s.x,
    shaft.at,
    s.z,
    shaft.foot,
    shaft.head,
    shaft.height,
    stone,
    GridLook.shaft.sides
  )
  Mesh.cone(v, s.x, crown.at, s.z, crown.foot, crown.head, crown.height, trim, GridLook.shaft.sides)
  Mesh.ring(v, s.x, ring.lift, s.z, ring.radius, ring.width, colors.sealRing, ring.sides)
  raise(first, s.x, s.z)
end
local function portalFrame(v, portal, raise)
  local first = #v + 1
  local P = GridLook.portal
  local sill, ring, light, posts = P.sill, P.ring, P.glow, P.posts
  Mesh.box(v, portal.x, 0, portal.z, sill.width, sill.height, sill.depth, dark)
  Mesh.ring(
    v,
    portal.x,
    portal.y,
    portal.z - ring.back,
    portal.radius,
    ring.width,
    trim,
    ring.sides,
    true
  )
  Mesh.ring(
    v,
    portal.x,
    portal.y,
    portal.z - light.back,
    portal.radius - light.inset,
    light.width,
    glow,
    ring.sides,
    true
  )
  for side = -1, 1, 2 do
    local x, z = portal.x + side * posts.apart, portal.z + posts.forward
    Mesh.cone(v, x, 0, z, posts.foot, posts.head, posts.height, stone)
    Mesh.cone(v, x, posts.height, z, posts.head, 0, posts.tip, trim)
  end
  raise(first, portal.x, portal.z)
end
-- Banners hang beside the walls of the widened nave.
local function hangBanner(v, banner, raise)
  local first = #v + 1
  local x, z, side = banner.x, banner.z, banner.side
  local B = GridLook.banner
  local rod, clasp = B.rod, B.clasp
  Mesh.beam(
    v,
    { x, rod.height, z - rod.half },
    { x, rod.height, z + rod.half },
    rod.radius,
    trim,
    rod.sides
  )
  for i = 0, B.strips - 1 do
    local a = i / B.strips
    local b = (i + 1) / B.strips
    local xa = x + side * (B.out + math.sin(a * math.pi * B.ripples) * B.ripple)
    local xb = x + side * (B.out + math.sin(b * math.pi * B.ripples) * B.ripple)
    Mesh.quad(
      v,
      { xa, B.top, z - B.half + a * B.width },
      { xb, B.top, z - B.half + b * B.width },
      { xb, B.hem + math.sin(b * math.pi) * B.sag, z - B.half + b * B.width },
      { xa, B.hem + math.sin(a * math.pi) * B.sag, z - B.half + a * B.width },
      colors.cloth
    )
  end
  Mesh.ring(
    v,
    x + side * clasp.out,
    clasp.height,
    z,
    clasp.radius,
    clasp.width,
    colors.clasp,
    clasp.sides,
    true
  )
  raise(first, banner.x, banner.z, banner.y)
end
local function candles(v, spot, raise)
  local first = #v + 1
  local C = GridLook.candle
  local flame = C.flame
  for i = 1, 3 do
    local x = spot.x + (i - 2) * C.apart
    local h = C.height + i * C.taller
    Mesh.cone(v, x, 0, spot.z, C.foot, C.head, h, colors.wax, C.sides)
    Mesh.cone(v, x, h, spot.z, flame.radius, 0, flame.height, colors.flame, flame.sides)
  end
  raise(first, spot.x, spot.z, spot.y)
end
local function build(w)
  local v = {}
  local decor = w.decor or {}
  local function raise(first, x, z, offset)
    local height = Ground.height(w, x, z) - Ground.height(w) + (offset or 0)
    if height ~= 0 then
      for i = first, #v do
        v[i][2] = v[i][2] + height
      end
    end
  end
  for z = 1, Grid.depth(w) do
    for x = 1, Grid.width(w) do
      if not Halls.covers(w, x, z) then
        if Tiles.walkable[w.map[z][x]] then
          floorCell(v, w, decor, raise, x, z)
        elseif Tiles.round[w.map[z][x]] then
          roundShaft(v, w, raise, x, z)
        end
      end
    end
  end
  -- Decks (plan v10 V3).
  for z = 1, Grid.depth(w) do
    for x = 1, Grid.width(w) do
      for _, deck in ipairs(not Halls.covers(w, x, z) and Ground.decks(w, x, z) or {}) do
        deckCell(v, w, decor, x, z, deck)
      end
    end
  end
  for _, arch in ipairs(decor.arches or {}) do
    ribArch(v, arch, raise)
  end
  for _, ritual in ipairs(decor.rituals or {}) do
    ritualInlay(v, ritual, raise)
  end
  for _, aisle in ipairs(decor.aisles or {}) do
    local first = #v + 1
    local A = GridLook.aisle
    Mesh.box(v, aisle.x, A.lift, aisle.z, A.width, A.height, aisle.length, colors.aisle)
    raise(first, aisle.x, aisle.z, aisle.y)
  end
  for _, s in ipairs(w.seals) do
    if not Halls.covers(w, math.floor(s.x + 0.5), math.floor(s.z + 0.5)) then
      sealStone(v, s, raise)
    end
  end
  if decor.portal then
    portalFrame(v, decor.portal, raise)
  end
  -- Dress the existing test arena without changing collision or routes.
  for _, banner in ipairs(decor.banners or {}) do
    hangBanner(v, banner, raise)
  end
  -- Candle clusters, ossuary niches, and the cracked western reliquary.
  for _, spot in ipairs(decor.candles or {}) do
    candles(v, spot, raise)
  end
  for _, spot in ipairs(decor.reliquaries or {}) do
    local first = #v + 1
    local chest, lid = GridLook.reliquary.chest, GridLook.reliquary.lid
    Mesh.box(v, spot.x, 0, spot.z, chest.width, chest.height, chest.depth, dark)
    Mesh.box(v, spot.x, chest.height, spot.z, lid.width, lid.height, lid.depth, trim)
    raise(first, spot.x, spot.z, spot.y)
  end
  local floor = Ground.height(w)
  if floor ~= 0 then
    for _, vertex in ipairs(v) do
      vertex[2] = vertex[2] + floor
    end
  end
  return Mesh.finish(v)
end
function Geometry.prepare(w, owner)
  assert(owner, 'world geometry requires an explicit resource owner')
  if not identities[w] then
    serial = serial + 1
    identities[w] = serial
  end
  local revision = w.viewRevision or w.geometryRevision
  local key = 'world geometry|' .. identities[w] .. '|' .. tostring(revision)
  return owner:retain(key, function()
    return build(w)
  end, function(mesh)
    mesh:release()
  end, { kind = 'generated world geometry', revision = revision })
end
return Geometry
