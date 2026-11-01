-- The small breakable things of a hall: each kind drawn whole and as what it
-- leaves behind. A new kind is one entry in content/breakables.lua and one here.
local Ground = require('src.physics.ground')
local B = require('src.render.kit.builder')
local Props = {}
local cos, sin, pi = math.cos, math.sin, math.pi
local URN = {
  { 0.0, 0.0 },
  { 0.15, 0.0 },
  { 0.17, 0.05 },
  { 0.27, 0.26 },
  { 0.3, 0.42 },
  { 0.24, 0.6 },
  { 0.12, 0.72 },
  { 0.1, 0.78 },
  { 0.15, 0.84 },
  { 0.12, 0.84 },
  { 0.08, 0.76 },
}
local BROKEN_URN =
  { { 0.0, 0.0 }, { 0.15, 0.0 }, { 0.17, 0.05 }, { 0.25, 0.2 }, { 0.2, 0.2 }, { 0.12, 0.08 } }
local function shards(list, x, z, base, count, spread, size, seed)
  local rng = B.random(seed)
  for i = 1, count do
    local a, d = rng() * 2 * pi, spread * (0.3 + rng() * 0.7)
    local s = size * (0.5 + rng() * 0.8)
    B.block(
      list,
      { x + cos(a) * d, base + s * 0.4, z + sin(a) * d },
      { s * 1.4, s * 0.35, s },
      rng() * pi,
      (rng() - 0.5) * 0.6,
      seed * 31 + i
    )
  end
end
local Draw = {}
function Draw.urn(sink, def, base, seed)
  local x, z = def.from[1], def.from[3]
  local scale = def.scale or 1
  local profile = {}
  for i, p in ipairs(URN) do
    profile[i] = { p[1] * scale, base + p[2] * scale }
  end
  B.lathe(sink:scope(def.id, 'whole').clay, x, z, profile, 16, 2, 1, nil, 0.9 * scale)
  profile = {}
  for i, p in ipairs(BROKEN_URN) do
    profile[i] = { p[1] * scale, base + p[2] * scale }
  end
  local after = sink:scope(def.id, 'after')
  B.lathe(after.clay, x, z, profile, 12, 2, 0.9, nil, 0.9 * scale)
  shards(after.clay, x, z, base, 9, 0.62, 0.075 * scale, seed)
end
function Draw.bench(sink, def, base, seed)
  local a, b = def.from, def.to
  local cx, cz = (a[1] + b[1]) / 2, (a[3] + b[3]) / 2
  local dx, dz = b[1] - a[1], b[3] - a[3]
  local length = math.sqrt(dx * dx + dz * dz)
  local yaw = math.atan2(dz, dx)
  local whole = sink:scope(def.id, 'whole')
  B.block(whole.wood, { cx, base + 0.46, cz }, { length / 2, 0.035, 0.2 }, yaw, 0, seed)
  B.block(
    whole.wood,
    { cx + sin(yaw) * 0.22, base + 0.72, cz - cos(yaw) * 0.22 },
    { length / 2, 0.08, 0.025 },
    yaw,
    0,
    seed + 1
  )
  for _, along in ipairs({ -0.42, 0.42 }) do
    local lx, lz = cx + cos(yaw) * length * along, cz + sin(yaw) * length * along
    B.block(whole.wood, { lx, base + 0.22, lz }, { 0.04, 0.22, 0.17 }, yaw, 0, seed + 2)
  end
  local after = sink:scope(def.id, 'after')
  local rng = B.random(seed)
  for i = 1, 6 do
    local along = (rng() - 0.5) * length
    B.block(after.wood, {
      cx + cos(yaw) * along + (rng() - 0.5) * 0.5,
      base + 0.05,
      cz + sin(yaw) * along + (rng() - 0.5) * 0.5,
    }, { 0.34 + rng() * 0.28, 0.03, 0.08 }, rng() * pi, (rng() - 0.5) * 0.25, seed * 13 + i)
  end
end
function Draw.candles(sink, def, base, seed)
  local x, z = def.from[1], def.from[3]
  local whole = sink:scope(def.id, 'whole')
  for i = 1, 3 do
    local a = i * 2.1 + seed
    local cx, cz = x + cos(a) * 0.1, z + sin(a) * 0.1
    local h = 0.16 + i * 0.05
    B.lathe(
      whole.clay,
      cx,
      cz,
      { { 0.0, base }, { 0.042, base }, { 0.038, base + h }, { 0.0, base + h } },
      6,
      1,
      1.2
    )
    local flame = sink:scope(def.id, 'flame').clay
    flame.glow = 1
    B.lathe(
      flame,
      cx,
      cz,
      { { 0.02, base + h }, { 0.026, base + h + 0.03 }, { 0.0, base + h + 0.1 } },
      5,
      1,
      1
    )
  end
  shards(sink:scope(def.id, 'after').clay, x, z, base, 4, 0.2, 0.04, seed)
end
function Props.add(sink, w, def)
  local draw = Draw[def.kind]
  if draw then
    local x, z = math.floor(def.from[1] + 0.5), math.floor(def.from[3] + 0.5)
    local seed = 0
    for i = 1, #def.id do
      seed = (seed * 31 + def.id:byte(i)) % 9973
    end
    draw(sink, def, def.base or Ground.cell(w, x, z), seed + 1)
  end
end
return Props
