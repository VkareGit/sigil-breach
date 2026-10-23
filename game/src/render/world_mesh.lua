-- Presentation resource: built on first draw, reused until the world revision changes.
-- World creation and collision tests never allocate a GPU mesh.
local M = require('src.render.mesh')
local Collision = require('src.physics.collision')
local Geometry = {}
local stone, dark, trim, glow =
  { 0.24, 0.29, 0.30 }, { 0.095, 0.12, 0.14 }, { 0.42, 0.36, 0.24 }, { 1, 0.28, 0.055, 1 }
function Geometry.prepare(w)
  if w.mesh and w.meshRevision == w.geometryRevision then
    return w.mesh
  end
  local v = {}
  for z = 1, w.size do
    for x = 1, w.size do
      if w.map[z][x] == 0 then
        M.quad(
          v,
          { x - 0.5, 0, z - 0.5 },
          { x - 0.5, 0, z + 0.5 },
          { x + 0.5, 0, z + 0.5 },
          { x + 0.5, 0, z - 0.5 },
          { 0.30, 0.33, 0.32 }
        )
        -- Every exposed face has a high base, a dark panel, and brass cornice.
        for _, d in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
          local nx, nz = x + d[1], z + d[2]
          if w.map[nz] and w.map[nz][nx] and w.map[nz][nx] > 0 then
            local h = Collision.top(w.map[nz][nx])
            local px, pz = x + d[1] * 0.55, z + d[2] * 0.55
            local bw, bd = d[1] == 0 and 1 or 0.12, d[2] == 0 and 1 or 0.12
            M.box(v, px, 0, pz, bw, 0.30, bd, trim)
            M.box(v, px, 0.3, pz, bw, h - 0.55, bd, stone)
            M.box(v, px, h - 0.25, pz, bw, 0.25, bd, trim)
            -- Leave continuous lime behind the three narrative wall paintings:
            -- a black niche stripe through a fresco reads as a pasted decal.
            local muralWall = ((x == 3 or x == 29) and z >= 14 and z <= 18)
              or (z == 29 and x >= 14 and x <= 18)
            if (x + z) % 3 == 0 and not muralWall then
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
          end
        end
      elseif w.map[z][x] == 2 then
        M.box(v, x, 0, z, 1.15, 0.22, 1.15, trim)
        M.cone(v, x, 0.22, z, 0.48, 0.36, 4.5, stone, 8)
        M.cone(v, x, 3.8, z, 0.37, 0.68, 0.5, trim, 8)
        M.cone(v, x, 4.3, z, 0.68, 0.45, 0.5, stone, 8)
      end
    end
  end
  -- Elevated rib arches across the nave, open to an impossible sky.
  -- 0.14: every rib springs from a real pillar (x 12 / 20): no column you can walk through.
  for _, z in ipairs({ 10, 15, 20, 25 }) do
    for side = -1, 1, 2 do
      for i = 0, 11 do
        local a = i / 12 * math.pi / 2
        local b = (i + 1) / 12 * math.pi / 2
        M.beam(
          v,
          { 16 + side * 4 * math.cos(a), 3.8 + 2 * math.sin(a), z },
          { 16 + side * 4 * math.cos(b), 3.8 + 2 * math.sin(b), z },
          0.18,
          stone
        )
      end
    end
  end
  -- Main ritual inlay, lines and nine circles.
  for _, r in ipairs({ 2.3, 2.4, 2.85 }) do
    M.ring(v, 16, 0.012, 17, r, 0.025, { 0.59, 0.40, 0.18, 0.25 })
  end
  for i = 0, 8 do
    local a = i * math.pi * 2 / 9
    M.ring(v, 16 + math.cos(a) * 2.62, 0.014, 17 + math.sin(a) * 2.62, 0.14, 0.02, trim, 16)
  end
  for _, x in ipairs({ 15.3, 16.7 }) do
    M.box(v, x, 0.01, 24, 0.025, 0.01, 9, { 0.55, 0.35, 0.15, 0.1 })
  end
  for _, s in ipairs(w.seals) do
    M.cone(v, s.x, 0, s.z, 0.95, 0.85, 0.18, dark, 32)
    M.cone(v, s.x, 0.18, s.z, 0.48, 0.32, 0.75, stone, 8)
    M.cone(v, s.x, 0.92, s.z, 0.32, 0.62, 0.12, trim, 8)
    M.ring(v, s.x, 0.20, s.z, 0.76, 0.025, { 0.31, 0.22, 0.15, 0.05 }, 40)
  end
  M.box(v, 16, 0, 2.9, 4, 0.2, 0.9, dark)
  M.ring(v, 16, 2.1, 2.85, 1.7, 0.16, trim, 64, true)
  M.ring(v, 16, 2.1, 2.84, 1.5, 0.04, glow, 64, true)
  for _, x in ipairs({ 13.8, 18.2 }) do
    M.cone(v, x, 0, 3, 0.4, 0.25, 3.5, stone)
    M.cone(v, x, 3.5, 3, 0.25, 0, 0.8, trim)
  end
  -- Dress the existing test arena without changing collision or routes.
  -- Banners hang beside the walls of the widened nave.
  for _, z in ipairs({ 25, 28 }) do
    for _, x in ipairs({ 9.25, 22.75 }) do
      local side = x < 16 and 1 or -1
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
    end
  end
  -- Candle clusters, ossuary niches, and the cracked western reliquary.
  for _, spot in ipairs({ { 14, 28 }, { 18, 28 }, { 6, 16 }, { 26, 16 }, { 14, 4 }, { 18, 4 } }) do
    for i = 1, 3 do
      local x = spot[1] + (i - 2) * 0.16
      local h = 0.16 + i * 0.05
      M.cone(v, x, 0, spot[2], 0.04, 0.035, h, { 0.57, 0.47, 0.29, 0.04 }, 6)
      M.cone(v, x, h, spot[2], 0.027, 0, 0.09, { 1, 0.47, 0.12, 1 }, 5)
    end
  end
  M.box(v, 3.7, 0, 20.4, 0.50, 0.65, 0.38, dark)
  M.box(v, 3.7, 0.65, 20.4, 0.58, 0.07, 0.43, trim)
  if w.mesh then
    w.mesh:release()
  end
  w.mesh = M.finish(v)
  w.meshRevision = w.geometryRevision
  return w.mesh
end
return Geometry
