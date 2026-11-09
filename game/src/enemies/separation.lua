-- Living bodies never overlap. See separate below.
local Archetypes = require('src.content.enemies')
local MathX = require('src.core.mathx')
local Arena = require('src.world.arena')
local Rules = require('src.combat.rules')
local Pools = require('src.session.world')
local Spatial = require('src.physics.spatial')
local Separation = {}
local len = MathX.len
local radius = Rules.radius
-- One pair, as the rules part it: true when they overlapped and moved.
local function part(g, a, b, dt, S)
  local dx, dz = a.x - b.x, a.z - b.z
  local d = len(dx, dz)
  local minimum = math.max(S.minimum, radius(a) + radius(b))
  -- Footprints first: heights are compared only for bodies that touch.
  if b.hp > 0 and d < minimum and Rules.bodiesOverlap(g, a, b) then
    local overlap = minimum - d
    if d < 1e-3 then
      dx, dz, d = 1, 0, 1
    end
    -- The parting is shared by the masses (0.25): the lighter body
    -- gives way more; equal bodies part equally.
    local amount = math.min(S.step, dt * S.rate, overlap * S.share)
    local ma, mb = Rules.body(a).mass or 1, Rules.body(b).mass or 1
    local ga, gb = 2 * amount * mb / (ma + mb), 2 * amount * ma / (ma + mb)
    Arena.move(g.world, a, dx / d * ga, dz / d * ga, radius(a), nil, Rules.tall(g, a))
    Arena.move(g.world, b, -dx / d * gb, -dz / d * gb, radius(b), nil, Rules.tall(g, b))
    return true
  end
  return false
end
-- Scratch of the indexed pass (rebuilt by every call, never kept between).
local hash, order, near = Spatial.new(1), {}, {}
-- The neighbours of a that come after `after` in the pool, in pool order.
local function gather(a, reach, after)
  for i = #near, 1, -1 do
    near[i] = nil
  end
  hash:query(a.x, a.z, reach, near)
  local n = 0
  for i = 1, #near do
    local b = near[i]
    if order[b] > after then
      n = n + 1
      near[n] = b
    end
  end
  for i = #near, n + 1, -1 do
    near[i] = nil
  end
  -- Insertion sort by pool order: neighbour lists are short.
  for i = 2, n do
    local b, k = near[i], order[near[i]]
    local j = i - 1
    while j >= 1 and order[near[j]] > k do
      near[j + 1] = near[j]
      j = j - 1
    end
    near[j + 1] = b
  end
  return near
end
-- Living bodies never overlap: resolve full overlaps symmetrically,
-- including identical spawn coordinates. Every pair in pool order (each a,
-- then every later b), as it always was; a spatial index (plan v10 V3)
-- skips only pairs too far apart to touch. A body that moves farther than
-- the margin during its own pass gathers its neighbours again, so the
-- result equals the pass over every pair.
local function separate(g, dt)
  local S = Archetypes.defaults.separation
  local bodies = Pools.of(g, 'enemies')
  local reach = S.minimum
  for _, e in ipairs(bodies) do
    if e.hp > 0 then
      reach = math.max(reach, 2 * radius(e))
    end
  end
  local margin = S.margin
  if hash.size ~= reach + margin then
    hash = Spatial.new(reach + margin)
  else
    hash:clear()
  end
  for e in pairs(order) do
    order[e] = nil
  end
  for i, e in ipairs(bodies) do
    order[e] = i
    if e.hp > 0 then
      hash:insert(e, e.x, e.z)
    end
  end
  for i, a in ipairs(bodies) do
    if a.hp > 0 then
      local list = gather(a, reach + margin, i)
      local ax, az = a.x, a.z
      local k = 1
      while k <= #list do
        local b = list[k]
        if part(g, a, b, dt, S) then
          hash:move(a, a.x, a.z)
          hash:move(b, b.x, b.z)
          if len(a.x - ax, a.z - az) > margin then
            -- Its later neighbours, from where it stands now.
            list = gather(a, reach + margin, order[b])
            ax, az, k = a.x, a.z, 0
          end
        end
        k = k + 1
      end
    end
  end
end
Separation.run = separate
return Separation
