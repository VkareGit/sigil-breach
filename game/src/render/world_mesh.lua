-- Presentation resource: built on first draw, reused until the world revision changes.
-- World creation and collision tests never allocate a GPU mesh.
local Tiles = require('src.core.tiles')
local M = require('src.render.mesh')
local Collision = require('src.physics.collision')
local Ground = require('src.physics.ground')
local Grid = require('src.physics.grid')
local Roof = require('src.physics.roof_cell')
local Halls = require('src.render.kit.halls')
local Geometry = {}
-- The weak map names worlds but owns no native resources. A live simulation
-- world must not keep a mesh alive after its last renderer has closed.
local identities, serial = setmetatable({}, { __mode = 'k' }), 0
local stone, dark, trim, glow =
  { 0.24, 0.29, 0.30 }, { 0.095, 0.12, 0.14 }, { 0.42, 0.36, 0.24 }, { 1, 0.28, 0.055, 1 }
local function roofCell(v, w, x, z, deck)
  local p, top = Roof.corners(deck, x, z), deck[2]
  if deck[3][5] then
    local middle = { x, deck[3][5], z }
    for i = 1, 4 do
      M.tri(v, p[i], p[i % 4 + 1], middle, stone)
    end
  else
    M.tri(v, p[1], p[2], p[3], stone)
    M.tri(v, p[1], p[3], p[4], stone)
  end
  -- A hall open to the sky sees over the walls: the outer shell of the other
  -- roofs must not rise behind it. Steps between vaults stay.
  local shell = not (w.decor and w.decor.halls)
  if shell then
    M.quad(
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
      M.quad(v, a, { a[1], highA, a[3] }, { b[1], highB, b[3] }, b, stone)
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
    local px, pz = x + d[1] * 0.55, z + d[2] * 0.55
    local bw, bd = d[1] == 0 and 1 or 0.12, d[2] == 0 and 1 or 0.12
    M.box(v, px, 0, pz, bw, 0.30, bd, trim)
    M.box(v, px, 0.3, pz, bw, h - 0.55, bd, stone)
    M.box(v, px, h - 0.25, pz, bw, 0.25, bd, trim)
    -- Leave continuous lime behind the three narrative wall paintings:
    -- a black niche stripe through a fresco reads as a pasted decal.
    if decor.niches ~= false and (x + z) % 3 == 0 and not muralWall(decor, x, z) then
      M.box(v, px - d[1] * 0.06, 0.55, pz - d[2] * 0.06, bw * 0.92, 2.8, bd * 0.92, dark)
      M.box(
        v,
        px - d[1] * 0.12,
        0.7,
        pz - d[2] * 0.12,
        d[1] == 0 and 0.035 or 0.025,
        2.25,
        d[2] == 0 and 0.035 or 0.025,
        { 0.5, 0.31, 0.13 }
      )
    end
    raise(first, nx, nz)
  end
end
local function floorCell(v, w, decor, raise, x, z)
  local elevation = Ground.cell(w, x, z)
  M.quad(
    v,
    { x - 0.5, elevation, z - 0.5 },
    { x - 0.5, elevation, z + 0.5 },
    { x + 0.5, elevation, z + 0.5 },
    { x + 0.5, elevation, z - 0.5 },
    { 0.30, 0.33, 0.32 }
  )
  -- Every exposed face has a high base, a dark panel, and brass cornice.
  for _, d in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
    local nx, nz = x + d[1], z + d[2]
    local adjacent = Ground.cell(w, nx, nz)
    if w.map[nz] and Tiles.walkable[w.map[nz][nx]] and elevation > adjacent then
      -- The riser is the same cell boundary queried by collision/rays.
      local px, pz = x + d[1] * 0.5, z + d[2] * 0.5
      local tx, tz = d[2] * 0.5, -d[1] * 0.5
      M.quad(
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
    M.box(v, x, 0, z, 1, elevation, 1, stone)
  end
  local first = #v + 1
  M.box(v, x, 0, z, 1.15, 0.22, 1.15, trim)
  M.cone(v, x, 0.22, z, 0.48, 0.36, 4.5, stone, 8)
  M.cone(v, x, 3.8, z, 0.37, 0.68, 0.5, trim, 8)
  M.cone(v, x, 4.3, z, 0.68, 0.45, 0.5, stone, 8)
  raise(first, x, z)
end
-- A slab's top, underside and the edges no neighbouring cell of the same deck hides.
local function deckCell(v, w, decor, x, z, deck)
  if deck[3] then
    roofCell(v, w, x, z, deck)
  else
    local bottom, top = deck[1], deck[2]
    M.quad(
      v,
      { x - 0.5, top, z - 0.5 },
      { x - 0.5, top, z + 0.5 },
      { x + 0.5, top, z + 0.5 },
      { x + 0.5, top, z - 0.5 },
      { 0.30, 0.33, 0.32 }
    )
    M.quad(
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
        M.quad(
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
    for i = 0, 11 do
      local a = i / 12 * math.pi / 2
      local b = (i + 1) / 12 * math.pi / 2
      M.beam(v, point(a, side), point(b, side), arch.radius or 0.18, stone)
    end
  end
  raise(first, arch.x, arch.z, arch.y)
end
-- Main ritual inlay, lines and nine circles.
local function ritualInlay(v, ritual, raise)
  local first = #v + 1
  for _, r in ipairs(ritual.rings) do
    M.ring(v, ritual.x, 0.012, ritual.z, r, 0.025, { 0.59, 0.40, 0.18, 0.25 })
  end
  for i = 0, ritual.seals - 1 do
    local a = i * math.pi * 2 / ritual.seals
    M.ring(
      v,
      ritual.x + math.cos(a) * ritual.orbit,
      0.014,
      ritual.z + math.sin(a) * ritual.orbit,
      0.14,
      0.02,
      trim,
      16
    )
  end
  raise(first, ritual.x, ritual.z, ritual.y)
end
local function sealStone(v, s, raise)
  local first = #v + 1
  M.cone(v, s.x, 0, s.z, 0.95, 0.85, 0.18, dark, 32)
  M.cone(v, s.x, 0.18, s.z, 0.48, 0.32, 0.75, stone, 8)
  M.cone(v, s.x, 0.92, s.z, 0.32, 0.62, 0.12, trim, 8)
  M.ring(v, s.x, 0.20, s.z, 0.76, 0.025, { 0.31, 0.22, 0.15, 0.05 }, 40)
  raise(first, s.x, s.z)
end
local function portalFrame(v, portal, raise)
  local first = #v + 1
  M.box(v, portal.x, 0, portal.z, 4, 0.2, 0.9, dark)
  M.ring(v, portal.x, portal.y, portal.z - 0.05, portal.radius, 0.16, trim, 64, true)
  M.ring(v, portal.x, portal.y, portal.z - 0.06, portal.radius - 0.2, 0.04, glow, 64, true)
  for side = -1, 1, 2 do
    local x = portal.x + side * 2.2
    M.cone(v, x, 0, portal.z + 0.1, 0.4, 0.25, 3.5, stone)
    M.cone(v, x, 3.5, portal.z + 0.1, 0.25, 0, 0.8, trim)
  end
  raise(first, portal.x, portal.z)
end
-- Banners hang beside the walls of the widened nave.
local function hangBanner(v, banner, raise)
  local first = #v + 1
  local x, z, side = banner.x, banner.z, banner.side
  M.beam(v, { x, 3.8, z - 0.65 }, { x, 3.8, z + 0.65 }, 0.035, trim, 6)
  for i = 0, 9 do
    local a = i / 10
    local b = (i + 1) / 10
    local xa = x + side * (0.09 + math.sin(a * math.pi * 4) * 0.035)
    local xb = x + side * (0.09 + math.sin(b * math.pi * 4) * 0.035)
    M.quad(
      v,
      { xa, 3.75, z - 0.55 + a * 1.1 },
      { xb, 3.75, z - 0.55 + b * 1.1 },
      { xb, 1.9 + math.sin(b * math.pi) * 0.12, z - 0.55 + b * 1.1 },
      { xa, 1.9 + math.sin(a * math.pi) * 0.12, z - 0.55 + a * 1.1 },
      { 0.24, 0.045, 0.035, 0 }
    )
  end
  M.ring(v, x + side * 0.14, 2.9, z, 0.20, 0.02, { 0.55, 0.32, 0.12, 0.08 }, 24, true)
  raise(first, banner.x, banner.z, banner.y)
end
local function candles(v, spot, raise)
  local first = #v + 1
  for i = 1, 3 do
    local x = spot.x + (i - 2) * 0.16
    local h = 0.16 + i * 0.05
    M.cone(v, x, 0, spot.z, 0.04, 0.035, h, { 0.57, 0.47, 0.29, 0.04 }, 6)
    M.cone(v, x, h, spot.z, 0.027, 0, 0.09, { 1, 0.47, 0.12, 1 }, 5)
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
    M.box(v, aisle.x, 0.01, aisle.z, 0.025, 0.01, aisle.length, { 0.55, 0.35, 0.15, 0.1 })
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
    M.box(v, spot.x, 0, spot.z, 0.50, 0.65, 0.38, dark)
    M.box(v, spot.x, 0.65, spot.z, 0.58, 0.07, 0.43, trim)
    raise(first, spot.x, spot.z, spot.y)
  end
  local floor = Ground.height(w)
  if floor ~= 0 then
    for _, vertex in ipairs(v) do
      vertex[2] = vertex[2] + floor
    end
  end
  return M.finish(v)
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
