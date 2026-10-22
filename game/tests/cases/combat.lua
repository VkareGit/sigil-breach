-- Pure regression probes: no renderer, asset loading or desktop input needed.
local Fixtures = require('tests.support.fixtures')
local Tests = {}
function Tests.run(check)
  local B = require('src.combat.ballistics')
  local D = require('src.combat.damage')
  local near = Fixtures.within(1e-7)
  local function world(size)
    local w = { size = size, map = {} }
    for z = 1, size do
      w.map[z] = {}
      for x = 1, size do
        w.map[z][x] = 0
      end
    end
    return w
  end
  local function wall(w, ox, oy, oz, dx, dy, dz, range)
    local d, n, kind = B.world(w, ox, oy, oz, dx, dy, dz, range)
    return kind == 'wall' and d or nil, n, kind
  end
  local diagonal = 1 / math.sqrt(2)
  for _, side in ipairs({ 'x', 'z' }) do
    local w = world(8)
    if side == 'x' then
      w.map[3][4] = 1
    else
      w.map[4][3] = 1
    end
    local forward = wall(w, 3, 1, 3, diagonal, 0, diagonal, 2)
    local reverse = wall(w, 4, 1, 4, -diagonal, 0, -diagonal, 2)
    check(
      'corner contact blocks ' .. side .. ' neighbour in both ray directions',
      near(forward, diagonal) and near(reverse, diagonal)
    )
  end
  local w = world(8)
  w.map[3][4] = 1
  w.map[4][3] = 1
  local d, n = wall(w, 3, 1, 3, diagonal, 0, diagonal, 2)
  check(
    'closed diagonal corner produces a unit symmetric collision normal',
    near(d, diagonal) and near(n[1], -diagonal) and near(n[3], -diagonal)
  )
  w = world(8)
  w.map[4][4] = 1
  d, n = wall(w, 3, 1, 3, diagonal, 0, diagonal, 2)
  check(
    'entering a solid diagonal cell stops at the corner with a unit normal',
    near(d, diagonal) and near(n[1] ^ 2 + n[2] ^ 2 + n[3] ^ 2, 1)
  )
  w = world(8)
  w.map[3][4] = 1
  local dx, dz = 1, 1 + 1e-5
  local len = math.sqrt(dx * dx + dz * dz)
  local _, _, kind = B.world(w, 3, 1, 3, dx / len, 0, dz / len, 2)
  check('corner fix preserves a ray that actually clears the wall', kind == 'range')
  dx, dz = 1 + 1e-5, 1
  len = math.sqrt(dx * dx + dz * dz)
  check(
    'a nearby ray that enters the solid side still hits it',
    wall(w, 3, 1, 3, dx / len, 0, dz / len, 2) ~= nil
  )
  w = world(8)
  w.map[3][3] = 1
  d, n = wall(w, 3.5, 1, 2, 0, 0, 1, 2)
  check(
    'ray along a vertical grid face cannot overlook its solid left neighbour',
    near(d, 0.5) and n[1] == 1
  )
  d, n = wall(w, 2, 1, 3.5, 1, 0, 0, 2)
  check(
    'ray along a horizontal grid face cannot overlook its solid upper neighbour',
    near(d, 0.5) and n[3] == 1
  )
  d, n = wall(w, 3.5, 5, 3.5, 0, -1, 0, 8)
  check(
    'vertical ray at a four-cell corner sees the highest touching wall',
    near(d, 0.8) and n[2] == 1
  )
  d, n = wall(w, 2, 1, 3, 1, 0, 0, 0.5)
  check(
    'wall exactly at segment endpoint is a contact rather than a miss',
    near(d, 0.5) and n[1] == -1
  )
  _, _, kind = B.world(w, 2, 1, 3, 1, 0, 0, 0.5 - 1e-5)
  check('wall beyond segment endpoint cannot stop an earlier projectile lifetime', kind == 'range')
  w = world(260)
  w.map[2][200] = 1
  d = wall(w, 2, 1, 2, 1, 0, 0, 220)
  check('grid traversal has no silent 128-cell cutoff', near(d, 197.5))
  w = world(8)
  w.map[3][4] = 2
  d, n = wall(w, 3, 5.5, 3, 0.8, -0.6, 0, 4)
  check(
    'descending ray hits a pillar top between grid crossings',
    near(d, (5.5 - 4.8) / 0.6) and n[2] == 1
  )
  _, _, kind = B.world(w, 3, 5, 3, 1, 0, 0, 3)
  check('horizontal ray above a pillar does not collide with its footprint', kind == 'range')

  local body = { x = 0, z = 0 }
  check(
    'an overlapping cylinder contact is exactly zero, including a zero-length segment',
    B.cylinderShape(body, 0, 1, 0, 1, 0, 0, 0, 1, 0, 2) == 0
  )
  check(
    'a tiny finite segment preserves its true first contact instead of a synthetic .001',
    B.cylinderShape(body, 0, 1, 0, 1, 0, 0, 0.0001, 1, 0, 2) == 0
  )
  local slow = B.cylinderShape(body, 1.0000005, 1, 0, -0.000001, 0, 0, 1, 1, 0, 2)
  check('sub-micrometre relative motion can cross a cylinder side', near(slow, 0.5, 1e-6))
  slow = B.cylinderShape(body, 0, 2.0000000005, 0, 0, -0.000000001, 0, 1, 1, 0, 2)
  check('sub-nanometre relative motion can cross a cylinder cap', near(slow, 0.5, 1e-6))
  check(
    'a segment wholly before the cylinder still misses',
    B.cylinderShape(body, 2, 1, 0, -1, 0, 0, 0.99, 1, 0, 2) == nil
  )
  check(
    'a true tangent remains a contact',
    near(B.cylinderShape(body, 1, 1, -2, 0, 0, 1, 5, 1, 0, 2), 2)
  )
  check(
    'zero-length segment outside a cylinder cannot create a hit',
    B.cylinderShape(body, 2, 1, 0, 0, 0, 0, 1, 1, 0, 2) == nil
  )
  local all = true
  for _, scale in ipairs({ 0.000001, 0.01, 1, 1000 }) do
    local t = B.cylinderShape(body, 2, 1, 0, -scale, 0, 0, 2 / scale, 1, 0, 2)
    all = all and t ~= nil and near(t * scale, 1)
  end
  check('rescaling a sweep preserves the physical cylinder intersection', all)
  -- Explicit volumetric extensions preserve a t=0 body hit before a wall
  -- only .0005 away. Painted billboards have a different plane-contact contract.
  w = world(8)
  w.map[3][4] = 1
  local profiles = require('src.enemies.hit_volumes').profiles
  local profileKey = 'test-near-wall-volume'
  profiles[profileKey] = { shapes = {} }
  local e = {
    id = 1,
    x = 3.4,
    z = 3,
    hp = 100,
    archetype = { appearance = { hit = 'volumes', anatomy = profileKey } },
  }
  local p = { x = 3.4995, z = 3, jump = 0, crouch = 0 }
  local g = { world = w, player = p, enemies = { e } }
  local bodies = {
    {
      enemy = e,
      volumes = {
        {
          id = 'torso',
          zone = 'torso',
          material = 'flesh',
          x = e.x,
          z = e.z,
          radius = 0.5,
          bottom = 0,
          top = 2,
        },
      },
    },
  }
  local target, dist = B.traceVector(g, 1, 0, 0, 2, bodies)
  profiles[profileKey] = nil
  check('point-blank target wins before an immediately adjacent wall', target == e and dist == 0)

  -- An independently implemented slab intersection is the oracle, not another DDA.
  local function box(ox, oy, oz, dx, dy, dz, range, x, z, height)
    local lo, hi = 0, range
    local origins = { ox, oy, oz }
    local directions = { dx, dy, dz }
    local mins = { x - 0.5, 0, z - 0.5 }
    local maxs = { x + 0.5, height, z + 0.5 }
    for axis = 1, 3 do
      local o, v = origins[axis], directions[axis]
      if v == 0 then
        if o < mins[axis] or o > maxs[axis] then
          return nil
        end
      else
        local a, b = (mins[axis] - o) / v, (maxs[axis] - o) / v
        lo = math.max(lo, math.min(a, b))
        hi = math.min(hi, math.max(a, b))
        if lo > hi then
          return nil
        end
      end
    end
    return lo
  end
  -- 0.14: round pillars (tile 2) are cylinders of the painted radius with a flat cap.
  local function cylinder(ox, oy, oz, dx, dy, dz, range, cx, cz, r, h)
    local best
    local px, pz = ox - cx, oz - cz
    local a = dx * dx + dz * dz
    if a > 1e-12 then
      local b = px * dx + pz * dz
      local c = px * px + pz * pz - r * r
      local disc = b * b - a * c
      if disc >= 0 then
        local t = (-b - math.sqrt(disc)) / a
        if c <= 0 then
          t = 0
        end
        if t >= 0 and t <= range and oy + dy * t <= h then
          best = t
        end
      end
    end
    if dy < 0 then
      local t = (h - oy) / dy
      if t >= 0 and t <= range then
        local x, z = px + dx * t, pz + dz * t
        if x * x + z * z <= r * r and (not best or t < best) then
          best = t
        end
      end
    end
    return best
  end
  w = world(10)
  for z = 1, 10 do
    for x = 1, 10 do
      if x == 1 or x == 10 or z == 1 or z == 10 or (x * 13 + z * 7) % 11 == 0 then
        w.map[z][x] = (x + z) % 2 + 1
      end
    end
  end
  local seed = 173
  local function random()
    seed = (seed * 48271) % 2147483647
    return seed / 2147483647
  end
  for group = 1, 8 do
    local matches = true
    local largestError = 0
    for sample = 1, 64 do
      local ox, oz = 2 + random() * 7, 2 + random() * 7
      local oy = 0.1 + random() * 3.9
      local yaw = random() * math.pi * 2
      local pitch = (random() - 0.5) * 2.5
      local vx, vy, vz = B.direction(yaw, pitch)
      local range = 1 + random() * 13
      local expected = range
      if vy < 0 then
        expected = math.min(expected, (0.025 - oy) / vy)
      end
      -- Undefined cells outside the finite map are solid even above its low walls.
      if vx ~= 0 then
        expected = math.min(expected, ((vx > 0 and 10.5 or 0.5) - ox) / vx)
      end
      if vz ~= 0 then
        expected = math.min(expected, ((vz > 0 and 10.5 or 0.5) - oz) / vz)
      end
      for z = 1, 10 do
        for x = 1, 10 do
          if w.map[z][x] > 0 then
            local hit = w.map[z][x] == 2
                and cylinder(ox, oy, oz, vx, vy, vz, range, x, z, B.pillarRadius, 4.8)
              or (w.map[z][x] ~= 2 and box(ox, oy, oz, vx, vy, vz, range, x, z, 4.2))
            if hit then
              expected = math.min(expected, hit)
            end
          end
        end
      end
      local actual = B.world(w, ox, oy, oz, vx, vy, vz, range)
      largestError = math.max(largestError, math.abs(actual - expected))
      matches = matches and near(actual, expected, 1e-7)
    end
    check(
      'independent 3D slab oracle: 64 mixed rays, batch '
        .. group
        .. ' (max error '
        .. string.format('%.2g', largestError)
        .. ')',
      matches
    )
  end

  -- No rebalance: preserve the public formula across distance / armor / penetration.
  local attack = {
    base = 70,
    power = 1.2,
    zone = 0.9,
    upgrade = 1.1,
    impact = 44,
    damageType = 'physical',
    falloffStart = 12,
    falloffEnd = 36,
    minPower = 0.65,
  }
  for _, distance in ipairs({ 0, 12, 24, 36, 42 }) do
    local monotonic = true
    local previous = math.huge
    for _, armor in ipairs({ 0, 20, 60, 200 }) do
      attack.penetration = 0.5
      local damage, absorbed, impact =
        D.resolve(attack, { armorRating = armor, resistances = { physical = 0.2 } }, distance)
      local raw = 70 * 1.2 * 0.9 * 1.1 * D.falloff(distance, 12, 36, 0.65)
      monotonic = monotonic
        and damage <= previous
        and near(damage + absorbed, raw)
        and near(impact, 44 * 1.2 * 0.9 * 1.1 * D.falloff(distance, 12, 36, 0.65))
      previous = damage
    end
    check(
      'damage conserves absorbed energy and monotonic armor at ' .. distance .. ' metres',
      monotonic
    )
  end
  local previous = 0
  all = true
  for _, penetration in ipairs({ 0, 0.1, 0.5, 0.9, 1 }) do
    attack.penetration = penetration
    local damage = D.resolve(attack, { armorRating = 80 }, 12)
    all = all and damage >= previous
    previous = damage
  end
  check(
    'physical penetration monotonically removes armor without adding raw damage',
    all and near(previous, 70 * 1.2 * 0.9 * 1.1)
  )
end
return Tests
