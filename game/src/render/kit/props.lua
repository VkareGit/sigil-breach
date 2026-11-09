-- The small breakable things of a hall: each kind drawn whole and as what it
-- leaves behind. A new kind is one entry in content/breakables.lua and one here.
local Ground = require('src.physics.ground')
local Builder = require('src.render.kit.builder')
local PropForms = require('src.content.art.prop_forms')
local Props = {}
local cos, sin, pi = math.cos, math.sin, math.pi
local function shards(list, x, z, base, count, spread, size, seed)
  local rng = Builder.random(seed)
  local S = PropForms.shards
  for i = 1, count do
    local a, d = rng() * 2 * pi, spread * (S.near + rng() * S.far)
    local s = size * (S.small + rng() * S.vary)
    Builder.block(
      list,
      { x + cos(a) * d, base + s * S.lift, z + sin(a) * d },
      { s * S.long, s * S.flat, s },
      rng() * pi,
      (rng() - 0.5) * S.tilt,
      seed * 31 + i -- constant: a seed of its own for every shard
    )
  end
end
local Draw = {}
function Draw.urn(sink, def, base, seed)
  local x, z = def.from[1], def.from[3]
  local scale = def.scale or 1
  local U = PropForms.urn
  local profile = {}
  for i, p in ipairs(U.profile) do
    profile[i] = { p[1] * scale, base + p[2] * scale }
  end
  Builder.lathe(
    sink:scope(def.id, 'whole').clay,
    x,
    z,
    profile,
    U.sides,
    U.wraps,
    1,
    nil,
    U.span * scale
  )
  profile = {}
  for i, p in ipairs(U.broken) do
    profile[i] = { p[1] * scale, base + p[2] * scale }
  end
  local after = sink:scope(def.id, 'after')
  Builder.lathe(
    after.clay,
    x,
    z,
    profile,
    U.brokenSides,
    U.wraps,
    U.brokenShade,
    nil,
    U.span * scale
  )
  shards(after.clay, x, z, base, U.shards.count, U.shards.spread, U.shards.size * scale, seed)
end
function Draw.bench(sink, def, base, seed)
  local a, b = def.from, def.to
  local cx, cz = (a[1] + b[1]) / 2, (a[3] + b[3]) / 2
  local dx, dz = b[1] - a[1], b[3] - a[3]
  local length = math.sqrt(dx * dx + dz * dz)
  local yaw = math.atan2(dz, dx)
  local whole = sink:scope(def.id, 'whole')
  local B = PropForms.bench
  local seat, back, legs, plank = B.seat, B.back, B.legs, B.plank
  Builder.block(
    whole.wood,
    { cx, base + seat.height, cz },
    { length / 2, seat.thick, seat.half },
    yaw,
    0,
    seed
  )
  Builder.block(
    whole.wood,
    { cx + sin(yaw) * back.out, base + back.height, cz - cos(yaw) * back.out },
    { length / 2, back.tall, back.thick },
    yaw,
    0,
    seed + 1
  )
  for _, along in ipairs({ -legs.along, legs.along }) do
    local lx, lz = cx + cos(yaw) * length * along, cz + sin(yaw) * length * along
    Builder.block(
      whole.wood,
      { lx, base + legs.height, lz },
      { legs.thick, legs.height, legs.half },
      yaw,
      0,
      seed + 2
    )
  end
  local after = sink:scope(def.id, 'after')
  local rng = Builder.random(seed)
  for i = 1, B.planks do
    local along = (rng() - 0.5) * length
    Builder.block(
      after.wood,
      {
        cx + cos(yaw) * along + (rng() - 0.5) * B.scatter,
        base + B.rest,
        cz + sin(yaw) * along + (rng() - 0.5) * B.scatter,
      },
      { plank.long + rng() * plank.vary, plank.thick, plank.half },
      rng() * pi,
      (rng() - 0.5) * B.tilt,
      seed * 13 + i -- constant: a seed of its own for every plank
    )
  end
end
function Draw.candles(sink, def, base, seed)
  local x, z = def.from[1], def.from[3]
  local whole = sink:scope(def.id, 'whole')
  local C = PropForms.candles
  local F = C.flame
  for i = 1, 3 do
    local a = i * C.turn + seed
    local cx, cz = x + cos(a) * C.reach, z + sin(a) * C.reach
    local h = C.height + i * C.taller
    Builder.lathe(
      whole.clay,
      cx,
      cz,
      { { 0, base }, { C.foot, base }, { C.head, base + h }, { 0, base + h } },
      C.sides,
      1,
      C.shade
    )
    local flame = sink:scope(def.id, 'flame').clay
    flame.glow = 1
    Builder.lathe(
      flame,
      cx,
      cz,
      { { F.foot, base + h }, { F.middle, base + h + F.rise }, { 0, base + h + F.height } },
      F.sides,
      1,
      1
    )
  end
  shards(
    sink:scope(def.id, 'after').clay,
    x,
    z,
    base,
    C.shards.count,
    C.shards.spread,
    C.shards.size,
    seed
  )
end
function Props.add(sink, w, def)
  local draw = Draw[def.kind]
  if draw then
    local x, z = math.floor(def.from[1] + 0.5), math.floor(def.from[3] + 0.5)
    local seed = 0
    for i = 1, #def.id do
      seed = (seed * 31 + def.id:byte(i)) % 9973 -- constant: a string hash
    end
    draw(sink, def, def.base or Ground.cell(w, x, z), seed + 1)
  end
end
return Props
