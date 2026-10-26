-- Behavioural checks for the deterministic dense-core volley. No test copies
-- the implementation's list of offsets, and no combat numbers are changed.
local S = {}
local B = require('src.combat.ballistics')
local Geometry = require('src.enemies.geometry')
local Definitions = require('src.content.enemy_catalog')
local Damage = require('src.combat.damage')
local Weapons = require('src.content.weapons')
local Tuning = require('src.content.tuning')
local function target(kind, x, z, frame, id)
  local d = Definitions[kind]
  return {
    kind = d.kind,
    variant = d.variant,
    id = id or 1,
    x = x,
    z = z,
    hp = d.hp,
    maxHp = d.hp,
    armorRating = d.armor,
    resistances = d.resistances,
    walk = 0,
    walkSpeed = 0,
    phase = 0,
    ai = 'idle',
    facing = math.pi,
    awake = true,
    memory = 60,
    previewFrame = frame or 1,
  }
end
local map = {}
for z = 1, 61 do
  map[z] = {}
  for x = 1, 61 do
    map[z][x] = 0
  end
end
local function scene(distance, enemies)
  return {
    world = { size = 61, map = map },
    player = {
      x = 31,
      z = 31 + distance,
      yaw = math.pi,
      pitch = 0,
      jump = 0,
      crouch = 0,
      weapon = 1,
    },
    enemies = enemies,
    testField = {},
    time = 0,
  }
end
function S.volley(kind, distance, frame, count, serial, offsets)
  local enemies = {}
  for i, x in ipairs(offsets or { 0 }) do
    enemies[#enemies + 1] = target(kind, 31 + x, 31, frame, i)
  end
  local g = scene(distance, enemies)
  local p = g.player
  -- Sternum/rib pixels measured on the source paintings, independent of hit regions.
  local points = {
    imp = { [1] = { 140, 101 }, [25] = { 370, 220 } },
    armored = { [1] = { 149, 94 } },
    stolas = { [1] = { 131, 148 }, [25] = { 415, 192 } },
    buer = { [1] = { 172, 181 } },
    boss = { [1] = { 168, 104 } },
    furfur = { [1] = { 176, 137 } },
  }
  local point = assert(points[kind][frame or 1], 'missing independently measured volley aim')
  local art = require('src.enemies.pose').sample(g, enemies[1])
  local data = love.image.newImageData(art.sourcePath)
  local iw, ih = data:getDimensions()
  local r = art.region.rect
  assert(select(4, data:getPixel(point[1], point[2])) > 0.65, 'shotgun aim must be painted chest')
  local u, v = (point[1] - r[1] * iw) / (r[3] * iw), (point[2] - r[2] * ih) / (r[4] * ih)
  local y = art.baseY + (1 - v) * art.sy * art.size
  local aimX = enemies[1].x + (u - 0.5) * art.sx * art.size
  local _, eye = B.origin(g)
  p.pitch = math.atan2(y - eye, distance)
  if not offsets then
    p.yaw = math.atan2(aimX - p.x, enemies[1].z - p.z)
  end
  data:release()
  local attack = Weapons.attack(g, 1)
  local bodies = B.prepare(g)
  local damage, hits, parts, unique = 0, 0, {}, {}
  for i = 1, count or 20 do
    local ox, oy = B.pellet(i, serial or 1, count or 20)
    local dx, dy, dz = B.spreadDirection(p.yaw, p.pitch, ox, oy)
    local e, d, _, _, _, _, _, part = B.traceVector(g, dx, dy, dz, Tuning.shotgunRange, bodies)
    if e then
      local amount = Damage.resolve(attack, e, d, part)
      damage = damage + amount
      hits = hits + 1
      unique[e.id] = (unique[e.id] or 0) + amount
      parts[part] = (parts[part] or 0) + 1
    end
  end
  return { damage = damage, hits = hits, targets = unique, parts = parts, hp = Definitions[kind].hp }
end
function S.run(check, renderer)
  local C = require('src.render.fresco_enemies')
  renderer = renderer or {}
  if not renderer.animations then
    C.loadAll(renderer)
  end
  for kind, frames in pairs(renderer.frames) do
    Geometry.register(kind, frames, renderer.feet[kind])
  end
  local count = 0
  local function verify(name, ok)
    count = count + 1
    if check then
      check(name, not not ok)
    else
      assert(ok, name)
    end
  end
  for _, pellets in ipairs({ 10, 20 }) do
    local first = {}
    for serial = 1, 2 do
      local sumX, sumY, maxX = 0, 0, 0
      local bounded, mirrored, distinct = true, true, {}
      for i = 1, pellets do
        local x, y = B.pellet(i, serial, pellets)
        sumX = sumX + x
        sumY = sumY + y
        maxX = math.max(maxX, math.abs(x))
        bounded = bounded
          and math.abs(x) <= Tuning.pelletSpread + 1e-12
          and math.abs(y) <= Tuning.pelletVerticalSpread + 1e-12
        distinct[string.format('%.12f/%.12f', x, y)] = true
        local otherX, otherY = B.pellet(i % 2 == 1 and i + 1 or i - 1, serial, pellets)
        mirrored = mirrored and math.abs(x + otherX) < 1e-12 and math.abs(y + otherY) < 1e-12
        first[i] = first[i] or { x, y }
        if serial == 2 then
          mirrored = mirrored and x == first[i][1] and y == -first[i][2]
        end
      end
      local n = 0
      for _ in pairs(distinct) do
        n = n + 1
      end
      verify(
        'shotgun '
          .. pellets
          .. ' rays serial '
          .. serial
          .. ' remain inside the original angular cone',
        bounded and maxX >= Tuning.pelletSpread * 0.99
      )
      verify(
        'shotgun '
          .. pellets
          .. ' rays serial '
          .. serial
          .. ' keep balanced paired barrel coverage',
        mirrored and math.abs(sumX) < 1e-12 and math.abs(sumY) < 1e-12
      )
      verify(
        'shotgun ' .. pellets .. ' rays serial ' .. serial .. ' are independent directions',
        n == pellets
      )
    end
  end
  local a, b = {}, {}
  local randomState = love.math.getRandomState()
  love.math.setRandomSeed(7)
  for i = 1, 20 do
    a[i] = { B.pellet(i, 3, 20) }
  end
  love.math.setRandomSeed(981)
  for _ = 1, 300 do
    love.math.random()
  end
  local same = true
  for i = 1, 20 do
    b[i] = { B.pellet(i, 3, 20) }
    same = same and a[i][1] == b[i][1] and a[i][2] == b[i][2]
  end
  love.math.setRandomState(randomState)
  verify('shotgun source randomness cannot change a volley', same)
  for _, kind in ipairs(C.kinds) do
    local last = math.huge
    local monotonic = true
    local attack = Weapons.attack({}, 1)
    local body = target(kind, 31, 31, 1)
    for _, distance in ipairs({ 2, 4, 6, 8, 10, 14, 18 }) do
      local damage = Damage.resolve(attack, body, distance, 'torso')
      monotonic = monotonic and damage <= last
      last = damage
    end
    verify('shotgun ' .. kind .. ' fixed-zone damage never increases across 2–18 m', monotonic)
    -- An expanding pattern can change anatomy: e.g. 20 torso hits at 2 m,
    -- but 19 torso + one head at 4 m. Whole-volley damage is not monotonically
    -- ordered at every distance; the fixed-contact damage function above is.
    local close, far = S.volley(kind, 2, 1), S.volley(kind, 18, 1)
    verify(
      'shotgun ' .. kind .. ' painted-body volley rewards closing 18 m to 2 m',
      close.damage > far.damage
    )
  end
  for _, kind in ipairs({ 'imp', 'stolas' }) do
    for _, frame in ipairs({ 1, require('src.enemies.idle').entries[kind].first }) do
      for _, distance in ipairs({ 6, 8 }) do
        local r = S.volley(kind, distance, frame)
        -- 0.20 (playtest: fodder died to any volley): the Ember Thrall now
        -- survives one centred volley at 8 m and needs a follow-up; the Star
        -- Acolyte stays a glass cannon. Both still fall to a volley at 6 m.
        if kind == 'imp' and distance == 8 then
          verify(
            'shotgun centred imp pose ' .. frame .. ' leaves the thrall standing at 8 m',
            r.damage < r.hp and r.damage > r.hp * 0.75
          )
        else
          verify(
            'shotgun centred '
              .. kind
              .. ' pose '
              .. frame
              .. ' is decisive at '
              .. distance
              .. ' m',
            r.damage >= r.hp
          )
        end
      end
    end
  end
  local armor = S.volley('armored', 8, 1)
  local revolver = Weapons.attack({}, 2)
  local pistolDamage =
    Damage.resolve(revolver, { armorRating = Definitions.armored.armor }, 8, 'torso')
  local shells = math.ceil(Definitions.armored.hp / armor.damage)
  local rounds = math.ceil(Definitions.armored.hp / pistolDamage)
  verify(
    'precision revolver keeps an armored-target cadence advantage at 8 m',
    (rounds - 1) * Tuning.revolverInterval < (shells - 1) * Tuning.shotgunCycle
  )
  for _, kind in ipairs({ 'imp', 'stolas', 'armored' }) do
    local near, far = S.volley(kind, 4, 1), S.volley(kind, 14, 1)
    verify(
      'shotgun ' .. kind .. ' remains a close weapon rather than a free sniper',
      near.damage > far.damage * 2
    )
  end
  for _, distance in ipairs({ 3, 4, 5 }) do
    local r = S.volley('imp', distance, 1, 20, 1, { -0.6, 0.6 })
    local targets = 0
    for _, damage in pairs(r.targets) do
      if damage > 0 then
        targets = targets + 1
      end
    end
    verify('shotgun wide rays still hit two adjacent bodies at ' .. distance .. ' m', targets == 2)
    verify(
      -- 0.20: a spread pair (1.2 m) is crippled by one volley, a tight pair
      -- (0.9 m, tests/suites/shotgun.lua) still dies: thralls survive 8 m.
      'shotgun leaves two aligned adjacent grunts near death at ' .. distance .. ' m',
      (r.targets[1] or 0) >= Definitions.imp.hp * 0.8
        and (r.targets[2] or 0) >= Definitions.imp.hp * 0.8
    )
  end
  return count
end
return S
